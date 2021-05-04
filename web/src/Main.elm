module Main exposing (main)

import Browser
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import Json.Decode as D exposing (Decoder)
import Json.Decode.Extra exposing (andMap)
import String.Extra exposing (ellipsis)
import Svg exposing (path, svg)
import Svg.Attributes exposing (d, fill, viewBox)


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = always Sub.none
        , view = view
        }



-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( Success [], getData )



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
        |> andMap (D.field "check_suites" (D.list checkSuiteDecoder))


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


checkSuiteDecoder : Decoder CheckSuite
checkSuiteDecoder =
    D.map2 CheckSuite
        (D.field "id" D.int)
        (D.field "checks" (D.list checkDecoder))


checkDecoder : Decoder Check
checkDecoder =
    D.map3 Check
        (D.field "id" D.int)
        (D.field "status" D.string)
        (D.field "conclusion" D.string)



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
            "Status Code: " ++ String.fromInt code

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
    , checkSuites : List CheckSuite
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


type alias CheckSuite =
    { id : Int
    , checks : List Check
    }


type alias Check =
    { id : Int
    , status : String
    , conclusion : String
    }



-- UPDATE


type Msg
    = DataReceived (Result Http.Error (List Repo))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg _ =
    case msg of
        DataReceived result ->
            case result of
                Ok data ->
                    ( Success data, Cmd.none )

                Err err ->
                    ( Failure (handleError err), Cmd.none )



-- VIEW


mutedText : List (Attribute msg)
mutedText =
    [ class "fw-light text-muted" ]


hidden : List (Attribute msg)
hidden =
    [ class "d-none" ]


addIf : Bool -> a -> List a -> List a
addIf condition value list =
    if condition then
        value :: list

    else
        list


viewCheckRun : Check -> Html msg
viewCheckRun check =
    let
        success =
            svg [ Svg.Attributes.class "text-success bi bi-check", width 16, height 16, viewBox "0 0 16 16", fill "currentColor" ]
                [ path [ d "M10.97 4.97a.75.75 0 0 1 1.07 1.05l-3.99 4.99a.75.75 0 0 1-1.08.02L4.324 8.384a.75.75 0 1 1 1.06-1.06l2.094 2.093 3.473-4.425a.267.267 0 0 1 .02-.022z" ] []
                ]

        failure =
            svg [ Svg.Attributes.class "text-danger bi bi-x", width 16, height 16, viewBox "0 0 16 16", fill "currentColor" ]
                [ path [ d "M4.646 4.646a.5.5 0 0 1 .708 0L8 7.293l2.646-2.647a.5.5 0 0 1 .708.708L8.707 8l2.647 2.646a.5.5 0 0 1-.708.708L8 8.707l-2.646 2.647a.5.5 0 0 1-.708-.708L7.293 8 4.646 5.354a.5.5 0 0 1 0-.708z" ] []
                ]

        pending =
            svg [ Svg.Attributes.class "text-warning bi bi-dot", width 16, height 16, viewBox "0 0 16 16", fill "currentColor" ]
                [ path [ d "M8 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z" ] []
                ]

        skipped =
            svg [ Svg.Attributes.class "text-muted bi bi-dot", width 16, height 16, viewBox "0 0 16 16", fill "currentColor" ]
                [ path [ d "M8 9.5a1.5 1.5 0 1 0 0-3 1.5 1.5 0 0 0 0 3z" ] []
                ]
    in
    case check.status of
        "completed" ->
            case check.conclusion of
                "success" ->
                    success

                "skipped" ->
                    skipped

                _ ->
                    failure

        _ ->
            pending


viewCheckSuite : CheckSuite -> Html msg
viewCheckSuite checkSuite =
    span [ class "me-1 badge rounded-pill bg-light" ] (List.map viewCheckRun checkSuite.checks)


viewReactions : Issue -> Reactions -> Html msg
viewReactions issue reactions =
    let
        reactionsAttrs =
            if issue.isRecent then
                [ class "flex-shrink-0" ]

            else
                [ class "flex-shrink-0 grayscale half-visible" ]
    in
    div reactionsAttrs
        (addIf (reactions.plusOne > 0) (span [ class "me-3" ] [ text ("👍 " ++ String.fromInt reactions.plusOne) ]) <|
            addIf (reactions.minusOne > 0) (span [ class "me-3" ] [ text ("👎 " ++ String.fromInt reactions.minusOne) ]) <|
                addIf (reactions.laugh > 0) (span [ class "me-3" ] [ text ("😄 " ++ String.fromInt reactions.laugh) ]) <|
                    addIf (reactions.hooray > 0) (span [ class "me-3" ] [ text ("🎉️ " ++ String.fromInt reactions.hooray) ]) <|
                        addIf (reactions.confused > 0) (span [ class "me-3" ] [ text ("😕️ " ++ String.fromInt reactions.confused) ]) <|
                            addIf (reactions.heart > 0) (span [ class "me-3" ] [ text ("❤️ " ++ String.fromInt reactions.heart) ]) <|
                                addIf (reactions.rocket > 0) (span [ class "me-3" ] [ text ("🚀️ " ++ String.fromInt reactions.rocket) ]) <|
                                    addIf (reactions.eyes > 0) (span [ class "me-3" ] [ text ("👀️ " ++ String.fromInt reactions.heart) ]) <|
                                        []
        )


viewComment : Comment -> Html msg
viewComment comment =
    let
        ( timeAttrs, userAttrs, bodyAttrs ) =
            if comment.isRecent then
                ( [ class "text-success fw-bold" ], [ class "text-primary fw-bold" ], [] )

            else
                ( mutedText, mutedText, mutedText )

        arrowClassAttrList =
            if comment.isRecent then
                "ms-3 me-2"

            else
                "ms-3 me-2 half-visible"
    in
    a [ class "list-group-item bg-light", href comment.url, target "_blank" ]
        [ img [ class arrowClassAttrList, src "/assets/img/arrow-return-right.svg", alt "arrow-return-right", width 16, height 16 ] []
        , span timeAttrs [ text ("(" ++ comment.createdAtHumanized ++ ") ") ]
        , span userAttrs [ text (comment.user ++ ": ") ]
        , span bodyAttrs [ text (ellipsis 75 comment.body) ]
        ]


viewIssue : Issue -> Html msg
viewIssue issue =
    let
        prClassList =
            if issue.isPr then
                "text-warning"

            else
                "d-none"

        ( rfcAttrs, prAttrs, userAttrs ) =
            if issue.isRecent then
                ( [], [ class prClassList ], [ class "text-primary fw-bold" ] )

            else
                ( mutedText, mutedText, mutedText )

        ( imgAttrList, titleAttrs, timeAttrs ) =
            if issue.isRecent then
                ( "rounded-circle", [], [ class "text-success fw-bold" ] )

            else
                ( "rounded-circle grayscale half-visible", [ class "fw-secondary text-muted" ], mutedText )

        checkSuitAttrs =
            if issue.isPr then
                [ class "mt-2" ]

            else
                hidden
    in
    ul [ class "list-group mt-1" ]
        (a [ class "list-group-item list-group-item-action", href issue.url, target "_blank" ]
            [ div [ class "d-flex" ]
                [ div [ class "flex-shrink-0" ]
                    [ img [ class imgAttrList, height 48, width 48, src issue.userAvatarUrl, alt issue.user ] []
                    ]
                , div [ class "flex-grow-1 ms-3" ]
                    [ h6 []
                        [ span rfcAttrs [ text ("(#" ++ String.fromInt issue.number ++ ") ") ]
                        , span prAttrs [ text " [PR] " ]
                        , span userAttrs [ text issue.user ]
                        , span timeAttrs [ text (" (" ++ issue.createdAtHumanized ++ ")") ]
                        ]
                    , span titleAttrs [ text issue.title ]
                    , br [] []
                    , span [ class "fw-light text-secondary" ] [ text (ellipsis 75 issue.body) ]
                    , div checkSuitAttrs (List.map viewCheckSuite issue.checkSuites)
                    ]
                , viewReactions issue issue.reactions
                ]
            ]
            :: List.map viewComment issue.comments
        )


viewRepo : Repo -> Html msg
viewRepo repo =
    div [ class "row mb-5 me-5", id repo.name ]
        [ div [ class "col-md-3" ] [ h4 [ class "text-center text-black-50" ] [ text repo.name ] ]
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
                        List.map viewRepo repos
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
