module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as D exposing (Decoder)
import Json.Decode.Extra exposing (andMap)
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
  (Success [], getData)

-- JSON
repoDecoder : Decoder Repo
repoDecoder =
    D.map2 Repo
        (D.field "repo" D.string)
        (D.field "issues" (D.list issueDecoder))

issueDecoder : Decoder Issue
issueDecoder =
    D.succeed Issue
        |> andMap (D.field "number" D.int)
        |> andMap (D.field "title" D.string)
        |> andMap (D.field "body" D.string)
        |> andMap (D.field "url" D.string)
        |> andMap (D.field "user" D.string)
        |> andMap (D.field "user_avatar_url" D.string)
        |> andMap (D.field "is_pr" D.bool)
        |> andMap (D.field "is_recent" D.bool)
        |> andMap (D.field "created_at_humanized" D.string)
        |> andMap (D.field "comments" (D.list commentDecoder))
        |> andMap (D.field "reactions" reactionsDecoder)

commentDecoder : Decoder Comment
commentDecoder =
    D.map5 Comment
        (D.field "user" D.string)
        (D.field "url" D.string)
        (D.field "created_at_humanized" D.string)
        (D.field "body" D.string)
        (D.field "is_recent" D.bool)

reactionsDecoder : Decoder Reactions
reactionsDecoder =
    D.map8 Reactions
        (D.field "+1" D.int)
        (D.field "-1" D.int)
        (D.field "laugh" D.int)
        (D.field "confused" D.int)
        (D.field "heart" D.int)
        (D.field "hooray" D.int)
        (D.field "rocket" D.int)
        (D.field "eyes" D.int)

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
    = Success (List Repo)
    | Failure String

type alias Repo =
    { name : String
    , issues : List Issue
    }

type alias Issue =
    { number : Int
    , title : String
    , body : String
    , url : String
    , user : String
    , userAvatarUrl : String
    , isPr : Bool
    , isRecent : Bool
    , createdAtHumanized : String
    , comments : List Comment
    , reactions : Reactions
    }

type alias Comment =
    { user : String
    , url : String
    , createdAtHumanized : String
    , body : String
    , isRecent : Bool
    }

type alias Reactions =
    { plusOne : Int
    , minusOne : Int
    , laugh : Int
    , confused : Int
    , heart : Int
    , hooray : Int
    , rocket : Int
    , eyes : Int
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
addIf : Bool -> a -> List a -> List a
addIf condition value list =
    if condition then
        value :: list
    else
        list

viewReactions : Reactions -> Html msg
viewReactions reactions =
    div [ class "flex-shrink-0" ]
        (
            (addIf (reactions.plusOne > 0) (span [ class "me-3" ] [ text ("👍 " ++ (String.fromInt reactions.plusOne)) ])
                <| addIf (reactions.minusOne > 0) (span [ class "me-3" ] [ text ("👎 " ++ (String.fromInt reactions.minusOne)) ])
                <| addIf (reactions.laugh > 0) (span [ class "me-3" ] [ text ("😄 " ++ (String.fromInt reactions.laugh)) ])
                <| addIf (reactions.hooray > 0) (span [ class "me-3" ] [ text ("🎉️ " ++ (String.fromInt reactions.hooray)) ])
                <| addIf (reactions.confused > 0) (span [ class "me-3" ] [ text ("😕️ " ++ (String.fromInt reactions.confused)) ])
                <| addIf (reactions.heart > 0) (span [ class "me-3" ] [ text ("❤️ " ++ (String.fromInt reactions.heart)) ])
                <| addIf (reactions.rocket > 0) (span [ class "me-3" ] [ text ("🚀️ " ++ (String.fromInt reactions.rocket)) ])
                <| addIf (reactions.eyes > 0) (span [ class "me-3" ] [ text ("👀️ " ++ (String.fromInt reactions.heart)) ])
                <| []
            )
        )

viewComment : Comment -> Html msg
viewComment comment =
    let
        timeAttrs = if comment.isRecent then "text-success fw-bold" else "text-success"
    in
    a [ class "list-group-item bg-light", href comment.url, target "_blank" ]
        [ img [ class "ms-3 me-2", src "/assets/img/arrow-return-right.svg", alt "arrow-return-right", width 16, height 16 ] []
        , span [ class timeAttrs ] [ text ("(" ++ comment.createdAtHumanized ++ ") ") ]
        , span [ class "text-primary fw-bold" ] [ text (comment.user ++ ": ") ]
        , text (ellipsis 75 comment.body)
    ]

viewIssue : Issue -> Html msg
viewIssue issue =
    let
        prAttrs = if issue.isPr then "text-warning" else "d-none"
        timeAttrs = if issue.isRecent then "text-success fw-bold" else "fw-normal"
    in
    ul [ class "list-group mt-1" ]
        (
            (a [ class "list-group-item list-group-item-action", href issue.url, target "_blank" ]
                [ div [ class "d-flex" ]
                      [ div [ class "flex-shrink-0" ]
                        [ img [ class "rounded-circle", height 48, width 48, src issue.userAvatarUrl, alt issue.user ] []
                        ]
                        , div [ class "flex-grow-1 ms-3" ]
                            [ h6 []
                                [ span [] [ text ("(#" ++ (String.fromInt issue.number) ++ ") ") ]
                                , span [ class prAttrs ] [ text " [PR] " ]
                                , span [ class "text-primary fw-bold" ] [ text issue.user ]
                                , span [ class timeAttrs ] [ text (" (" ++ issue.createdAtHumanized ++")") ]
                                ]
                            , span [] [ text issue.title ]
                            , br [] []
                            , span [ class "fw-light text-secondary" ] [ text (ellipsis 75 issue.body) ]
                            ]
                        , viewReactions issue.reactions
                      ]
                ]
            ) :: (List.map viewComment issue.comments)
        )

viewRepo : Repo -> Html msg
viewRepo repo =
    div [ class "row mb-5 me-5", id repo.name ]
        [ div [ class "col-md-3" ] [ h4 [ class "text-center text-black-50" ] [ text repo.name] ]
        , div [ class "col-md" ] (List.map viewIssue repo.issues)
        ]

view : Model -> Html msg
view model =
    let
        content =
            case model of
              Failure txt ->
                  [ text txt ]
              Success repos ->
                if List.length repos == 0 then
                    [ text "Try reloading after a few seconds.. 😉" ]
                else
                    (List.map viewRepo repos)
    in
    div [ class "feed" ]
        [ nav [ class "navbar fixed-top navbar-dark bg-dark" ]
            [ div [ class "container-fluid" ]
                [ a [ class "navbar-brand", href "#" ]
                    [ img [ src "/assets/img/buildpacks-icon.png", alt "logo", width 30, height 25, class "d-inline-block align-text-top mx-4" ] []
                    , text "Activity"
                    ]
                ]
            ]
        , div [ class "container" ] content
        ]
