module MarkdownRenderer exposing (renderMarkdown)

import Components.Accordion as Accordion
import Components.Alert as Alert
import Components.Card as Card
import Components.Hero as Hero
import Components.Stats as Stats
import Components.Timeline as Timeline
import Html exposing (Html)
import Html.Attributes as Attr
import Markdown.Block as Block
import Markdown.Html
import Markdown.Parser
import Markdown.Renderer


renderMarkdown : String -> Html msg
renderMarkdown markdown =
    case
        markdown
            |> Markdown.Parser.parse
            |> Result.mapError (List.map Markdown.Parser.deadEndToString >> String.join "\n")
            |> Result.andThen (Markdown.Renderer.render renderer)
    of
        Ok rendered ->
            Html.article [ Attr.class "prose prose-gray max-w-none" ] rendered

        Err err ->
            Html.pre [ Attr.class "text-red-600 text-sm p-4 bg-red-50 rounded" ] [ Html.text err ]


{-| Custom renderer — no explicit type annotation so Elm can freely unify the
`msg` type variable across all fields.
-}
renderer =
    { heading = viewHeading
    , paragraph = Html.p [ Attr.class "my-4 leading-7 text-gray-700" ]
    , hardLineBreak = Html.br [] []
    , blockQuote =
        \children ->
            Html.blockquote
                [ Attr.class "pl-4 border-l-4 border-gray-300 text-gray-600 italic my-6" ]
                children
    , strong = \children -> Html.strong [ Attr.class "font-semibold text-gray-900" ] children
    , emphasis = \children -> Html.em [ Attr.class "italic" ] children
    , strikethrough = \children -> Html.s [] children
    , codeSpan =
        \code ->
            Html.code
                [ Attr.class "px-1.5 py-0.5 rounded bg-gray-100 text-gray-800 font-mono text-sm" ]
                [ Html.text code ]
    , link = viewLink
    , image = viewImage
    , text = Html.text
    , unorderedList = viewUnorderedList
    , orderedList = viewOrderedList
    , codeBlock = viewCodeBlock
    , thematicBreak = Html.hr [ Attr.class "my-8 border-gray-200" ] []
    , table = Html.table [ Attr.class "w-full text-sm border-collapse my-6 rounded overflow-hidden" ]
    , tableHeader = Html.thead [ Attr.class "bg-gray-50 border-b border-gray-200" ]
    , tableBody = Html.tbody []
    , tableRow = Html.tr [ Attr.class "border-b border-gray-100 last:border-0" ]
    , tableHeaderCell =
        \_ children ->
            Html.th [ Attr.class "px-4 py-2 text-left font-semibold text-gray-700" ] children
    , tableCell =
        \_ children ->
            Html.td [ Attr.class "px-4 py-2 text-gray-700" ] children
    , html = htmlRenderer
    }


viewHeading :
    { level : Block.HeadingLevel, rawText : String, children : List (Html msg) }
    -> Html msg
viewHeading { level, children } =
    case level of
        Block.H1 ->
            Html.h1 [ Attr.class "text-3xl font-bold tracking-tight text-gray-900 mt-8 mb-4" ] children

        Block.H2 ->
            Html.h2 [ Attr.class "text-2xl font-bold text-gray-900 mt-8 mb-3 border-b border-gray-200 pb-2" ] children

        Block.H3 ->
            Html.h3 [ Attr.class "text-xl font-semibold text-gray-900 mt-6 mb-2" ] children

        Block.H4 ->
            Html.h4 [ Attr.class "text-base font-semibold text-gray-900 mt-4 mb-1" ] children

        Block.H5 ->
            Html.h5 [ Attr.class "text-sm font-semibold text-gray-700 mt-3 mb-1 uppercase tracking-wide" ] children

        Block.H6 ->
            Html.h6 [ Attr.class "text-sm font-medium text-gray-500 mt-2 mb-1" ] children


viewLink : { title : Maybe String, destination : String } -> List (Html msg) -> Html msg
viewLink link children =
    Html.a
        [ Attr.href link.destination
        , Attr.class "text-indigo-600 hover:text-indigo-800 underline underline-offset-2 transition-colors"
        ]
        children


viewImage : { alt : String, src : String, title : Maybe String } -> Html msg
viewImage img =
    Html.figure [ Attr.class "my-8" ]
        [ Html.img
            [ Attr.src img.src
            , Attr.alt img.alt
            , Attr.class "rounded-lg w-full"
            ]
            []
        , case img.title of
            Just title ->
                Html.figcaption [ Attr.class "mt-2 text-center text-sm text-gray-500" ]
                    [ Html.text title ]

            Nothing ->
                Html.text ""
        ]


viewUnorderedList : List (Block.ListItem (Html msg)) -> Html msg
viewUnorderedList items =
    Html.ul [ Attr.class "my-4 space-y-1 list-disc pl-6 text-gray-700" ]
        (List.map
            (\(Block.ListItem task children) ->
                Html.li
                    [ Attr.class
                        (case task of
                            Block.CompletedTask ->
                                "line-through text-gray-400"

                            _ ->
                                ""
                        )
                    ]
                    children
            )
            items
        )


viewOrderedList : Int -> List (List (Html msg)) -> Html msg
viewOrderedList startingIndex items =
    Html.ol
        [ Attr.class "my-4 space-y-1 list-decimal pl-6 text-gray-700"
        , Attr.attribute "start" (String.fromInt startingIndex)
        ]
        (List.map (Html.li []) items)


viewCodeBlock : { body : String, language : Maybe String } -> Html msg
viewCodeBlock { body, language } =
    Html.div [ Attr.class "my-6 rounded-lg overflow-hidden" ]
        [ case language of
            Just lang ->
                Html.div [ Attr.class "px-4 py-1.5 bg-gray-700 text-gray-300 text-xs font-mono" ]
                    [ Html.text lang ]

            Nothing ->
                Html.text ""
        , Html.pre
            [ Attr.class "bg-gray-900 text-gray-100 p-4 overflow-x-auto text-sm font-mono leading-relaxed" ]
            [ Html.code [] [ Html.text body ] ]
        ]


{-| No explicit type annotation — lets Elm freely infer and unify `msg`.
-}
htmlRenderer =
    Markdown.Html.oneOf
        [ -- <callout type="info|success|warning|error">…</callout>
          Markdown.Html.tag "callout"
            (\calloutType children ->
                Alert.view
                    { alertType = parseAlertType calloutType
                    , title = Nothing
                    , body = children
                    }
            )
            |> Markdown.Html.withAttribute "type"

        , -- <hero title="…" subtitle="…">…</hero>
          Markdown.Html.tag "hero"
            (\title subtitle children ->
                Hero.view
                    { title = title
                    , subtitle = subtitle
                    , cta = children
                    }
            )
            |> Markdown.Html.withAttribute "title"
            |> Markdown.Html.withOptionalAttribute "subtitle"

        , -- <feature-grid columns="2|3">…</feature-grid>
          Markdown.Html.tag "feature-grid"
            (\columns children ->
                let
                    cols =
                        columns
                            |> Maybe.andThen String.toInt
                            |> Maybe.withDefault 3
                in
                Html.div
                    [ Attr.class
                        ("not-prose grid gap-x-8 gap-y-10 "
                            ++ (case cols of
                                    2 ->
                                        "sm:grid-cols-2"

                                    3 ->
                                        "sm:grid-cols-2 lg:grid-cols-3"

                                    _ ->
                                        "sm:grid-cols-2 lg:grid-cols-4"
                               )
                        )
                    ]
                    children
            )
            |> Markdown.Html.withOptionalAttribute "columns"

        , -- <feature title="…" icon="…">…</feature>
          Markdown.Html.tag "feature"
            (\title icon children ->
                Html.div [ Attr.class "flex flex-col" ]
                    [ case icon of
                        Just ico ->
                            Html.div
                                [ Attr.class "mb-4 flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-600 text-white text-lg" ]
                                [ Html.text ico ]

                        Nothing ->
                            Html.text ""
                    , Html.h3 [ Attr.class "text-base font-semibold leading-7 text-gray-900" ]
                        [ Html.text title ]
                    , Html.div [ Attr.class "mt-2 text-sm leading-7 text-gray-600" ] children
                    ]
            )
            |> Markdown.Html.withAttribute "title"
            |> Markdown.Html.withOptionalAttribute "icon"

        , -- <pricing-table highlighted="Tier Name">…</pricing-table>
          Markdown.Html.tag "pricing-table"
            (\_ children ->
                Html.div
                    [ Attr.class "not-prose py-8 grid gap-8 sm:grid-cols-2 lg:grid-cols-3" ]
                    children
            )
            |> Markdown.Html.withOptionalAttribute "highlighted"

        , -- <pricing-tier name="…" price="…" period="…">…</pricing-tier>
          Markdown.Html.tag "pricing-tier"
            (\name price period children ->
                Html.div
                    [ Attr.class "rounded-2xl border border-gray-200 bg-white shadow-sm overflow-hidden" ]
                    [ Html.div [ Attr.class "p-8" ]
                        [ Html.h3
                            [ Attr.class "text-lg font-semibold text-gray-900" ]
                            [ Html.text name ]
                        , Html.div [ Attr.class "mt-4 flex items-baseline gap-x-2" ]
                            [ Html.span
                                [ Attr.class "text-4xl font-bold tracking-tight text-gray-900" ]
                                [ Html.text price ]
                            , case period of
                                Just p ->
                                    Html.span
                                        [ Attr.class "text-sm font-semibold text-gray-500" ]
                                        [ Html.text ("/ " ++ p) ]

                                Nothing ->
                                    Html.text ""
                            ]
                        , Html.div [ Attr.class "mt-8 text-sm text-gray-700" ] children
                        ]
                    ]
            )
            |> Markdown.Html.withAttribute "name"
            |> Markdown.Html.withAttribute "price"
            |> Markdown.Html.withOptionalAttribute "period"

        , -- <button-link href="…" variant="primary|secondary|ghost">label</button-link>
          Markdown.Html.tag "button-link"
            (\href variant children ->
                Html.a
                    [ Attr.href href
                    , Attr.class (buttonLinkClass variant)
                    ]
                    children
            )
            |> Markdown.Html.withAttribute "href"
            |> Markdown.Html.withOptionalAttribute "variant"

        , -- <card title="…">body</card>
          Markdown.Html.tag "card"
            (\title children ->
                Card.view
                    { header = Maybe.map (\t -> Html.span [ Attr.class "font-semibold text-gray-900" ] [ Html.text t ]) title
                    , body = children
                    , footer = Nothing
                    , image = Nothing
                    , shadow = Card.Sm
                    }
            )
            |> Markdown.Html.withOptionalAttribute "title"

        , -- <badge color="gray|blue|green|yellow|red|purple|indigo">label</badge>
          Markdown.Html.tag "badge"
            (\color children ->
                Html.span [ Attr.class (badgeClass color) ] children
            )
            |> Markdown.Html.withOptionalAttribute "color"

        , -- <accordion><accordion-item summary="…">…</accordion-item></accordion>
          Markdown.Html.tag "accordion"
            (\children -> Accordion.view children)

        , -- <accordion-item summary="…">…</accordion-item>
          Markdown.Html.tag "accordion-item"
            (\summary children ->
                Accordion.viewItem { summary = summary, children = children }
            )
            |> Markdown.Html.withAttribute "summary"

        , -- <stat-grid><stat label="…" value="…" change="…"></stat></stat-grid>
          Markdown.Html.tag "stat-grid"
            (\children -> Stats.view children)

        , -- <stat label="…" value="…" change="…"></stat>
          Markdown.Html.tag "stat"
            (\label value change _ ->
                Stats.viewItem { label = label, value = value, change = change }
            )
            |> Markdown.Html.withAttribute "label"
            |> Markdown.Html.withAttribute "value"
            |> Markdown.Html.withOptionalAttribute "change"

        , -- <timeline><timeline-item date="…" title="…">…</timeline-item></timeline>
          Markdown.Html.tag "timeline"
            (\children -> Timeline.view children)

        , -- <timeline-item date="…" title="…">…</timeline-item>
          Markdown.Html.tag "timeline-item"
            (\date title children ->
                Timeline.viewItem { date = date, title = title, children = children }
            )
            |> Markdown.Html.withAttribute "date"
            |> Markdown.Html.withAttribute "title"
        ]


parseAlertType : String -> Alert.AlertType
parseAlertType s =
    case s of
        "success" ->
            Alert.Success

        "warning" ->
            Alert.Warning

        "error" ->
            Alert.Error

        _ ->
            Alert.Info


badgeClass : Maybe String -> String
badgeClass color =
    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium "
        ++ (case Maybe.withDefault "gray" color of
                "blue" ->
                    "bg-blue-100 text-blue-700"

                "green" ->
                    "bg-green-100 text-green-700"

                "yellow" ->
                    "bg-yellow-100 text-yellow-800"

                "red" ->
                    "bg-red-100 text-red-700"

                "purple" ->
                    "bg-purple-100 text-purple-700"

                "indigo" ->
                    "bg-indigo-100 text-indigo-700"

                _ ->
                    "bg-gray-100 text-gray-700"
           )


buttonLinkClass : Maybe String -> String
buttonLinkClass variant =
    let
        base =
            "no-underline inline-flex items-center justify-center font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 px-4 py-2 text-sm"
    in
    base
        ++ " "
        ++ (case Maybe.withDefault "primary" variant of
                "secondary" ->
                    "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-indigo-500"

                "ghost" ->
                    "text-indigo-600 hover:bg-indigo-50 focus:ring-indigo-500"

                _ ->
                    "bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500"
           )
