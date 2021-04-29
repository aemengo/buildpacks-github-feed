module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as D exposing (Decoder)
import String.Extra exposing (ellipsis)

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
  (Loading, getData)

-- JSON
repoDecoder : Decoder Repo
repoDecoder =
    D.map2 Repo
        (D.field "repo" D.string)
        (D.field "issues" (D.list issueDecoder))

issueDecoder : Decoder Issue
issueDecoder =
    D.map8 Issue
        (D.field "number" D.int)
        (D.field "title" D.string)
        (D.field "url" D.string)
        (D.field "user" D.string)
        (D.field "user_avatar_url" D.string)
        (D.field "is_pr" D.bool)
        (D.field "created_at_humanized" D.string)
        (D.field "comments" (D.list commentDecoder))

commentDecoder : Decoder Comment
commentDecoder =
    D.map4 Comment
        (D.field "user" D.string)
        (D.field "url" D.string)
        (D.field "created_at_humanized" D.string)
        (D.field "body" D.string)

-- HTTP
getData : Cmd Msg
getData =
    Http.get
        { url = "/data"
        , expect = Http.expectJson DataReceived (D.list repoDecoder)
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
    | Success (List Repo)
    | Failure String

type alias Repo =
    { name : String
    , issues : List Issue
    }

type alias Issue =
    { number : Int
    , title : String
    , url : String
    , user : String
    , userAvatarUrl : String
    , isPr : Bool
    , createdAtHumanized : String
    , comments : List Comment
    }

type alias Comment =
    { user : String
    , url : String
    , createdAtHumanized : String
    , body : String
    }

-- UPDATE
type Msg = DataReceived (Result Http.Error (List Repo))

update : Msg -> Model -> ( Model, Cmd Msg )
update msg _ =
    case msg of
        DataReceived result ->
            case result of
                Ok data ->
                    (Success data, Cmd.none)
                Err err ->
                    (Failure (handleError err), Cmd.none)

-- VIEW
viewComment : Comment -> Html msg
viewComment comment =
    li [ class "list-group-item bg-light" ]
        [ img [ class "ms-3 me-2", src "/assets/img/arrow-return-right.svg", alt "arrow-return-right", width 16, height 16 ] []
        , text ("(" ++ comment.createdAtHumanized ++ ") " ++ comment.user ++ " " ++ (ellipsis 75 comment.body) )
        ]

viewIssue : String -> Issue -> Html msg
viewIssue repoName issue =
    ul [ class "list-group" ]
        (
            (li [ class "list-group-item" ]
                [ div [ class "d-flex" ]
                      [ div [ class "flex-shrink-0" ]
                        [ img [ class "rounded-circle", height 48, width 48, src issue.userAvatarUrl, alt issue.user ] []
                        ]
                        , div [ class "flex-grow-1 ms-3" ]
                            [ h6 [] [ text ( "(#" ++ (String.fromInt issue.number) ++ ") " ++ repoName ++ " " ++ issue.user ++ " (" ++ issue.createdAtHumanized ++")") ]
                            , text issue.title
                            ]
                      ]
                ]
            ) :: (List.map viewComment issue.comments)
        )

viewRepo : Repo -> Html msg
viewRepo repo =
    div [ class "row mb-5 me-5" ]
        [ div [ class "col-md-3" ] [ h4 [ class "text-center text-black-50" ] [ text repo.name] ]
        , div [ class "col-md" ] (List.map (viewIssue repo.name) repo.issues)
        ]

view : Model -> Html Msg
view model =
    case model of
        Loading ->
            text ""
        Failure txt ->
            text txt
        Success repos ->
            div [ class "feed" ]
                [ nav [ class "navbar fixed-top navbar-dark bg-dark" ]
                    [ div [ class "container-fluid" ]
                        [ a [ class "navbar-brand", href "#" ]
                            [ img [ src "/assets/img/buildpacks-icon.png", alt "logo", width 30, height 25, class "d-inline-block align-text-top mx-4" ] []
                            , text "Activity"
                            ]
                        ]
                    ]
                , div [ class "container" ] (List.map viewRepo repos)
                ]
