module Components.Alert exposing (AlertType(..), view)

import Html exposing (Html)
import Html.Attributes as Attr


type AlertType
    = Info
    | Success
    | Warning
    | Error


view : { alertType : AlertType, title : Maybe String, body : List (Html msg) } -> Html msg
view config =
    Html.div
        [ Attr.class (containerClasses config.alertType) ]
        [ Html.div [ Attr.class "flex" ]
            [ Html.div [ Attr.class "flex-shrink-0 text-lg leading-6" ]
                [ Html.text (icon config.alertType) ]
            , Html.div [ Attr.class "ml-3" ]
                (List.filterMap identity
                    [ Maybe.map
                        (\t ->
                            Html.p
                                [ Attr.class ("font-semibold " ++ titleClass config.alertType) ]
                                [ Html.text t ]
                        )
                        config.title
                    , Just
                        (Html.div
                            [ Attr.class ("text-sm " ++ bodyClass config.alertType) ]
                            config.body
                        )
                    ]
                )
            ]
        ]


containerClasses : AlertType -> String
containerClasses alertType =
    "rounded-md p-4 "
        ++ (case alertType of
                Info ->
                    "bg-blue-50"

                Success ->
                    "bg-green-50"

                Warning ->
                    "bg-yellow-50"

                Error ->
                    "bg-red-50"
           )


icon : AlertType -> String
icon alertType =
    case alertType of
        Info ->
            "ℹ"

        Success ->
            "✓"

        Warning ->
            "⚠"

        Error ->
            "✕"


titleClass : AlertType -> String
titleClass alertType =
    case alertType of
        Info ->
            "text-blue-800"

        Success ->
            "text-green-800"

        Warning ->
            "text-yellow-800"

        Error ->
            "text-red-800"


bodyClass : AlertType -> String
bodyClass alertType =
    case alertType of
        Info ->
            "text-blue-700"

        Success ->
            "text-green-700"

        Warning ->
            "text-yellow-700"

        Error ->
            "text-red-700"
