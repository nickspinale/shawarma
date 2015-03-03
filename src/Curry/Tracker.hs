{-# LANGUAGE RecordWildCards #-}

module Curry.Tracker
    ( Travent(..)
    , mkURL
    ) where

import           Curry.State
import           Curry.Parsers.Bencode
import           Curry.Parsers.PWP
import           Curry.Parsers.Torrent

import           Control.Concurrent.STM
import           Control.Lens
import           Control.Monad
import           Control.Monad.Reader
import           Control.Monad.Trans
import           Data.Attoparsec.ByteString
import           Data.Bits
import qualified Data.ByteString as B
import qualified Data.ByteString.Lazy as L
import qualified Data.ByteString.Char8 as C
import           Data.Char
import           Data.List
import           Data.List.Split
import qualified Data.Map as M
import           Data.Maybe
import           Data.Word
import qualified Network.Wreq as W

-- Event for tracker http requests
data Travent = Started | Stopped | Complete

instance Show Travent where
    show Started  = "started"
    show Stopped  = "stopped"
    show Complete = "complete"

mkURL :: Environment -> CommSt -> Maybe Travent -> STM String
mkURL Environment{..} CommSt{..} event = do

    peers' <- readTVar peers
    ups <- mapM (fmap up . readTVar . mut) peers'
    downs <- mapM (fmap down . readTVar . mut) peers'
    have <- readTVar pieceMap

    return (announce torrent ++ "?" ++ intercalate "&"
      ( catMaybes [ fmap (("trackerid=" ++) . urifyBS) trackerId
                  , fmap (("event="     ++) . show   ) event
                  ]
     ++ [ "numwant="    ++ show minPeers
        , "port="       ++ show port
        , "peer_id="    ++ urifyBS pid
        , "key="        ++ urifyBS key
        , "info_hash="  ++ urifyBS infoHash
        , "uploaded="   ++ show ( sum ups)
        , "downloaded=" ++ show ( sum downs)
        , "left="       ++ show ( totalSize - toInteger (M.size have))
        ]
      ))

  where
    Config{..} = config
    Ident{..} = ident
    MetaInfo{..} = metaInfo
    info' = info torrent
    totalSize = pieceLen info' * genericLength (pieces info')

urifyBS :: B.ByteString -> String
urifyBS = concatMap urify8 . B.unpack

urify8 :: Word8 -> String
urify8 byte = ['%', toHexHalf $ shiftR byte 4, toHexHalf $ byte .&. 15]

toHexHalf :: Word8 -> Char
toHexHalf = genericIndex "0123456789ABCDEF"

-- ---------------------------------------------------------------------

-- beFriend :: GlobalEnv -> ChuteIn Peer -> (Socket, SockAddr) -> IO ()
-- beFriend GlobalEnv{..} chute (sock, _) = do
--     sendAll myShake
--     bytes <- revc 4096
--     case getShake bytes of
--         Left str -> putStrLn str
--         Right Handshake{..} -> do
--             return () -- check to make sure its valid
--             let status' = newMVar $ Status True True False False
--                 (has', has) = newMView
--                 (has', has) = newCount
--                 (has', has) = newCount
--             putChute chute $ Peer sock status' has up down
--             go
--   where go = do
--     bytes <- recv sock 4096
--     case getMessage bytes of
--         Left str -> putStrLn str
--         Right msg -> do
--             case msg of
--                 Keepalive -> return ()
--                 Choke -> modifyMVar status' $ \s -> s { choked = True }
--                 Unchoke -> modifyMVar status' $ \s -> s { choked = False }
--                 Interested -> modifyMVar status' $ \s -> s { interested = True }
--                 Bored -> modifyMVar status' $ \s -> s { interested = False }
--                 Have ix -> modifyMCtrl has' (insert ix True)
--                 Bitfield m -> modifyMCtrl has' $ M.union m
--                 Request ix off len -> putStrLn ("Peer requested chunk: " ++ show ix ++ ", " show off ++ ", " ++ show len)
--                 Piece ix off bytes -> putStrLn ("Got chunk: " ++ show ix ++ ", " show off)
--                 Cancel ix off len -> putStrLn ("Peer canceled chunk: " ++ show ix ++ ", " show off ++ ", " ++ show len)
--             go

-- ---------------------------------------------------------------------

-- -- -- Regularly gets updated info (and keepalives) from tracker,
-- -- -- spawing new processes for each new peer reported and adding
-- -- -- information about the processes to ST for the brain module.
