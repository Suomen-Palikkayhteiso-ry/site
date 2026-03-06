module Components.Stats exposing (view, viewItem)

import Html exposing (Html)
import Html.Attributes as Attr


view : List (Html msg) -> Html msg
view items =
    Html.dl
        [ Attr.class "not-prose grid grid-cols-1 gap-px bg-gray-200 rounded-lg overflow-hidden sm:grid-cols-2 lg:grid-cols-4" ]
        items


viewItem : { label : String, value : String, change : Maybe String } -> Html msg
viewItem config =
    Html.div
        [ Attr.class "flex flex-wrap items-baseline justify-between gap-x-4 gap-y-2 bg-white px-6 py-5 sm:px-8" ]
        [ Html.dt
            [ Attr.class "text-sm font-medium leading-6 text-gray-500" ]
            [ Html.text config.label ]
        , case config.change of
            Just change ->
                Html.dd
                    [ Attr.class "text-xs font-medium text-emerald-700" ]
                    [ Html.text change ]

            Nothing ->
                Html.text ""
        , Html.dd
            [ Attr.class "w-full flex-none text-3xl font-medium leading-10 tracking-tight text-gray-900" ]
            [ Html.text config.value ]
        ]
