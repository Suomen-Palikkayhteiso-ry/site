module Components.Pricing exposing (Tier, view)

import Html exposing (Html)
import Html.Attributes as Attr


type alias Tier msg =
    { name : String
    , price : String
    , period : Maybe String
    , features : List String
    , cta : Html msg
    , highlighted : Bool
    }


view : List (Tier msg) -> Html msg
view tiers =
    Html.div
        [ Attr.class "py-12" ]
        [ Html.div
            [ Attr.class "grid gap-8 sm:grid-cols-2 lg:grid-cols-3" ]
            (List.map viewTier tiers)
        ]


viewTier : Tier msg -> Html msg
viewTier tier =
    Html.div
        [ Attr.class (tierClasses tier.highlighted) ]
        [ Html.div [ Attr.class "p-8" ]
            [ Html.h3
                [ Attr.class (tierNameClass tier.highlighted) ]
                [ Html.text tier.name ]
            , Html.div [ Attr.class "mt-4 flex items-baseline gap-x-2" ]
                [ Html.span
                    [ Attr.class (priceClass tier.highlighted) ]
                    [ Html.text tier.price ]
                , case tier.period of
                    Just p ->
                        Html.span
                            [ Attr.class (periodClass tier.highlighted) ]
                            [ Html.text ("/ " ++ p) ]

                    Nothing ->
                        Html.text ""
                ]
            , Html.ul
                [ Attr.class "mt-8 space-y-3" ]
                (List.map (viewFeature tier.highlighted) tier.features)
            , Html.div [ Attr.class "mt-8" ] [ tier.cta ]
            ]
        ]


viewFeature : Bool -> String -> Html msg
viewFeature highlighted feature =
    Html.li
        [ Attr.class "flex items-center gap-x-3 text-sm" ]
        [ Html.span
            [ Attr.class
                (if highlighted then
                    "text-indigo-200 text-base"

                 else
                    "text-green-500 text-base"
                )
            ]
            [ Html.text "✓" ]
        , Html.span
            [ Attr.class
                (if highlighted then
                    "text-white"

                 else
                    "text-gray-700"
                )
            ]
            [ Html.text feature ]
        ]


tierClasses : Bool -> String
tierClasses highlighted =
    "rounded-2xl border overflow-hidden "
        ++ (if highlighted then
                "bg-indigo-600 border-indigo-600"

            else
                "bg-white border-gray-200 shadow-sm"
           )


tierNameClass : Bool -> String
tierNameClass highlighted =
    "text-lg font-semibold "
        ++ (if highlighted then
                "text-white"

            else
                "text-gray-900"
           )


priceClass : Bool -> String
priceClass highlighted =
    "text-4xl font-bold tracking-tight "
        ++ (if highlighted then
                "text-white"

            else
                "text-gray-900"
           )


periodClass : Bool -> String
periodClass highlighted =
    "text-sm font-semibold "
        ++ (if highlighted then
                "text-indigo-200"

            else
                "text-gray-500"
           )
