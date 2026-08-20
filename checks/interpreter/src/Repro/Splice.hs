module Repro.Splice (makeValue) where

import Language.Haskell.TH (Exp, Q, stringE)

makeValue :: Q Exp
makeValue = stringE "wasm interpreter ran"
