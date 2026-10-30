{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ImportQualifiedPost #-}
{-# LANGUAGE TypeApplications #-}

module Test.NTTCoeffMem (spec) where

import Clash.Prelude qualified as C
import Component.NTTConfig
  ( PECount
  )
import Component.NTTCoeffMem
import Prelude qualified as P
import Test.Hspec

peCountValue :: P.Int
peCountValue =
  C.natToNum @PECount

logicalRowsValue :: P.Int
logicalRowsValue =
  64 `P.div` peCountValue

ramDepthValue :: P.Int
ramDepthValue =
  96 `P.div` peCountValue

halfLogicalRowsValue :: P.Int
halfLogicalRowsValue =
  logicalRowsValue `P.div` 2

toUnsigned6 :: P.Int -> C.Unsigned 6
toUnsigned6 =
  P.fromIntegral

toLogicalRow :: P.Int -> LogicalRow
toLogicalRow =
  P.fromIntegral

toRowIndex :: P.Int -> RowIndex
toRowIndex =
  P.fromIntegral

-- Independent description of the intended initial mapping.
expectedInitialAddress
  :: P.Int
  -> PhysicalAddress
expectedInitialAddress logicalIndex =
  PhysicalAddress
    { addressBank  = P.fromIntegral bankNumber
    , addressBlock = P.fromIntegral blockNumber
    , addressRow   = P.fromIntegral rowNumber
    }
  where
    secondHalf :: P.Bool
    secondHalf =
      logicalIndex P.>= 128

    withinHalf :: P.Int
    withinHalf =
      logicalIndex `P.mod` 128

    clusterBase :: P.Int
    clusterBase =
      if secondHalf then 2 else 0

    blockNumber :: P.Int
    blockNumber =
      withinHalf `P.mod` peCountValue

    bankWithinCluster :: P.Int
    bankWithinCluster =
      (withinHalf `P.div` peCountValue) `P.mod` 2

    bankNumber :: P.Int
    bankNumber =
      clusterBase P.+ bankWithinCluster

    rowNumber :: P.Int
    rowNumber =
      withinHalf `P.div` (2 P.* peCountValue)

spec :: Spec
spec =
  describe "NTT coefficient memory" P.$ do

    describe "configuration" P.$ do
      it "uses a supported power-of-two PE count" P.$ do
        peCountValue `shouldSatisfy`
          (`P.elem` [2, 4, 8])

      it "maintains 384 coefficient storage locations" P.$ do
        (4 P.* peCountValue P.* ramDepthValue)
          `shouldBe` 384

    describe "initialAddress" P.$ do
      it "maps all 256 coefficients correctly" P.$ do
        let
          actual =
            P.map
              (\index ->
                initialAddress (P.fromIntegral index)
              )
              [0 .. 255]

          expected =
            P.map expectedInitialAddress [0 .. 255]

        actual `shouldBe` expected

      it "maps the lower-half boundary correctly" P.$ do
        initialAddress 0
          `shouldBe`
            PhysicalAddress 0 0 0

        initialAddress
          (P.fromIntegral (peCountValue P.- 1))
          `shouldBe`
            PhysicalAddress
              0
              (P.fromIntegral (peCountValue P.- 1))
              0

        initialAddress
          (P.fromIntegral peCountValue)
          `shouldBe`
            PhysicalAddress 1 0 0

      it "maps the upper-half boundary correctly" P.$ do
        initialAddress 128
          `shouldBe`
            PhysicalAddress 2 0 0

        initialAddress
          (P.fromIntegral (128 P.+ peCountValue))
          `shouldBe`
            PhysicalAddress 3 0 0

        initialAddress 255
          `shouldBe`
            expectedInitialAddress 255

    describe "physicalRamIndex" P.$ do
      it "numbers RAMs in bank-major order" P.$ do
        let
          addresses =
            [ PhysicalAddress
                (P.fromIntegral bank)
                (P.fromIntegral block)
                0
            | bank <- [0 .. 3]
            , block <- [0 .. peCountValue P.- 1]
            ]

          actual =
            P.map physicalRamIndex addresses

          expected =
            P.map
              P.fromIntegral
              [0 .. 4 P.* peCountValue P.- 1]

        actual `shouldBe` expected

    describe "row rotation" P.$ do
      it "rotates through the three memory regions" P.$ do
        nextBase 0
          `shouldBe`
            toUnsigned6 logicalRowsValue

        nextBase (toUnsigned6 logicalRowsValue)
          `shouldBe`
            toUnsigned6 halfLogicalRowsValue

        nextBase (toUnsigned6 halfLogicalRowsValue)
          `shouldBe`
            0

      it "wraps at the configured physical RAM depth" P.$ do
        wrapRow48
          (toUnsigned6 (ramDepthValue P.- 1))
          `shouldBe`
            toRowIndex (ramDepthValue P.- 1)

        wrapRow48
          (toUnsigned6 ramDepthValue)
          `shouldBe`
            0

        wrapRow48
          (toUnsigned6
            (ramDepthValue P.+ halfLogicalRowsValue P.- 1))
          `shouldBe`
            toRowIndex (halfLogicalRowsValue P.- 1)

      it "adds and wraps the stage base correctly" P.$ do
        physicalRow
          0
          (toLogicalRow (logicalRowsValue P.- 1))
          `shouldBe`
            toRowIndex (logicalRowsValue P.- 1)

        physicalRow
          (toUnsigned6 logicalRowsValue)
          (toLogicalRow (halfLogicalRowsValue P.- 1))
          `shouldBe`
            toRowIndex (ramDepthValue P.- 1)

        physicalRow
          (toUnsigned6 logicalRowsValue)
          (toLogicalRow halfLogicalRowsValue)
          `shouldBe`
            0

        physicalRow
          (toUnsigned6 halfLogicalRowsValue)
          (toLogicalRow (logicalRowsValue P.- 1))
          `shouldBe`
            toRowIndex (ramDepthValue P.- 1)