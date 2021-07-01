module Main exposing (main)

import Browser
import Decoders exposing (repoDecoder)
import Html exposing (..)
import Html.Attributes exposing (..)
import Http
import HttpUtils exposing (..)
import Json.Decode as D
import Models exposing (..)
import String.Extra exposing (ellipsis)
import Svg exposing (path, svg)
import Svg.Attributes exposing (d, fill, fillRule, viewBox)
import Time


main =
    Browser.element
        { init = init
        , update = update
        , subscriptions = subscriptions
        , view = view
        }



-- INIT


init : () -> ( Model, Cmd Msg )
init _ =
    ( Success [], getData )



-- UPDATE


type Msg
    = Tick Time.Posix
    | DataReceived (Result Http.Error (List Repo))


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Tick _ ->
            ( model, getData )

        DataReceived result ->
            case result of
                Ok data ->
                    ( Success data, Cmd.none )

                Err err ->
                    ( Failure (handleError err), Cmd.none )


getData : Cmd Msg
getData =
    Http.get
        { url = "/data"
        , expect = Http.expectJson DataReceived (D.list repoDecoder)
        }



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Time.every (5 * 60 * 1000) Tick



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
                                    addIf (reactions.eyes > 0) (span [ class "me-3" ] [ text ("👀️ " ++ String.fromInt reactions.eyes) ]) <|
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
        prAttrs =
            if issue.isPr then
                if issue.isRecent then
                    [ class "text-warning" ]

                else
                    mutedText

            else
                hidden

        draftAttrs =
            if issue.isDraftPr then
                if issue.isRecent then
                    [ class "fw-light fst-italic" ]

                else
                    [ class "fw-light fst-italic text-muted" ]

            else
                hidden

        ( rfcAttrs, userAttrs ) =
            if issue.isRecent then
                ( [], [ class "text-primary fw-bold" ] )

            else
                ( mutedText, mutedText )

        ( imgAttrList, titleAttrs, timeAttrs ) =
            if issue.isRecent then
                ( "rounded-circle", [], [ class "text-success fw-bold" ] )

            else
                ( "rounded-circle grayscale half-visible", mutedText, mutedText )

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
                    , span draftAttrs [ text "draft: " ]
                    , span titleAttrs [ text issue.title ]
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
        refresh =
            svg [ Svg.Attributes.class "text-white-50 me-1 bi bi-arrow-repeat", width 16, height 16, viewBox "0 0 16 16", fill "currentColor" ]
                [ path [ d "M11.534 7h3.932a.25.25 0 0 1 .192.41l-1.966 2.36a.25.25 0 0 1-.384 0l-1.966-2.36a.25.25 0 0 1 .192-.41zm-11 2h3.932a.25.25 0 0 0 .192-.41L2.692 6.23a.25.25 0 0 0-.384 0L.342 8.59A.25.25 0 0 0 .534 9z" ] []
                , path [ d "M8 3c-1.552 0-2.94.707-3.857 1.818a.5.5 0 1 1-.771-.636A6.002 6.002 0 0 1 13.917 7H12.9A5.002 5.002 0 0 0 8 3zM3.1 9a5.002 5.002 0 0 0 8.757 2.182.5.5 0 1 1 .771.636A6.002 6.002 0 0 1 2.083 9H3.1z", fillRule "evenodd" ] []
                ]

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
                , span []
                    [ refresh
                    , small [ class "fw-light fst-italic text-white-50 me-5" ] [ text "5m" ]
                    ]
                ]
            ]
        , div [ class "container" ] content
        ]
