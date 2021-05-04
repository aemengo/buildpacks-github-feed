module Models exposing (..)


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
