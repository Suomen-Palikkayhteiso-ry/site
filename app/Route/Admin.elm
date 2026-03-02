port module Route.Admin exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import Effect exposing (Effect)
import FatalError exposing (FatalError)
import Head
import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events
import Json.Decode as Decode
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatefulRoute)
import Shared
import SiteMeta exposing (SiteMeta)
import UrlPath exposing (UrlPath)
import View exposing (View)


-- ── Route wiring ─────────────────────────────────────────────────────────────

type alias RouteParams =
    {}


type alias Data =
    { siteMeta : SiteMeta }


type alias ActionData =
    {}


route : StatefulRoute RouteParams Data ActionData Model Msg
route =
    RouteBuilder.single
        { head = head
        , data = data
        }
        |> RouteBuilder.buildWithLocalState
            { init = init
            , update = update
            , view = view
            , subscriptions = subscriptions
            }


data : BackendTask FatalError Data
data =
    SiteMeta.task
        |> BackendTask.map (\meta -> { siteMeta = meta })


head : App Data ActionData RouteParams -> List Head.Tag
head _ =
    [ Head.metaName "robots" (Head.raw "noindex, nofollow") ]


-- ── Model ─────────────────────────────────────────────────────────────────────

type AuthState
    = NotLoggedIn
    | RequestingDeviceCode
    | AwaitingUserAuth DeviceCodeState
    | LoggedIn Token
    | PATEntry String
    | AuthError String


type alias DeviceCodeState =
    { userCode : String
    , verificationUri : String
    , deviceCode : String
    , interval : Int
    }


type alias Token =
    { value : String
    , login : String
    }


type alias FileMeta =
    { path : String
    , name : String
    , sha : String
    }


type alias EditSession =
    { file : FileMeta
    , originalSha : String
    , content : String
    , commitMessage : String
    , commitState : CommitState
    , pendingDraft : Maybe String
    }


type CommitState
    = Idle
    | Committing
    | CommitError String


type EditorState
    = NoBrowserOpen
    | LoadingFiles
    | FileBrowser (List FileMeta)
    | LoadingFile FileMeta
    | Editing EditSession


type BuildStatus
    = BuildIdle
    | PollingActions { commitSha : String, attempt : Int }
    | PollingPage { commitSha : String, attempt : Int }
    | BuildLive { commitSha : String, pageUrl : String }
    | BuildTimedOut
    | BuildFailed String


type alias Model =
    { auth : AuthState
    , siteMeta : SiteMeta
    , editorState : EditorState
    , buildStatus : BuildStatus
    }


-- ── Init ──────────────────────────────────────────────────────────────────────

init :
    App Data ActionData RouteParams
    -> Shared.Model
    -> ( Model, Effect Msg )
init app _ =
    ( { auth = NotLoggedIn
      , siteMeta = app.data.siteMeta
      , editorState = NoBrowserOpen
      , buildStatus = BuildIdle
      }
    , Effect.fromCmd (loadTokenFromStorage ())
    )


-- ── Msg ───────────────────────────────────────────────────────────────────────

type Msg
    = ClickedLoginWithGitHub
    | ClickedUsePAT
    | ClickedLogout
    | PATChanged String
    | PATSubmitted
    | DeviceCodeReceived (Result String DeviceCodeState)
    | TokenReceived (Result String String)
    | TokenLoadedFromStorage (Maybe String)
    | ClickedBrowseFiles
    | FilesListed (Result String (List FileMeta))
    | ClickedFile FileMeta
    | FileLoaded (Result String { meta : FileMeta, content : String })
    | EditorContentChanged String
    | DraftLoaded (Maybe String)
    | ResumedDraft
    | DiscardedDraft
    | CommitMessageChanged String
    | ClickedCommit
    | CommitResultReceived (Result String String)
    | BuildStatusUpdated BuildStatusEvent


type BuildStatusEvent
    = ActionsQueued
    | ActionsRunning
    | ActionsComplete
    | ActionsFailed String
    | PageShaMatched String
    | PollTimedOut


-- ── Update ────────────────────────────────────────────────────────────────────

update :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Msg
    -> Model
    -> ( Model, Effect Msg )
update _ _ msg model =
    case msg of
        ClickedLoginWithGitHub ->
            ( { model | auth = RequestingDeviceCode }
            , Effect.fromCmd
                (requestDeviceCode
                    { clientId = model.siteMeta.oauthClientId
                    , proxyUrl = model.siteMeta.oauthProxyUrl
                    }
                )
            )

        ClickedUsePAT ->
            ( { model | auth = PATEntry "" }, Effect.none )

        PATChanged v ->
            ( { model | auth = PATEntry v }, Effect.none )

        PATSubmitted ->
            case model.auth of
                PATEntry v ->
                    if String.isEmpty (String.trim v) then
                        ( model, Effect.none )
                    else
                        ( { model | auth = LoggedIn { value = v, login = "pat-user" } }
                        , Effect.fromCmd (storeToken v)
                        )

                _ ->
                    ( model, Effect.none )

        DeviceCodeReceived (Ok state) ->
            ( { model | auth = AwaitingUserAuth state }
            , Effect.fromCmd (startPolling state)
            )

        DeviceCodeReceived (Err err) ->
            ( { model | auth = AuthError err }, Effect.none )

        TokenReceived (Ok token) ->
            ( { model | auth = LoggedIn { value = token, login = "" } }
            , Effect.fromCmd (storeToken token)
            )

        TokenReceived (Err err) ->
            ( { model | auth = AuthError err }, Effect.none )

        TokenLoadedFromStorage (Just token) ->
            ( { model | auth = LoggedIn { value = token, login = "" } }, Effect.none )

        TokenLoadedFromStorage Nothing ->
            ( model, Effect.none )

        ClickedLogout ->
            ( { model | auth = NotLoggedIn }
            , Effect.fromCmd (clearToken ())
            )

        ClickedBrowseFiles ->
            case model.auth of
                LoggedIn token ->
                    ( { model | editorState = LoadingFiles }
                    , Effect.fromCmd
                        (listFiles
                            { token = token.value
                            , owner = model.siteMeta.owner
                            , repo = model.siteMeta.repo
                            , path = "content"
                            }
                        )
                    )

                _ ->
                    ( model, Effect.none )

        FilesListed (Ok files) ->
            ( { model | editorState = FileBrowser files }, Effect.none )

        FilesListed (Err _) ->
            ( { model | editorState = NoBrowserOpen }, Effect.none )

        ClickedFile meta ->
            case model.auth of
                LoggedIn token ->
                    ( { model | editorState = LoadingFile meta }
                    , Effect.fromCmd
                        (fetchFile
                            { token = token.value
                            , owner = model.siteMeta.owner
                            , repo = model.siteMeta.repo
                            , path = meta.path
                            }
                        )
                    )

                _ ->
                    ( model, Effect.none )

        FileLoaded (Ok { meta, content }) ->
            let
                session =
                    { file = meta
                    , originalSha = meta.sha
                    , content = content
                    , commitMessage = "Update " ++ meta.name
                    , commitState = Idle
                    , pendingDraft = Nothing
                    }
            in
            ( { model | editorState = Editing session }
            , Effect.batch
                [ Effect.fromCmd (mountEditor ())
                , Effect.fromCmd (setEditorContent content)
                , Effect.fromCmd (loadDraft meta.path)
                ]
            )

        FileLoaded (Err _) ->
            ( model, Effect.none )

        EditorContentChanged newContent ->
            case model.editorState of
                Editing session ->
                    ( { model | editorState = Editing { session | content = newContent } }
                    , Effect.none
                    )

                _ ->
                    ( model, Effect.none )

        DraftLoaded maybeDraft ->
            case ( model.editorState, maybeDraft ) of
                ( Editing session, Just draft ) ->
                    ( { model | editorState = Editing { session | pendingDraft = Just draft } }
                    , Effect.none
                    )

                _ ->
                    ( model, Effect.none )

        ResumedDraft ->
            case model.editorState of
                Editing session ->
                    case session.pendingDraft of
                        Just draft ->
                            ( { model | editorState = Editing { session | content = draft, pendingDraft = Nothing } }
                            , Effect.fromCmd (setEditorContent draft)
                            )

                        Nothing ->
                            ( model, Effect.none )

                _ ->
                    ( model, Effect.none )

        DiscardedDraft ->
            case model.editorState of
                Editing session ->
                    ( { model | editorState = Editing { session | pendingDraft = Nothing } }
                    , Effect.fromCmd (clearDraft session.file.path)
                    )

                _ ->
                    ( model, Effect.none )

        CommitMessageChanged commitMsg ->
            case model.editorState of
                Editing session ->
                    ( { model | editorState = Editing { session | commitMessage = commitMsg } }, Effect.none )

                _ ->
                    ( model, Effect.none )

        ClickedCommit ->
            case ( model.editorState, model.auth ) of
                ( Editing session, LoggedIn token ) ->
                    ( { model | editorState = Editing { session | commitState = Committing } }
                    , Effect.fromCmd
                        (commitFile
                            { token = token.value
                            , owner = model.siteMeta.owner
                            , repo = model.siteMeta.repo
                            , path = session.file.path
                            , content = session.content
                            , sha = session.originalSha
                            , message = session.commitMessage
                            }
                        )
                    )

                _ ->
                    ( model, Effect.none )

        CommitResultReceived (Ok commitSha) ->
            case ( model.editorState, model.auth ) of
                ( Editing session, LoggedIn token ) ->
                    let
                        pageUrl =
                            "https://"
                                ++ model.siteMeta.owner
                                ++ ".github.io/"
                                ++ model.siteMeta.repo
                                ++ "/"
                                ++ (session.file.path
                                        |> String.replace "content/" ""
                                        |> String.replace ".md" "/"
                                   )
                    in
                    ( { model
                        | editorState = Editing { session | commitState = Idle }
                        , buildStatus = PollingActions { commitSha = commitSha, attempt = 0 }
                      }
                    , Effect.batch
                        [ Effect.fromCmd (clearDraft session.file.path)
                        , Effect.fromCmd
                            (startBuildPolling
                                { commitSha = commitSha
                                , token = token.value
                                , owner = model.siteMeta.owner
                                , repo = model.siteMeta.repo
                                , pageUrl = pageUrl
                                , actionsIntervalMs = 15000
                                , pageIntervalMs = 30000
                                , timeoutMs = 600000
                                }
                            )
                        ]
                    )

                _ ->
                    ( model, Effect.none )

        CommitResultReceived (Err errMsg) ->
            case model.editorState of
                Editing session ->
                    ( { model | editorState = Editing { session | commitState = CommitError errMsg } }
                    , Effect.none
                    )

                _ ->
                    ( model, Effect.none )

        BuildStatusUpdated event ->
            let
                next =
                    case ( model.buildStatus, event ) of
                        ( _, PollTimedOut ) ->
                            BuildTimedOut

                        ( _, ActionsFailed reason ) ->
                            BuildFailed reason

                        ( PollingActions state, ActionsComplete ) ->
                            PollingPage { commitSha = state.commitSha, attempt = 0 }

                        ( PollingPage state, PageShaMatched pageUrl ) ->
                            BuildLive { commitSha = state.commitSha, pageUrl = pageUrl }

                        _ ->
                            model.buildStatus
            in
            ( { model | buildStatus = next }, Effect.none )


-- ── Subscriptions ─────────────────────────────────────────────────────────────

subscriptions :
    RouteParams
    -> UrlPath
    -> Shared.Model
    -> Model
    -> Sub Msg
subscriptions _ _ _ _ =
    Sub.batch
        [ deviceCodeReceived (decodeDeviceCode >> DeviceCodeReceived)
        , tokenReceived (decodeToken >> TokenReceived)
        , tokenLoadedFromStorage TokenLoadedFromStorage
        , filesListed (decodeFileList >> FilesListed)
        , fileLoaded (decodeFileLoaded >> FileLoaded)
        , editorContentChanged EditorContentChanged
        , draftLoaded DraftLoaded
        , commitDone (decodeCommitResult >> CommitResultReceived)
        , buildStatusUpdate (decodeBuildStatusEvent >> BuildStatusUpdated)
        ]


-- ── View ──────────────────────────────────────────────────────────────────────

view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> Model
    -> View (PagesMsg Msg)
view _ _ model =
    { title = "Admin"
    , body = [ Html.map PagesMsg.fromMsg (viewBody model) ]
    }


viewBody : Model -> Html Msg
viewBody model =
    Html.div [ Attr.class "admin" ]
        [ Html.h1 [] [ Html.text "Site Editor" ]
        , viewBuildStatus model.buildStatus
        , case model.auth of
            NotLoggedIn ->
                viewNotLoggedIn

            RequestingDeviceCode ->
                Html.p [] [ Html.text "Requesting device code\u{2026}" ]

            AwaitingUserAuth state ->
                viewAwaitingAuth state

            PATEntry draft ->
                viewPATEntry draft

            LoggedIn token ->
                viewLoggedIn token model

            AuthError err ->
                Html.div []
                    [ Html.p [ Attr.style "color" "red" ] [ Html.text ("Error: " ++ err) ]
                    , Html.button [ Events.onClick ClickedLoginWithGitHub ]
                        [ Html.text "Try again" ]
                    ]
        ]


viewNotLoggedIn : Html Msg
viewNotLoggedIn =
    Html.div []
        [ Html.p [] [ Html.text "Sign in to edit pages." ]
        , Html.button [ Events.onClick ClickedLoginWithGitHub ]
            [ Html.text "Login with GitHub (device flow)" ]
        , Html.text " or "
        , Html.button [ Events.onClick ClickedUsePAT ]
            [ Html.text "Use Personal Access Token" ]
        ]


viewAwaitingAuth : DeviceCodeState -> Html Msg
viewAwaitingAuth state =
    Html.div []
        [ Html.p [] [ Html.text "Open this URL in your browser:" ]
        , Html.a [ Attr.href state.verificationUri, Attr.target "_blank" ]
            [ Html.text state.verificationUri ]
        , Html.p [] [ Html.text "Then enter this code:" ]
        , Html.pre [] [ Html.text state.userCode ]
        , Html.p [] [ Html.text "Waiting for authorisation\u{2026}" ]
        ]


viewPATEntry : String -> Html Msg
viewPATEntry draft =
    Html.div []
        [ Html.p [] [ Html.text "Paste a GitHub Personal Access Token with repo scope:" ]
        , Html.input
            [ Attr.type_ "password"
            , Attr.value draft
            , Attr.placeholder "ghp_..."
            , Events.onInput PATChanged
            ]
            []
        , Html.button [ Events.onClick PATSubmitted ] [ Html.text "Save" ]
        ]


viewLoggedIn : Token -> Model -> Html Msg
viewLoggedIn token model =
    Html.div []
        [ Html.p []
            [ Html.text
                ("Logged in"
                    ++ (if String.isEmpty token.login then
                            ""

                        else
                            " as " ++ token.login
                       )
                )
            ]
        , Html.button [ Events.onClick ClickedLogout ] [ Html.text "Log out" ]
        , viewEditorState model.editorState
        ]


viewEditorState : EditorState -> Html Msg
viewEditorState editorState =
    case editorState of
        NoBrowserOpen ->
            Html.button [ Events.onClick ClickedBrowseFiles ]
                [ Html.text "Browse files" ]

        LoadingFiles ->
            Html.p [] [ Html.text "Loading files\u{2026}" ]

        FileBrowser files ->
            Html.div []
                [ Html.h2 [] [ Html.text "Choose a file" ]
                , Html.ul []
                    (List.map
                        (\f ->
                            Html.li []
                                [ Html.button [ Events.onClick (ClickedFile f) ]
                                    [ Html.text f.name ]
                                ]
                        )
                        files
                    )
                ]

        LoadingFile meta ->
            Html.p [] [ Html.text ("Loading " ++ meta.name ++ "\u{2026}") ]

        Editing session ->
            Html.div []
                [ Html.h2 [] [ Html.text ("Editing: " ++ session.file.name) ]
                , case session.pendingDraft of
                    Just _ ->
                        Html.div [ Attr.style "background" "#fff3cd", Attr.style "padding" "0.5em" ]
                            [ Html.text "You have an unsaved draft. "
                            , Html.button [ Events.onClick ResumedDraft ] [ Html.text "Resume draft" ]
                            , Html.text " or "
                            , Html.button [ Events.onClick DiscardedDraft ] [ Html.text "Discard" ]
                            ]

                    Nothing ->
                        Html.text ""
                , Html.div [ Attr.id "cm-editor" ] []
                , Html.div [ Attr.style "margin-top" "1em" ]
                    [ Html.input
                        [ Attr.type_ "text"
                        , Attr.value session.commitMessage
                        , Attr.placeholder "Commit message"
                        , Events.onInput CommitMessageChanged
                        , Attr.style "width" "60%"
                        ]
                        []
                    , Html.text " "
                    , Html.button
                        [ Events.onClick ClickedCommit
                        , Attr.disabled (session.commitState == Committing)
                        ]
                        [ Html.text
                            (if session.commitState == Committing then
                                "Committing\u{2026}"

                             else
                                "Commit & Push"
                            )
                        ]
                    , case session.commitState of
                        CommitError err ->
                            Html.p [ Attr.style "color" "red" ] [ Html.text ("Error: " ++ err) ]

                        _ ->
                            Html.text ""
                    ]
                ]


viewBuildStatus : BuildStatus -> Html Msg
viewBuildStatus status =
    case status of
        BuildIdle ->
            Html.text ""

        PollingActions _ ->
            Html.div [ Attr.class "build-status polling" ]
                [ Html.text "\u{23F3} Build queued / running\u{2026}" ]

        PollingPage _ ->
            Html.div [ Attr.class "build-status polling" ]
                [ Html.text "\u{1F680} Build complete, waiting for deploy\u{2026}" ]

        BuildLive { pageUrl } ->
            Html.div [ Attr.class "build-status live" ]
                [ Html.text "\u{2705} Live! "
                , Html.a [ Attr.href pageUrl, Attr.target "_blank" ]
                    [ Html.text "View updated page" ]
                ]

        BuildTimedOut ->
            Html.div [ Attr.class "build-status error" ]
                [ Html.text "\u{26A0}\u{FE0F} Deploy timed out. Check GitHub Actions." ]

        BuildFailed reason ->
            Html.div [ Attr.class "build-status error" ]
                [ Html.text ("\u{274C} Build failed: " ++ reason) ]


-- ── Port stubs ────────────────────────────────────────────────────────────────

port requestDeviceCode : { clientId : String, proxyUrl : String } -> Cmd msg


port startPolling : DeviceCodeState -> Cmd msg


port loadTokenFromStorage : () -> Cmd msg


port storeToken : String -> Cmd msg


port clearToken : () -> Cmd msg


port deviceCodeReceived : (Decode.Value -> msg) -> Sub msg


port tokenReceived : (Decode.Value -> msg) -> Sub msg


port tokenLoadedFromStorage : (Maybe String -> msg) -> Sub msg


port listFiles : { token : String, owner : String, repo : String, path : String } -> Cmd msg


port filesListed : (Decode.Value -> msg) -> Sub msg


port fetchFile : { token : String, owner : String, repo : String, path : String } -> Cmd msg


port fileLoaded : (Decode.Value -> msg) -> Sub msg


port setEditorContent : String -> Cmd msg


port editorContentChanged : (String -> msg) -> Sub msg


port mountEditor : () -> Cmd msg


port destroyEditor : () -> Cmd msg


port saveDraft : { path : String, content : String } -> Cmd msg


port loadDraft : String -> Cmd msg


port draftLoaded : (Maybe String -> msg) -> Sub msg


port clearDraft : String -> Cmd msg


port commitFile :
    { token : String
    , owner : String
    , repo : String
    , path : String
    , content : String
    , sha : String
    , message : String
    }
    -> Cmd msg


port commitDone : (Decode.Value -> msg) -> Sub msg


port startBuildPolling :
    { commitSha : String
    , token : String
    , owner : String
    , repo : String
    , pageUrl : String
    , actionsIntervalMs : Int
    , pageIntervalMs : Int
    , timeoutMs : Int
    }
    -> Cmd msg


port buildStatusUpdate : (Decode.Value -> msg) -> Sub msg


-- ── Helpers ───────────────────────────────────────────────────────────────────

decodeDeviceCode : Decode.Value -> Result String DeviceCodeState
decodeDeviceCode =
    Decode.decodeValue
        (Decode.map4 DeviceCodeState
            (Decode.field "userCode" Decode.string)
            (Decode.field "verificationUri" Decode.string)
            (Decode.field "deviceCode" Decode.string)
            (Decode.field "interval" Decode.int)
        )
        >> Result.mapError Decode.errorToString


decodeToken : Decode.Value -> Result String String
decodeToken =
    Decode.decodeValue (Decode.field "token" Decode.string)
        >> Result.mapError Decode.errorToString


decodeFileList : Decode.Value -> Result String (List FileMeta)
decodeFileList =
    Decode.decodeValue
        (Decode.list
            (Decode.map3 FileMeta
                (Decode.field "path" Decode.string)
                (Decode.field "name" Decode.string)
                (Decode.field "sha" Decode.string)
            )
        )
        >> Result.mapError Decode.errorToString


decodeFileLoaded : Decode.Value -> Result String { meta : FileMeta, content : String }
decodeFileLoaded =
    Decode.decodeValue
        (Decode.map2 (\meta content -> { meta = meta, content = content })
            (Decode.field "meta"
                (Decode.map3 FileMeta
                    (Decode.field "path" Decode.string)
                    (Decode.field "name" Decode.string)
                    (Decode.field "sha" Decode.string)
                )
            )
            (Decode.field "content" Decode.string)
        )
        >> Result.mapError Decode.errorToString


decodeCommitResult : Decode.Value -> Result String String
decodeCommitResult =
    Decode.decodeValue
        (Decode.oneOf
            [ Decode.field "sha" Decode.string |> Decode.map Ok
            , Decode.field "error" Decode.string |> Decode.map Err
            ]
        )
        >> Result.withDefault (Err "Unknown error")


decodeBuildStatusEvent : Decode.Value -> BuildStatusEvent
decodeBuildStatusEvent value =
    case Decode.decodeValue (Decode.field "event" Decode.string) value of
        Ok "actionsQueued" ->
            ActionsQueued

        Ok "actionsRunning" ->
            ActionsRunning

        Ok "actionsComplete" ->
            ActionsComplete

        Ok "pageMatched" ->
            Decode.decodeValue (Decode.field "pageUrl" Decode.string) value
                |> Result.withDefault ""
                |> PageShaMatched

        Ok "timedOut" ->
            PollTimedOut

        Ok "actionsFailed" ->
            Decode.decodeValue (Decode.field "reason" Decode.string) value
                |> Result.withDefault "unknown"
                |> ActionsFailed

        _ ->
            PollTimedOut
