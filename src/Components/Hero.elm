module Components.Hero exposing (view)

import Html exposing (Html)
import Html.Attributes as Attr


view :
    { title : String
    , subtitle : Maybe String
    , cta : List (Html msg)
    }
    -> Html msg
view config =
    Html.section
        [ Attr.class "bg-white py-16 sm:py-24" ]
        [ Html.div
            [ Attr.class "mx-auto max-w-4xl px-6 lg:px-8 text-center" ]
            [ Html.h1
                [ Attr.class "text-4xl font-bold tracking-tight text-gray-900 sm:text-5xl lg:text-6xl" ]
                [ Html.text config.title ]
            , case config.subtitle of
                Just sub ->
                    Html.p
                        [ Attr.class "mt-6 text-lg leading-8 text-gray-600 max-w-2xl mx-auto" ]
                        [ Html.text sub ]

                Nothing ->
                    Html.text ""
            , if List.isEmpty config.cta then
                Html.text ""

              else
                Html.div
                    [ Attr.class "mt-10 flex items-center justify-center gap-x-6 flex-wrap gap-y-4" ]
                    config.cta
            ]
        ]
