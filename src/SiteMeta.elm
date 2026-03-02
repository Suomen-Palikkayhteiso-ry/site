module SiteMeta exposing (SiteMeta, decoder, task)

import BackendTask exposing (BackendTask)
import BackendTask.File as File
import FatalError exposing (FatalError)
import Json.Decode as Decode exposing (Decoder)


type alias SiteMeta =
    { buildSha : String
    , buildTimestamp : String
    , runId : String
    , owner : String
    , repo : String
    , oauthClientId : String
    , oauthProxyUrl : String
    , repoScope : String
    }


decoder : Decoder SiteMeta
decoder =
    Decode.map7
        (\buildSha buildTimestamp runId owner repo oauthClientId oauthProxyUrl ->
            { buildSha = buildSha
            , buildTimestamp = buildTimestamp
            , runId = runId
            , owner = owner
            , repo = repo
            , oauthClientId = oauthClientId
            , oauthProxyUrl = oauthProxyUrl
            , repoScope = "public_repo"
            }
        )
        (Decode.field "buildSha" Decode.string)
        (Decode.field "buildTimestamp" Decode.string)
        (Decode.field "runId" Decode.string)
        (Decode.field "owner" Decode.string)
        (Decode.field "repo" Decode.string)
        (Decode.field "oauthClientId" Decode.string)
        (Decode.field "oauthProxyUrl" Decode.string
            |> Decode.maybe
            |> Decode.map (Maybe.withDefault "")
        )
        |> Decode.andThen
            (\meta ->
                Decode.field "repoScope" Decode.string
                    |> Decode.maybe
                    |> Decode.map (Maybe.withDefault "public_repo")
                    |> Decode.map (\scope -> { meta | repoScope = scope })
            )


task : BackendTask FatalError SiteMeta
task =
    File.jsonFile decoder "public/site-config.json"
        |> BackendTask.allowFatal
