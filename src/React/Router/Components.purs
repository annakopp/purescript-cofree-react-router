module React.Router.Components
  ( Location
  , BrowserRouter(..)
  , browserRouter
  , browserRouterClass
  , LinkProps(LinkProps)
  , linkSpec
  , linkClass
  , link
  , link'
  , goto
  ) where


import Control.Comonad.Cofree (Cofree)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Console (CONSOLE, error)
import Control.Monad.Eff.Exception (EXCEPTION, catchException)
import Control.Monad.Eff.Unsafe (unsafeCoerceEff)
import DOM (DOM)
import DOM.Event.EventTarget (addEventListener, dispatchEvent, eventListener)
import DOM.Event.Types (Event)
import DOM.HTML (window)
import DOM.HTML.Event.EventTypes (popstate)
import DOM.HTML.History (DocumentTitle(..), URL(..), pushState)
import DOM.HTML.Location (hash, pathname, search)
import DOM.HTML.Types (HISTORY, windowToEventTarget)
import DOM.HTML.Window (history, location)
import Data.Foreign (toForeign)
import Data.List (List)
import Data.Maybe (Maybe(..), fromMaybe, isNothing, maybe, maybe')
import Data.Newtype (un)
import Data.Tuple (Tuple)
import Prelude (Unit, bind, const, discard, pure, show, unit, void, ($), (<$>), (<<<), (<>), (>>=), (||))
import React (ReactClass, ReactElement, ReactProps, ReactRefs, ReactSpec, ReactState, ReadOnly, ReadWrite, createClass, createElement, getChildren, getProps, preventDefault, readState, spec, spec', writeState)
import React.DOM (a, div')
import React.DOM.Props (Props, href, onClick)
import React.Router.Routing (runRouter)
import React.Router.Types (class RoutePropsClass, IndexRoute, Route, RouterConfig(RouterConfig))
import React.Router.Utils (hasBaseName, joinUrls, stripBaseName, warning)

-- | RouterState type
newtype Location = Location
  { pathname :: URL
  , search :: String
  , hash :: String
  }

-- | BrowserRouter prop type
newtype BrowserRouter props arg notFoundProps = BrowserRouter
  { router :: Cofree List (Tuple (Route props arg) (Maybe (IndexRoute props arg)))
  , config :: RouterConfig
  , notFound :: Maybe
    { cls :: ReactClass notFoundProps
    , props :: notFoundProps
    }
  }

foreign import createPopStateEvent :: URL -> Event

getLocation
  :: forall e
   . Eff (dom :: DOM, console :: CONSOLE | e) Location
getLocation = do
  l <- window >>= location
  h <- hash l
  p <- pathname l
  s <- search l
  pure $ Location { hash: h, pathname: (URL p), search: s }

runLocation :: Location -> URL
runLocation (Location { pathname: URL pathname, search, hash }) = URL $ pathname <> search <> hash

stripBaseNameL :: Maybe URL -> Location -> Location
stripBaseNameL a (Location b) = Location (b { pathname = stripBaseName a b.pathname })

-- | `ReactSpec` for the `browserRouterClass` - the main entry point react
-- | class for the router.
browserRouter
  :: forall eff props arg notfound
   . (RoutePropsClass props arg)
  => ReactSpec (BrowserRouter props arg notfound) Location (history :: HISTORY, dom :: DOM, console :: CONSOLE | eff)
browserRouter = (spec' initialState render) { displayName = "BrowserRouter", componentWillMount = componentWillMount }
  where
    initialState this = do
      BrowserRouter { config: RouterConfig { baseName } } <- getProps this
      stripBaseNameL baseName <$> getLocation

    renderNotFound props =
      maybe' (const $ div' []) (\nf -> createElement nf.cls nf.props []) props.notFound

    render this = do
      BrowserRouter props <- getProps this
      loc <- readState this
      case runRouter (runLocation loc) props.router of
        Nothing -> do
          warning false ("Router did not found path '" <> un URL (runLocation loc) <> "'")
          pure $ renderNotFound props
        Just el -> pure el

    componentWillMount this =
      window >>= addEventListener popstate (eventListener $ handler this) false <<< windowToEventTarget

    handler this ev = do
      BrowserRouter { config: RouterConfig { baseName } } <- getProps this
      cur <- readState this
      loc' <- getLocation
      let to' = runLocation loc'
          loc = stripBaseNameL baseName loc'
      warning
        (isNothing baseName || hasBaseName baseName to')
        ("""You are using baseName on a page which URL path does not begin with.  Expecting path: """
         <> un URL to' <> " to begin with: " <> (maybe "" (un URL) baseName))
      void $ writeState this loc

-- | React class for the `browerRouter` element.  Use it to init your application.
-- | ```purescript
-- |  router = ... :: Router _
-- |  main = void $ elm >>= render (createElement browserRouterClass {router, notFound: Nothing} [])
-- |    where
-- |      elm = do
-- |        elm_ <- window >>= document >>= getElementById (ElementId "app") <<< documentToNonElementParentNode <<< htmlDocumentToDocument
-- |        pure $ unsafePartial fromJust (toMaybe elm_)
-- |  ```
browserRouterClass
  :: forall props arg notfound
   . (RoutePropsClass props arg)
  => ReactClass (BrowserRouter props arg notfound)
browserRouterClass = createClass browserRouter

newtype LinkProps eff = LinkProps
  { url :: URL
  , props :: Array Props
  , action :: Eff (props :: ReactProps, refs :: ReactRefs ReadOnly, state :: ReactState ReadWrite | eff) Unit
  }

-- | `ReactSpec` for the `link` element; it takes a record of type `LinkProps`
-- | as properties.  The `props` record property is directly passed to underlying
-- | `a` element, e.g. this can be used to add css classes.
linkSpec :: forall eff. ReactSpec (LinkProps eff) Unit ()
linkSpec = (spec unit render) { displayName = "Link" }
  where
    render this = do
      LinkProps p <- getProps this
      chrn <- getChildren this
      pure $ a
        ([href (un URL p.url), (onClick $ clickHandler this)] <> p.props)
        chrn

    clickHandler this ev = do
      _ <- preventDefault ev
      LinkProps { action } <- getProps this
      action

-- | React class for the `link` element.
linkClass :: forall eff. ReactClass (LinkProps eff)
linkClass = createClass linkSpec

-- | `link` element; use it instead of `a` to route the user through
-- | application with the default action `goto cfg url` and custom properties.
link :: RouterConfig -> URL -> Array Props -> Array ReactElement -> ReactElement
link cfg url props = createElement linkClass (LinkProps { url, props, action: goto cfg url})

-- | as `link`, but with empty props.
link' :: RouterConfig -> URL -> Array ReactElement -> ReactElement
link' cfg url = link cfg url []

-- | goto url
goto
  :: forall eff
   . RouterConfig
  -> URL
  -> Eff ( console :: CONSOLE
         , dom :: DOM
         , history :: HISTORY
         | eff
         ) Unit
goto cfg url = catchException
  (error <<< show)
  (do
    w <- window
    h <- history w
    let url_ = joinUrls (fromMaybe (URL "") (un RouterConfig cfg).baseName) url
    pushState (toForeign unit) (DocumentTitle (un URL url_)) url_ h
    void $ coerceEff $ dispatchEvent (createPopStateEvent url) (windowToEventTarget w))
  where
    coerceEff :: forall e a. Eff (err :: EXCEPTION | e) a -> Eff (exception :: EXCEPTION | e) a
    coerceEff = unsafeCoerceEff
