module HttpUtils exposing (..)

import Http exposing (..)


handleError : Http.Error -> String
handleError error =
    case error of
        Http.BadUrl url ->
            "The URL" ++ url ++ " was invalid"

        Http.Timeout ->
            "Timed out"

        Http.NetworkError ->
            "Network Error"

        Http.BadStatus code ->
            "Status Code: " ++ String.fromInt code

        Http.BadBody message ->
            message
