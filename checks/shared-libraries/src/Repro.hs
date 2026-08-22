{-# LANGUAGE TemplateHaskell #-}

module Repro (value) where

import Repro.Dependency (makeValue)

value :: String
value = $(makeValue)
