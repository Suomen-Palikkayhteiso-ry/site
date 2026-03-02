module Route.Slug_ exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import BackendTask.File as File
import BackendTask.Glob as Glob
import FatalError exposing (FatalError)
import Frontmatter exposing (Frontmatter)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import Json.Decode as Decode
import Markdown.Parser
import Markdown.Renderer
import Pages.Url
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatelessRoute)
import Shared
import UrlPath
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


type alias RouteParams =
    { slug : String }


type alias Data =
    { frontmatter : Frontmatter
    , body : String
    }


type alias ActionData =
    {}


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.preRender
        { head = head
        , pages = pages
        , data = data
        }
        |> RouteBuilder.buildNoState { view = view }


pages : BackendTask FatalError (List RouteParams)
pages =
    Glob.succeed (\slug -> { slug = slug })
        |> Glob.match (Glob.literal "content/")
        |> Glob.capture Glob.wildcard
        |> Glob.match (Glob.literal ".md")
        |> Glob.toBackendTask


data : RouteParams -> BackendTask FatalError Data
data routeParams =
    File.bodyWithFrontmatter
        (\body ->
            Frontmatter.decoder
                |> Decode.map (\fm -> { frontmatter = fm, body = body })
        )
        ("content/" ++ routeParams.slug ++ ".md")
        |> BackendTask.allowFatal


head : App Data ActionData RouteParams -> List Head.Tag
head app =
    Seo.summary
        { canonicalUrlOverride = Nothing
        , siteName = "My Site"
        , image =
            { url = Pages.Url.external ""
            , alt = ""
            , dimensions = Nothing
            , mimeType = Nothing
            }
        , description = app.data.frontmatter.description
        , locale = Nothing
        , title = app.data.frontmatter.title
        }
        |> Seo.website


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> View (PagesMsg Msg)
view app _ =
    { title = app.data.frontmatter.title
    , body =
        [ renderMarkdown app.data.body ]
    }


renderMarkdown : String -> Html (PagesMsg Msg)
renderMarkdown markdown =
    case
        markdown
            |> Markdown.Parser.parse
            |> Result.mapError (List.map Markdown.Parser.deadEndToString >> String.join "\n")
            |> Result.andThen (Markdown.Renderer.render Markdown.Renderer.defaultHtmlRenderer)
    of
        Ok rendered ->
            Html.div [ Attr.class "prose" ] rendered

        Err err ->
            Html.pre [] [ Html.text err ]
