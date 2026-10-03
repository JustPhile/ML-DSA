module Main (main) where

import Test.Hspec (hspec)
import Test.NTT256 qualified as NTT
import Test.NTTCoeffMem qualified as CoeffMem

main :: IO ()
main =
  hspec $ do
    NTT.spec
    CoeffMem.spec
