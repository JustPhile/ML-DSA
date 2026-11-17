{-# LANGUAGE DataKinds #-}

module Main (main) where

import Clash.Prelude
  ( Vec, Signal, System, bundle, clockGen, enableGen, fromList
  , resetGen, sampleN, toList
  )
import qualified Clash.Sized.Vector as Vec
import qualified Component.NTT as DUT
import Component.NTTCore (Coeff)
import qualified Component.NTTConstants as Constants
import Data.List (find)
import qualified Data.Vector as V
import qualified MLDSA.NTT as Ref
import System.Exit (die)

type Poly = Vec 256 Coeff

-- Wait until resetGen has deasserted, then pulse start for one cycle.
startCycle, maxCycles :: Int
startCycle = 3
maxCycles = 2048

input :: Poly
input = Vec.unsafeFromList [0 .. 255]

outputs :: [(Bool, Poly)]
outputs =
  sampleN (startCycle + maxCycles + 1) output
  where
    start =
      fromList
        (replicate startCycle False ++ [True] ++ repeat False)

    (done, result) =
      DUT.topEntity
        clockGen
        resetGen
        enableGen
        start
        (pure input)

    output :: Signal System (Bool, Poly)
    output = bundle (done, result)

main :: IO ()
main =
  case find (fst . snd) (zip [0 :: Int ..] outputs) of
    Nothing ->
      die "NTT cycle benchmark: done timed out after 2048 cycles"

    Just (doneCycle, (_, result))
      | doneCycle <= startCycle ->
          die "NTT cycle benchmark: done asserted before start was accepted"

      | actual /= expected ->
          die "NTT cycle benchmark: result differs from MLDSA.NTT"

      | otherwise ->
          putStrLn
            ("NTT_CYCLES=" ++ show (doneCycle - startCycle))

      where
        actual =
          V.fromList (map toInteger (toList result))

        zetas =
          V.fromList
            (map
              (\zeta -> toInteger (DUT.montgomeryMul zeta 1))
              (toList Constants.zetasMont))

        expected =
          Ref.ntt
            8380417
            zetas
            (V.fromList [0 .. 255])