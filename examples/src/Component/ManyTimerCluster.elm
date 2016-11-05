module Component.ManualTimerCluster exposing (Msg (..), Model, init, update, view)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.App as Html
import Html.Events exposing ( onClick )
--import Time exposing (Time, every, second)
--import Random
--import Dict exposing (Dict)
import Component.TaskTimer as TaskTimer
import Component.Many as Many
--import Component.SuperBuzzer as Buzzer

import Updater exposing (converter, Updater, Converter, Interface, toCmd, noReaction)

type alias TimersModel = Many.Model TaskTimer.Model TaskTimer.Msg

type alias TimersMsg = Many.Msg TaskTimer.Model TaskTimer.Msg


type alias Model = { timers : TimersModel }

type Msg = NoOp
         | UpdaterMsg (Updater Model Msg)


timersC : Converter Msg TimersMsg
timersC = converter
           UpdaterMsg
           { get = Just << .timers
           , set = (\ cm model -> { model | timers = cm } )
           , update = Many.update
           , react = noReaction }

--

init : (Model, Cmd Msg)
init = { timers = Many.initModel TaskTimer.update TaskTimer.subscriptions }
    ! [ ]

-- UPDATE
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
      NoOp -> model ! []
      UpdaterMsg u -> u model


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.batch [ Sub.map timersC <| Many.subscriptions model.timers ]

-- VIEW
-- Html is defined as: elem [ attribs ][ children ]
-- CSS can be applied via class names or inline style attrib
view : Model -> Html Msg
view model =
    div []
        [ Html.map timersC <| viewTimers model.timers ]

viewTimers : TimersModel -> Html TimersMsg
viewTimers timers =
    div [ class "timers" ]
        [ div [ style [("height", "420px")]] <|

              timers.viewAll
              (\ id timer conv -> Just <|
                   div [ style [ ("width", "215px")
                               , ("float", "left")
                               , ("height", "320px") ] ]
                   [ conv <| TaskTimer.view timer
                   , button [ onClick <| Many.Delete id ] [ text "Delete" ] ])

        , div [] [ button [ onClick <| Many.Add TaskTimer.init ] [ text "Add Timer" ]]]


{-
            List.map (\ (id, timerModel) ->
                          deletableTimer id <|
                          Html.map (timersC << model.timers.converter id) <|
                          TaskTimer.view timerModel)
            (Dict.toList model.timers.objects)
-}

deletableTimer : Int -> Html Msg -> Html Msg
deletableTimer id html = div [ style [ ("width", "215px")
                                     , ("float", "left")
                                     , ("height", "320px") ] ]
               [ html
               , Html.map timersC <|
                   button [ onClick <| Many.Delete id ] [ text "Delete" ]
               ]


-- APP
main : Program Never
main =
    Html.program { init = init
                 , update = update
                 , subscriptions = subscriptions
                 , view = view }