module Frontmatter exposing (Frontmatter, decoder)

import Json.Decode as Decode exposing (Decoder)


type alias Frontmatter =
    { title : String
    , description : String
    , slug : String
    , published : Bool
    }


decoder : Decoder Frontmatter
decoder =
    Decode.map4 Frontmatter
        (Decode.field "title" Decode.string)
        (Decode.field "description" Decode.string)
        (Decode.field "slug" Decode.string)
        (Decode.field "published" Decode.bool)
