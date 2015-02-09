{-# LANGUAGE RecordWildCards, FlexibleInstances, DeriveDataTypeable#-}

module Curry.Common
    ( Chunk(..)
    , Addr(..)
    , Noitpecxe(..)
    , Error
    , modifyTMVar
    , extract
    , eitherToMaybe
    , maybeToEither
    , (<%>)
    , (<+>)
    --
    -- , ChuteIn
    -- , ChuteOut
    -- , newChute
    -- , putChute
    -- , takeChute
    -- , MCtrl
    -- , MView
    -- , newMSplit
    -- , modifyMCtrl
    -- , readMView
    -- , CountCtrl
    -- , CountView
    -- , newCount
    -- , addCount
    -- , readCount
    --
    ) where

import qualified Data.ByteString as B
import           Data.Typeable
import           Control.Applicative
import           Control.Concurrent.Chan
import           Control.Concurrent.STM
import           Control.Exception
import           Control.Monad

----------------------------------------
-- TYPES
----------------------------------------

-- Information about a part of a piece
data Chunk a = Chunk
    { index :: Integer
    , start :: Integer
    , body  :: a
    } deriving (Show, Eq, Ord)

data Addr = Addr
    { addrIp   :: String
    , addrPort :: String
    } deriving (Show, Eq)

data Noitpecxe = Noitpecxe String deriving (Show, Typeable)

instance Exception Noitpecxe

type Error = Either String

----------------------------------------
-- UTILS
----------------------------------------

modifyTMVar :: TMVar a -> (a -> a) -> STM ()
modifyTMVar v f = takeTMVar v >>= (putTMVar v . f)

extract :: (a -> Either String b) -> a -> IO b
extract f x = case f x of
    (Left  str) -> throw $ PatternMatchFail str
    (Right val) -> return val

maybeToEither :: String -> Maybe a -> Either String a
maybeToEither _ (Just x) = Right x
maybeToEither s Nothing  = Left s

eitherToMaybe :: Either a b -> Maybe b
eitherToMaybe (Right x) = Just x
eitherToMaybe (Left  _) = Nothing

infixl 1 <%>
(<%>) :: Applicative f => f (a -> b) -> a -> f b
(<%>) = (. pure) . (<*>)

-- This is mplus, but (Either String) is already an instance
-- for SOME e in certain modules, so trying to use the actual
-- mplus class made things pretty messy.
infixl 6 <+>
(<+>) :: Either a b -> Either a b -> Either a b
r@(Right _) <+> _ = r
_ <+> r@(Right _) = r
_ <+> l@(Left  _) = l

----------------------------------------
-- CETERA
----------------------------------------

-- To allow types with MVars and TVars to allow show (which will only be
-- used for debugging)

instance Show (TVar a) where
    show _ = "(a tvar exists here)"

instance Show (TMVar a) where
    show _ = "(a tmvar exists here)"

instance Show (TChan a) where
    show _ = "(a tchan exists here)"

instance Show (Chan a) where
    show _ = "(a chan exists here)"