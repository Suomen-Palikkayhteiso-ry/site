module Route.Index exposing (ActionData, Data, Model, Msg, route)

import BackendTask exposing (BackendTask)
import BackendTask.File as File
import BackendTask.Glob as Glob
import FatalError exposing (FatalError)
import Frontmatter exposing (Frontmatter)
import Head
import Head.Seo as Seo
import Html exposing (Html)
import Html.Attributes as Attr
import Pages.Url
import PagesMsg exposing (PagesMsg)
import RouteBuilder exposing (App, StatelessRoute)
import Shared
import View exposing (View)


type alias Model =
    {}


type alias Msg =
    ()


type alias RouteParams =
    {}


type alias Data =
    { pages : List Frontmatter }


type alias ActionData =
    {}


route : StatelessRoute RouteParams Data ActionData
route =
    RouteBuilder.single
        { head = head
        , data = data
        }
        |> RouteBuilder.buildNoState { view = view }


data : BackendTask FatalError Data
data =
    Glob.succeed identity
        |> Glob.match (Glob.literal "content/")
        |> Glob.capture Glob.wildcard
        |> Glob.match (Glob.literal ".md")
        |> Glob.toBackendTask
        |> BackendTask.andThen
            (\slugs ->
                slugs
                    |> List.map
                        (\slug ->
                            File.bodyWithFrontmatter
                                (\_ -> Frontmatter.decoder)
                                ("content/" ++ slug ++ ".md")
                                |> BackendTask.allowFatal
                        )
                    |> BackendTask.combine
            )
        |> BackendTask.map
            (List.filter .published
                >> List.sortBy .title
                >> (\pages_ -> { pages = pages_ })
            )


head :
    App Data ActionData RouteParams
    -> List Head.Tag
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
        , description = "Welcome to My Site"
        , locale = Nothing
        , title = "Home"
        }
        |> Seo.website


view :
    App Data ActionData RouteParams
    -> Shared.Model
    -> View (PagesMsg Msg)
view app _ =
    { title = "Home"
    , body =
        [ Html.h1 [] [ Html.text "Pages" ]
        , Html.ul []
            (List.map
                (\page ->
                    Html.li []
                        [ Html.a
                            [ Attr.href ("/" ++ page.slug) ]
                            [ Html.text page.title ]
                        ]
                )
                app.data.pages
            )
        ]
    }
