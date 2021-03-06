module Updater exposing (converter, Updater, Converter, Interface, toCmd, noReaction)

{-| Helps you to more easily organize and update nested child components.
    The usual boilerplate has been reduced drastically.

See the `/examples` folder for usage examples.

@docs Interface, converter, Converter, Updater, toCmd, noReaction

-}

import Task
import Maybe

{-| An Interface describes how to communicate between a parent and child component.
You must supply four functions:
* `get` - retrieves the child component model from the parent's model.
* `set` - takes the child model and parent model, and returns the parent model with the updated child model.
* `update` - the standard update function for the component.
* `react` - a function that allows the parent to react to any messages that occur in the child component. Its arguments are the child's message, the child's updated model, and the parent's updated model.
-}
type alias Interface pModel pMsg cModel cMsg =
    { get : ( pModel -> Maybe cModel )
    , set : ( cModel -> pModel -> pModel )
    , update : ( cMsg -> cModel -> ( cModel, Cmd cMsg ) )
    , react : ( cMsg -> cModel -> pModel -> ( pModel, Cmd pMsg ) ) }
--

type alias UpdaterMsg pModel pMsg =
    ((Updater pModel pMsg) -> pMsg)
--
{-| You need to create one message in the parent component that takes an `Updater` as
  an argument. This one message will handle all the internal updating for all of your
  child components.

For example:
```elm
type Msg = Increment
         | SetTo Int
         | UpdaterMsg (Updater Model Msg)
```
Then, in your `update` function:
```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
      Increment -> ...

      SetTo n -> ...

      UpdaterMsg u -> u model
```
An `Updater` is a function automatically generated by converters, constructed with a child's 
message and an Interface for handling a child's type. Feed the parent's model into an
`Updater` and it will pop out a model with the updated child.
-}
type alias Updater pModel pMsg =
    pModel -> ( pModel, Cmd pMsg )
--

{-| Converters are functions that take a child component's message and converts it
into the parent message that handles `Updater`s. To use a Converter, just `map` it onto
any instance of a child's message.

You can use the same converter for anything that takes a message and has a `map` function:
* use it in `subscription` with `Sub.map`
* use it in `view` with `Html.map`
* use it in `init` and `update` with `Cmd.map`

So, supposing you were displaying a `Timer` component in your view, and you had a 
`Converter Msg Timer.Msg` named `timer1C`, you could do this in your view function:

```elm
view model =
  div [] [...
         , Html.map timer1C <| Timer.view model.timer1
         ... ]
```
You can also use it to issue commands to child components within a parent's `update` function.
For example, suppose `Timer.Reset` is part of `Timer.Msg`:

```elm
update msg model =
  case msg of
    ...
    ResetTimer -> model ! [ Cmd.map timer1C <| toCmd Timer.Reset ]
```
-}
type alias Converter pMsg cMsg =
    cMsg -> pMsg
--

{-|
`converter` creates a `Converter`. It's first argument is the Msg constructor that 
handles Updaters. The second argument is the `Interface` to the child component.

For example. let's say our parent's Model and Msg are these:
```elm
type alias Model = { timer1 : Timer.Model
                   , ...}

type Msg = UpdaterMsg (Updater Model Msg)
```
To make a Converter for timer1:

```elm
timer1C : Converter Msg Timer.Msg
timer1C = converter
          UpdaterMsg
          { get = Just << .timer1
          , set = (\ cm m -> { m | timer1 = cm } )
          , update = Timer.update
          , react = noReaction }
```
Then you can use `map` and `timer1C` to converter any Timer messages.

What if you have multiple Timer models stored in a dictionary `Dict Int Timer.Model`, which is stored in your model at `model.timers`?

```elm
timerC : Int -> Converter Msg Timer.Msg
timerC n = converter
           UpdaterMsg
           { get = (\ model -> Dict.get n model.timers )
           , set = (\ cModel pModel -> { pModel | timers =
                                             Dict.insert n cModel pModel.timers } )
           , update = Timer.update
           , react = noReaction }
```
Then you can use something like `map (timerC 4) ...` to convert any messages for the
timer with the id of `4`. 
-}
converter : UpdaterMsg pModel pMsg
          -> Interface pModel pMsg cModel cMsg
          -> Converter pMsg cMsg
converter cons i =
    (\ cMsg -> cons (makeUpdater cons i cMsg))
--

{-| Convenience function to convert a message into a Cmd.
It's useful for emitting commands in the `react` function.

Be careful that you don't create any Cmd message loops!
-}
toCmd : msg -> Cmd msg
toCmd msg = Task.perform identity identity <| Task.succeed msg

--

makeUpdater : UpdaterMsg pModel pMsg
            -> Interface pModel pMsg cModel cMsg
            -> cMsg
            -> Updater pModel pMsg
makeUpdater cons i cMsg =
    (\ model ->
         Maybe.withDefault ( model, Cmd.none ) <|
         (i.get model) `Maybe.andThen`
         (\ gotcModel -> Just <|
              let (cModel, cCmd) = i.update cMsg gotcModel
                  (rModel, rCmd) = i.react cMsg cModel (i.set cModel model)
              in
                  rModel ! [ Cmd.map (\ m -> cons (makeUpdater cons i m)) cCmd
                           , rCmd]))
--

{-| use in an `Interface` for `react` when you don't want to react to any of the child's messages. -}
noReaction : cMsg -> cModel -> pModel -> ( pModel, Cmd pMsg )
noReaction _ _ model = ( model, Cmd.none )
