-- Stub for WASM - terminal-size is not available
module System.Console.Terminal.Size
    ( Window(..)
    , size
    , hSize
    , fdSize
    ) where

import System.IO (Handle)

data Window a = Window
    { height :: !a
    , width  :: !a
    } deriving (Eq, Show, Read)

-- Always return Nothing for WASM (no terminal)
size :: Integral n => IO (Maybe (Window n))
size = return Nothing

hSize :: Integral n => Handle -> IO (Maybe (Window n))
hSize _ = return Nothing

fdSize :: Integral n => Int -> IO (Maybe (Window n))
fdSize _ = return Nothing
