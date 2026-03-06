module Components.Navbar exposing (NavLink, view)

import Html exposing (Html)
import Html.Attributes as Attr


type alias NavLink =
    { label : String
    , href : String
    }


view :
    { logo : Html msg
    , links : List NavLink
    , action : Maybe (Html msg)
    }
    -> Html msg
view config =
    Html.nav
        [ Attr.class "bg-white border-b border-gray-200" ]
        [ Html.div
            [ Attr.class "mx-auto max-w-7xl px-6 lg:px-8" ]
            [ Html.div
                [ Attr.class "flex h-16 items-center justify-between" ]
                [ Html.div [ Attr.class "flex items-center gap-x-8" ]
                    [ config.logo
                    , Html.div [ Attr.class "hidden md:flex items-center gap-x-6" ]
                        (List.map viewLink config.links)
                    ]
                , case config.action of
                    Just btn ->
                        Html.div [] [ btn ]

                    Nothing ->
                        Html.text ""
                ]
            ]
        ]


viewLink : NavLink -> Html msg
viewLink link =
    Html.a
        [ Attr.href link.href
        , Attr.class "text-sm font-medium text-gray-600 hover:text-gray-900 transition-colors"
        ]
        [ Html.text link.label ]
