module Components.Button exposing (Config, Size(..), Variant(..), view, viewLink)

import Html exposing (Html)
import Html.Attributes as Attr
import Html.Events as Events


type Variant
    = Primary
    | Secondary
    | Ghost
    | Danger


type Size
    = Sm
    | Md
    | Lg


type alias Config msg =
    { label : String
    , variant : Variant
    , size : Size
    , onClick : msg
    , disabled : Bool
    }


view : Config msg -> Html msg
view config =
    Html.button
        [ Attr.class (baseClasses config.size config.variant)
        , Attr.disabled config.disabled
        , Events.onClick config.onClick
        ]
        [ Html.text config.label ]


viewLink : { label : String, href : String, variant : Variant, size : Size } -> Html msg
viewLink config =
    Html.a
        [ Attr.href config.href
        , Attr.class (baseClasses config.size config.variant)
        ]
        [ Html.text config.label ]


baseClasses : Size -> Variant -> String
baseClasses size variant =
    String.join " "
        [ "inline-flex items-center justify-center font-medium rounded-md transition-colors focus:outline-none focus:ring-2 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
        , sizeClasses size
        , variantClasses variant
        ]


sizeClasses : Size -> String
sizeClasses size =
    case size of
        Sm ->
            "px-3 py-1.5 text-sm"

        Md ->
            "px-4 py-2 text-sm"

        Lg ->
            "px-6 py-3 text-base"


variantClasses : Variant -> String
variantClasses variant =
    case variant of
        Primary ->
            "bg-indigo-600 text-white hover:bg-indigo-700 focus:ring-indigo-500"

        Secondary ->
            "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50 focus:ring-indigo-500"

        Ghost ->
            "text-indigo-600 hover:bg-indigo-50 focus:ring-indigo-500"

        Danger ->
            "bg-red-600 text-white hover:bg-red-700 focus:ring-red-500"
