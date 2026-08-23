{-# LANGUAGE TemplateHaskell #-}

module Fixture (value) where

import Fixture.Splice (makeValue)

value :: String
value = $(makeValue)
