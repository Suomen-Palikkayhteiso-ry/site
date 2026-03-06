module Components.Badge exposing (Color(..), view)

import Html exposing (Html)
import Html.Attributes as Attr


type Color
    = Gray
    | Blue
    | Green
    | Yellow
    | Red
    | Purple
    | Indigo


view : { label : String, color : Color } -> Html msg
view config =
    Html.span
        [ Attr.class (badgeClasses config.color) ]
        [ Html.text config.label ]


badgeClasses : Color -> String
badgeClasses color =
    "inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium "
        ++ colorClasses color


colorClasses : Color -> String
colorClasses color =
    case color of
        Gray ->
            "bg-gray-100 text-gray-700"

        Blue ->
            "bg-blue-100 text-blue-700"

        Green ->
            "bg-green-100 text-green-700"

        Yellow ->
            "bg-yellow-100 text-yellow-800"

        Red ->
            "bg-red-100 text-red-700"

        Purple ->
            "bg-purple-100 text-purple-700"

        Indigo ->
            "bg-indigo-100 text-indigo-700"
