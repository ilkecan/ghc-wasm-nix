module Repro.Dependency (makeValue) where

import Language.Haskell.TH (Exp, Q, stringE)

makeValue :: Q Exp
makeValue = stringE "loaded dependency"
