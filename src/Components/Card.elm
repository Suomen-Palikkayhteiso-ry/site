module Components.Card exposing (Config, Shadow(..), view, viewSimple)

import Html exposing (Html)
import Html.Attributes as Attr


type Shadow
    = None
    | Sm
    | Md
    | Lg


type alias Config msg =
    { header : Maybe (Html msg)
    , body : List (Html msg)
    , footer : Maybe (Html msg)
    , image : Maybe { src : String, alt : String }
    , shadow : Shadow
    }


view : Config msg -> Html msg
view config =
    Html.div
        [ Attr.class (cardClasses config.shadow) ]
        (List.filterMap identity
            [ Maybe.map viewImage config.image
            , Maybe.map viewHeader config.header
            , Just (Html.div [ Attr.class "p-6" ] config.body)
            , Maybe.map viewFooter config.footer
            ]
        )


viewSimple : List (Html msg) -> Html msg
viewSimple body =
    view
        { header = Nothing
        , body = body
        , footer = Nothing
        , image = Nothing
        , shadow = Sm
        }


viewImage : { src : String, alt : String } -> Html msg
viewImage img =
    Html.img
        [ Attr.src img.src
        , Attr.alt img.alt
        , Attr.class "w-full h-48 object-cover rounded-t-lg"
        ]
        []


viewHeader : Html msg -> Html msg
viewHeader content =
    Html.div
        [ Attr.class "px-6 py-4 border-b border-gray-200" ]
        [ content ]


viewFooter : Html msg -> Html msg
viewFooter content =
    Html.div
        [ Attr.class "px-6 py-4 border-t border-gray-200 bg-gray-50 rounded-b-lg" ]
        [ content ]


cardClasses : Shadow -> String
cardClasses shadow =
    "bg-white rounded-lg border border-gray-200 overflow-hidden "
        ++ shadowClass shadow


shadowClass : Shadow -> String
shadowClass shadow =
    case shadow of
        None ->
            ""

        Sm ->
            "shadow-sm"

        Md ->
            "shadow-md"

        Lg ->
            "shadow-lg"
