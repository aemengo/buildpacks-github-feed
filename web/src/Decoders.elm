module Decoders exposing (..)

import Json.Decode as D exposing (Decoder)
import Json.Decode.Extra exposing (andMap)
import Models exposing (..)


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
        |> andMap (D.field "is_draft_pr" D.bool)
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
