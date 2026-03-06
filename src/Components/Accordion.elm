module Components.Accordion exposing (view, viewItem)

import Html exposing (Html)
import Html.Attributes as Attr


view : List (Html msg) -> Html msg
view items =
    Html.div
        [ Attr.class "divide-y divide-gray-200 border border-gray-200 rounded-lg overflow-hidden" ]
        items


viewItem : { summary : String, children : List (Html msg) } -> Html msg
viewItem config =
    Html.details
        [ Attr.class "group" ]
        [ Html.summary
            [ Attr.class "flex cursor-pointer select-none items-center justify-between px-6 py-4 font-medium text-gray-900 hover:bg-gray-50 [&::-webkit-details-marker]:hidden" ]
            [ Html.span [] [ Html.text config.summary ]
            , Html.span
                [ Attr.class "ml-4 shrink-0 text-gray-400 transition-transform duration-200 group-open:rotate-180" ]
                [ Html.text "▾" ]
            ]
        , Html.div
            [ Attr.class "px-6 pb-5 text-sm leading-7 text-gray-600" ]
            config.children
        ]
