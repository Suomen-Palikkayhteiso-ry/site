module Components.Footer exposing (LinkGroup, view)

import Html exposing (Html)
import Html.Attributes as Attr


type alias LinkGroup =
    { heading : String
    , links : List { label : String, href : String }
    }


view :
    { groups : List LinkGroup
    , copyright : String
    }
    -> Html msg
view config =
    Html.footer
        [ Attr.class "bg-gray-900" ]
        [ Html.div
            [ Attr.class "mx-auto max-w-7xl px-6 py-12 lg:px-8" ]
            [ Html.div
                [ Attr.class "grid grid-cols-2 gap-8 md:grid-cols-4" ]
                (List.map viewGroup config.groups)
            , Html.div
                [ Attr.class "mt-10 border-t border-gray-800 pt-8" ]
                [ Html.p
                    [ Attr.class "text-sm text-gray-400 text-center" ]
                    [ Html.text config.copyright ]
                ]
            ]
        ]


viewGroup : LinkGroup -> Html msg
viewGroup group =
    Html.div []
        [ Html.h3
            [ Attr.class "text-sm font-semibold text-white" ]
            [ Html.text group.heading ]
        , Html.ul
            [ Attr.class "mt-4 space-y-3" ]
            (List.map viewGroupLink group.links)
        ]


viewGroupLink : { label : String, href : String } -> Html msg
viewGroupLink link =
    Html.li []
        [ Html.a
            [ Attr.href link.href
            , Attr.class "text-sm text-gray-400 hover:text-white transition-colors"
            ]
            [ Html.text link.label ]
        ]
