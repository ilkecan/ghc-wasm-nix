{-# LANGUAGE TemplateHaskell #-}

module Repro (value) where

import Repro.Splice (makeValue)

value :: String
value = $(makeValue)
