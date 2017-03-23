module React.Router.Types 
  ( (:+)
  , Hash(Hash)
  , IndexRoute(IndexRoute)
  , PathPart(PathPart)
  , Query
  , Route(Route)
  , RouteClass
  , RouteProps_(..)
  , RouteProps
  , Router
  , URL
  , withoutIndex
  -- lenses
  , urlLens
  , idLens
  , argsLens
  ) where

import Prelude
import Control.Comonad.Cofree ((:<), Cofree)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Data.NonEmpty (NonEmpty)
import Data.StrMap (StrMap)
import Data.Tuple (Tuple(..))
import Optic.Lens (lens)
import Optic.Types (Lens, Lens')
import React (ReactClass)
import Routing.Match (Match) as R
import Routing.Types (Route) as R

newtype PathPart = PathPart String

derive instance newTypePathPart :: Newtype PathPart _

instance showPathPart :: Show PathPart where
  show (PathPart s) = "(PathPart \"" <> s <> "\")"

derive instance eqPathPart :: Eq PathPart

type Query = StrMap String

newtype Hash = Hash String

derive instance newHash :: Newtype Hash _

instance showHash :: Show Hash where
  show (Hash s) = "Hash " <> s

derive instance eqHash :: Eq Hash

-- parsed pathname and query string
type URL = R.Route

newtype RouteProps_ args = RouteProps { id :: String, args :: args }

type RouteProps args = RouteProps_ (NonEmpty Array args)

idLens :: forall args. Lens' (RouteProps_ args) String
idLens = lens (\(RouteProps rp) -> rp.id) (\(RouteProps rp) id -> RouteProps (rp { id=id }))

argsLens :: forall args args'. Lens (RouteProps_ args) (RouteProps_ args') args args'
argsLens = lens (\(RouteProps rp) -> rp.args) (\(RouteProps rp) args -> RouteProps (rp { args=args }))

derive instance newtypeRouteProps :: Newtype (RouteProps_ args) _

-- | React component which will be mounted at matching node
-- | It recieves array of all matching routes.
type RouteClass args = ReactClass (RouteProps_ (NonEmpty Array args))

-- | Route type
-- | The first parameter is the id property
data Route args = Route String (R.Match args) (RouteClass args)

-- | IndexRoute type
-- | The first parameter is the id property
data IndexRoute args = IndexRoute String (RouteClass args)

instance showRoute :: Show (Route args) where
  show (Route id_ _ _) = "<Route \"" <> id_ <> "\">"

urlLens :: forall args. Lens' (Route args) (R.Match args)
urlLens = lens (\(Route _ url _) -> url) (\(Route id _ cls) url -> Route id url cls)

-- | Router
-- | ```
-- | router =
-- |     Route "home" "/" Home :+
-- |         [ Route "user" "user/:id" User :+
-- |             [ Route "email" "email" UserEmail :+ []
-- |             , Route "password" "password" UserPassword :+ []
-- |             ]
-- |         , Tuple (Route "books" "books" Books) (Just BooksIndex) :<
-- |             [ Route "book" ":id" Book :+ []
-- |             , Route "reader" "reader" BookReader :+ []
-- |             ]
-- |         ]
-- | ```
type Router args = Cofree Array (Tuple (Route args) (Maybe (IndexRoute args)))

withoutIndex
  :: forall args. Route args
  -> Array (Router args)
  -> Router args
withoutIndex r rs = Tuple r Nothing :< rs

infixr 6 withoutIndex as :+
