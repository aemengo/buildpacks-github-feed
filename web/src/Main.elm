module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Task exposing (Task)
import Time
import Json.Decode exposing (Decoder)

main =
  Browser.element
    { init = init
    , update = update
    , subscriptions = always Sub.none
    , view = view
    }

-- INIT
init : () -> (Model, Cmd Msg)
init _ =
  (Loading, getIssues "pack")

-- VARS
host : String
host = "https://api.github.com"

token : String
token = ""

repos : List String
repos =
    [ "pack"
    , "lifecycle"
    , "rfcs"
    , "spec"
    , "imgutil"
    , "docs"
    ]

-- HTTP
issueDecoder : Decoder Issue
issueDecoder =
    Json.Decode.map5 Issue
        (Json.Decode.at [ "number" ] Json.Decode.int)
        (Json.Decode.at [ "url" ] Json.Decode.string)
        (Json.Decode.at [ "title" ] Json.Decode.string)
        (Json.Decode.at [ "user", "login" ] Json.Decode.string)
        (Json.Decode.at [ "user", "avatar_url" ] Json.Decode.string)


getIssues : String -> Cmd Msg
getIssues repo =
    Http.get
        { url = host ++ "/repos/buildpacks/" ++ repo ++ "/issues/564?sort=comments&direction=desc&per_page=5"
        , expect = Http.expectJson DataReceived issueDecoder
        }

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
            "Status Code: " ++ String.fromInt(code)
        Http.BadBody message ->
            message

-- MODEL
type Model
    = Loading
    | Success Issue
    | Failure String

type alias Issue =
    { id : Int
    , url : String
    , title : String
    , user : String
    , userAvatar : String
    }

    --, isPr : Bool
    --, createdAt : String
    --, updatedAt : String

type alias Comments =
    { user : String
    , text : String
    , createdAt : Time.Posix
    , updatedAt : Time.Posix
    }

-- UPDATE
type Msg = DataReceived (Result Http.Error Issue)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        DataReceived result ->
            case result of
                Ok issue ->
                    (Success issue, Cmd.none)

                Err err ->
                    (Failure (handleError err), Cmd.none)

-- VIEW
view : Model -> Html Msg
view model =
    case model of
        Loading ->
            text "Loading..."
        Failure txt ->
            text txt
        Success issue ->
            div [ class "container" ]
                [ div [ class "row" ]
                    [ div [ class "col-md-12" ]
                        [ ul [ class "list-group" ]
                                [ li [ class "list-group-item" ]
                                    [ div [ class "d-flex" ]
                                          [ div [ class "flex-shrink-0" ]
                                            [ img [ class "rounded-circle", height 48, width 48, src issue.userAvatar, alt issue.user ] []
                                            ]
                                            , div [ class "flex-grow-1 ms-3" ]
                                                [ h6 [] [ text ( "(#" ++ (String.fromInt issue.id) ++ ") pack . " ++ issue.user) ]
                                                , text issue.title
                                                ]
                                          ]
                                    ]
                                , li [ class "list-group-item" ]
                                    [ img [ class "ms-3 me-2", src "./assets/img/arrow-return-right.svg", alt "arrow-return-right", width 16, height 16 ] []
                                    , text "(7 months ago) micahyoung: I'm happy to take a first pass..."
                                    ]
                                , li [ class "list-group-item" ]
                                    [ img [ class "ms-3 me-2", src "./assets/img/arrow-return-right.svg", alt "arrow-return-right", width 16, height 16 ] []
                                    , text "(5 months ago) aemengo: This be another comment..."
                                    ]
                                ]
                        ]
                    ]
                ]



