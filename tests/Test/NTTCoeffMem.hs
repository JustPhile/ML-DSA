{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ImportQualifiedPost #-}

module Test.NTTCoeffMem (spec) where

import Component.NTTCoeffMem
import Prelude qualified as P
import Test.Hspec

spec :: Spec
spec =
  describe "NTT coefficient memory" P.$ do
    describe "initialAddress" P.$ do
      it "maps coefficients 0-4 correctly" P.$ do
        initialAddress 0
          `shouldBe` PhysicalAddress 0 0 0

        initialAddress 1
          `shouldBe` PhysicalAddress 0 1 0

        initialAddress 2
          `shouldBe` PhysicalAddress 1 0 0

        initialAddress 3
          `shouldBe` PhysicalAddress 1 1 0

        initialAddress 4
          `shouldBe` PhysicalAddress 0 0 1

      it "maps cluster boundaries correctly" P.$ do
        initialAddress 127
          `shouldBe` PhysicalAddress 1 1 31

        initialAddress 128
          `shouldBe` PhysicalAddress 2 0 0

        initialAddress 255
          `shouldBe` PhysicalAddress 3 1 31

    describe "physicalRamIndex" P.$ do
      it "maps banks and blocks to RAM 0-7" P.$ do
        physicalRamIndex (PhysicalAddress 0 0 0)
          `shouldBe` 0

        physicalRamIndex (PhysicalAddress 0 1 0)
          `shouldBe` 1

        physicalRamIndex (PhysicalAddress 1 0 0)
          `shouldBe` 2

        physicalRamIndex (PhysicalAddress 1 1 0)
          `shouldBe` 3

        physicalRamIndex (PhysicalAddress 2 0 0)
          `shouldBe` 4

        physicalRamIndex (PhysicalAddress 3 1 0)
          `shouldBe` 7

    describe "row rotation" P.$ do
      it "rotates the base correctly" P.$ do
        nextBase 0  `shouldBe` 32
        nextBase 32 `shouldBe` 16
        nextBase 16 `shouldBe` 0

      it "wraps rows at 48" P.$ do
        wrapRow48 47 `shouldBe` 47
        wrapRow48 48 `shouldBe` 0
        wrapRow48 63 `shouldBe` 15

      it "adds the stage base to a logical row" P.$ do
        physicalRow 0  31 `shouldBe` 31
        physicalRow 32 0  `shouldBe` 32
        physicalRow 32 15 `shouldBe` 47
        physicalRow 32 16 `shouldBe` 0
        physicalRow 16 31 `shouldBe` 47