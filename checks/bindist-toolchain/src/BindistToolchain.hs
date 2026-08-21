module BindistToolchain (reproValue) where

import Foreign.C.Types (CInt (..))

foreign import ccall "repro_value" reproValue :: IO CInt
