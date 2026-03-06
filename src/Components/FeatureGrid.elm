module Components.FeatureGrid exposing (Feature, view)

import Html exposing (Html)
import Html.Attributes as Attr


type alias Feature msg =
    { icon : Maybe String
    , title : String
    , description : List (Html msg)
    }


view : { columns : Int, features : List (Feature msg) } -> Html msg
view config =
    Html.div
        [ Attr.class "py-12" ]
        [ Html.div
            [ Attr.class (gridClasses config.columns) ]
            (List.map viewFeature config.features)
        ]


viewFeature : Feature msg -> Html msg
viewFeature feature =
    Html.div
        [ Attr.class "flex flex-col" ]
        [ case feature.icon of
            Just ico ->
                Html.div
                    [ Attr.class "mb-4 flex h-10 w-10 items-center justify-center rounded-lg bg-indigo-600 text-white text-lg" ]
                    [ Html.text ico ]

            Nothing ->
                Html.text ""
        , Html.h3
            [ Attr.class "text-base font-semibold leading-7 text-gray-900" ]
            [ Html.text feature.title ]
        , Html.div
            [ Attr.class "mt-2 text-sm leading-7 text-gray-600" ]
            feature.description
        ]


gridClasses : Int -> String
gridClasses columns =
    "grid gap-x-8 gap-y-10 "
        ++ (case columns of
                2 ->
                    "sm:grid-cols-2"

                3 ->
                    "sm:grid-cols-2 lg:grid-cols-3"

                4 ->
                    "sm:grid-cols-2 lg:grid-cols-4"

                _ ->
                    "sm:grid-cols-2 lg:grid-cols-3"
           )
