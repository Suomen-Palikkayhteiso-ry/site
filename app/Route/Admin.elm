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
    ( { auth = PATEntry ""
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
            ( { model | auth = PATEntry "" }
            , Effect.fromCmd (clearToken ())
            )

        ClickedBrowseFiles ->
            case model.auth of
                LoggedIn token ->
                    ( { model | editorState = LoadingFiles }
                    , Effect.fromCmd
                        (listFiles
                            { token = token.value
                            , owner = model.siteMeta.contentOwner
                            , repo = model.siteMeta.contentRepo
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
                            , owner = model.siteMeta.contentOwner
                            , repo = model.siteMeta.contentRepo
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
                            , owner = model.siteMeta.contentOwner
                            , repo = model.siteMeta.contentRepo
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
    { title = "Login"
    , body = [ Html.map PagesMsg.fromMsg (viewBody model) ]
    }


viewBody : Model -> Html Msg
viewBody model =
    Html.div [ Attr.class "min-h-screen bg-gray-50 flex flex-col" ]
        [ viewNav model
        , viewBuildStatus model.buildStatus
        , Html.main_ [ Attr.class "flex-1 max-w-5xl mx-auto w-full px-6 py-8" ]
            [ case model.auth of
                NotLoggedIn ->
                    viewPATEntry ""

                PATEntry draft ->
                    viewPATEntry draft

                LoggedIn _ ->
                    viewEditorState model.editorState

                AuthError err ->
                    viewCard []
                        [ Html.p [ Attr.class "text-red-600 mb-4" ] [ Html.text ("Error: " ++ err) ]
                        , btnSecondary [ Events.onClick ClickedUsePAT ] "Try again"
                        ]

                _ ->
                    Html.text ""
            ]
        ]


viewNav : Model -> Html Msg
viewNav model =
    Html.nav [ Attr.class "bg-brand shadow-sm" ]
        [ Html.div [ Attr.class "max-w-5xl mx-auto px-6 py-3 flex items-center justify-between" ]
            [ Html.a [ Attr.href "/" ]
                [ Html.img
                    [ Attr.src "https://logo.suomenpalikkayhteiso.fi/logo/horizontal/svg/horizontal-full-dark.svg"
                    , Attr.alt "Suomen Palikkaharrastajat ry"
                    , Attr.class "h-9"
                    ]
                    []
                ]
            , case model.auth of
                LoggedIn token ->
                    Html.div [ Attr.class "flex items-center gap-4" ]
                        [ Html.span [ Attr.class "text-sm text-white/70" ]
                            [ Html.text
                                (if String.isEmpty token.login then
                                    "Logged in"

                                 else
                                    "Signed in as " ++ token.login
                                )
                            ]
                        , Html.button
                            [ Events.onClick ClickedLogout
                            , Attr.class "text-sm text-white/70 hover:text-white underline"
                            ]
                            [ Html.text "Log out" ]
                        ]

                _ ->
                    Html.text ""
            ]
        ]



viewPATEntry : String -> Html Msg
viewPATEntry draft =
    viewCard [ Attr.class "max-w-md mx-auto" ]
        [ Html.h2 [ Attr.class "text-xl font-semibold text-gray-800 mb-2" ]
            [ Html.text "Personal Access Token" ]
        , Html.p [ Attr.class "text-sm text-gray-500 mb-4" ]
            [ Html.text "Paste a GitHub Personal Access Token with repo scope." ]
        , Html.div [ Attr.class "flex gap-2" ]
            [ Html.input
                [ Attr.type_ "password"
                , Attr.value draft
                , Attr.placeholder "ghp_..."
                , Events.onInput PATChanged
                , Attr.class "flex-1 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                ]
                []
            , btnPrimary [ Events.onClick PATSubmitted ] "Save"
            ]
        ]


viewEditorState : EditorState -> Html Msg
viewEditorState editorState =
    case editorState of
        NoBrowserOpen ->
            viewCard [ Attr.class "max-w-sm mx-auto text-center" ]
                [ Html.p [ Attr.class "text-gray-500 mb-4" ]
                    [ Html.text "Browse the content directory to pick a file to edit." ]
                , btnPrimary [ Events.onClick ClickedBrowseFiles ] "Browse files"
                ]

        LoadingFiles ->
            Html.p [ Attr.class "text-gray-500" ] [ Html.text "Loading files\u{2026}" ]

        FileBrowser files ->
            Html.div []
                [ Html.h2 [ Attr.class "text-lg font-semibold text-gray-800 mb-4" ]
                    [ Html.text "Choose a file" ]
                , Html.ul [ Attr.class "divide-y divide-gray-100 border border-gray-200 rounded-lg overflow-hidden bg-white shadow-sm" ]
                    (List.map
                        (\f ->
                            Html.li []
                                [ Html.button
                                    [ Events.onClick (ClickedFile f)
                                    , Attr.class "w-full text-left px-4 py-3 text-sm text-gray-700 hover:bg-gray-50 hover:text-blue-600 transition-colors"
                                    ]
                                    [ Html.text f.name ]
                                ]
                        )
                        files
                    )
                ]

        LoadingFile meta ->
            Html.p [ Attr.class "text-gray-500" ]
                [ Html.text ("Loading " ++ meta.name ++ "\u{2026}") ]

        Editing session ->
            Html.div [ Attr.class "flex flex-col gap-4" ]
                [ Html.div [ Attr.class "flex items-center justify-between" ]
                    [ Html.h2 [ Attr.class "text-lg font-semibold text-gray-800" ]
                        [ Html.text ("Editing: " ++ session.file.name) ]
                    ]
                , case session.pendingDraft of
                    Just _ ->
                        Html.div [ Attr.class "bg-amber-50 border border-amber-200 rounded-lg px-4 py-3 flex items-center gap-3 text-sm" ]
                            [ Html.span [ Attr.class "text-amber-800 flex-1" ]
                                [ Html.text "You have an unsaved draft." ]
                            , btnSecondary [ Events.onClick ResumedDraft ] "Resume draft"
                            , Html.button
                                [ Events.onClick DiscardedDraft
                                , Attr.class "text-sm text-gray-500 hover:text-gray-700 underline"
                                ]
                                [ Html.text "Discard" ]
                            ]

                    Nothing ->
                        Html.text ""
                , Html.div [ Attr.id "cm-editor" ] []
                , Html.div [ Attr.class "flex items-center gap-3 flex-wrap" ]
                    [ Html.input
                        [ Attr.type_ "text"
                        , Attr.value session.commitMessage
                        , Attr.placeholder "Commit message"
                        , Events.onInput CommitMessageChanged
                        , Attr.class "flex-1 min-w-0 border border-gray-300 rounded-lg px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
                        ]
                        []
                    , Html.button
                        [ Events.onClick ClickedCommit
                        , Attr.disabled (session.commitState == Committing)
                        , Attr.class
                            ("inline-flex items-center px-4 py-2 rounded-lg text-sm font-medium text-white transition-colors "
                                ++ (if session.commitState == Committing then
                                        "bg-blue-400 cursor-not-allowed"

                                    else
                                        "bg-blue-600 hover:bg-blue-700"
                                   )
                            )
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
                            Html.p [ Attr.class "w-full text-sm text-red-600" ]
                                [ Html.text ("Error: " ++ err) ]

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
                , Html.a [ Attr.href pageUrl, Attr.target "_blank", Attr.class "underline hover:no-underline" ]
                    [ Html.text "View updated page" ]
                ]

        BuildTimedOut ->
            Html.div [ Attr.class "build-status error" ]
                [ Html.text "\u{26A0}\u{FE0F} Deploy timed out. Check GitHub Actions." ]

        BuildFailed reason ->
            Html.div [ Attr.class "build-status error" ]
                [ Html.text ("\u{274C} Build failed: " ++ reason) ]


-- ── Reusable UI helpers ────────────────────────────────────────────────────

viewCard : List (Html.Attribute Msg) -> List (Html Msg) -> Html Msg
viewCard attrs children =
    Html.div
        (Attr.class "bg-white border border-gray-200 rounded-xl shadow-sm p-6" :: attrs)
        children


btnPrimary : List (Html.Attribute Msg) -> String -> Html Msg
btnPrimary attrs label =
    Html.button
        (Attr.class "inline-flex items-center justify-center px-4 py-2 rounded-lg text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
            :: attrs
        )
        [ Html.text label ]


btnSecondary : List (Html.Attribute Msg) -> String -> Html Msg
btnSecondary attrs label =
    Html.button
        (Attr.class "inline-flex items-center justify-center px-4 py-2 rounded-lg text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50 transition-colors"
            :: attrs
        )
        [ Html.text label ]


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
