{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}

module Component.NTTCoeffController
  ( IssueIndex
  , CoeffControl(..)
  , zeroCoeffControl
  , makeCoeffControl
  , makePEInputs
  , makeWriteCommands
  , makeTwiddleAddresses
  ) where

import Clash.Prelude
import Component.NTTConstants (zetasMont)
import Component.NTTCore
  ( Coeff
  , PEInput
  , PEOutput
  )

import Component.NTTCoeffMem
  ( LogicalRow
  , ReadAddresses
  , ReadResults
  , RowIndex
  , WriteCommands
  , nextBase
  , physicalRow
  )

import Component.NTTTwiddleMem
  ( TwiddleAddresses
  , TwiddleResults
  )
  
import GHC.Generics (Generic)
import Prelude hiding ((!!), not, repeat)

type IssueIndex = Index 64

data CoeffControl = CoeffControl
  { ccValid         :: Bool
  , ccStage         :: Index 8
  , ccIssue         :: IssueIndex
  , ccReadAddresses :: ReadAddresses
  , ccOddBanks      :: Bool
  , ccWriteUpper    :: Bool
  , ccWriteRow      :: RowIndex
  , ccLast          :: Bool
  }
  deriving (Generic, NFDataX, Eq, Show)

zeroCoeffControl :: CoeffControl
zeroCoeffControl =
  CoeffControl
    { ccValid         = False
    , ccStage         = 0
    , ccIssue         = 0
    , ccReadAddresses = repeat 0
    , ccOddBanks      = False
    , ccWriteUpper    = False
    , ccWriteRow      = 0
    , ccLast          = False
    }

-- Generate the coefficient-memory control for one issue cycle.
makeCoeffControl
  :: Bool
  -> Index 8
  -> Unsigned 6
  -> IssueIndex
  -> CoeffControl
makeCoeffControl valid stage sourceBase issue =
  CoeffControl
    { ccValid         = valid
    , ccStage         = stage
    , ccIssue         = issue
    , ccReadAddresses = repeat readRow
    , ccOddBanks      = testBit issueWide 0
    , ccWriteUpper    = testBit issueWide 5
    , ccWriteRow      = writeRow
    , ccLast          = issue == 63
    }
  where
    issueWide :: Unsigned 6
    issueWide =
      fromIntegral issue

    -- Two issue cycles consume one logical row:
    -- issue 0,1 -> row 0
    -- issue 2,3 -> row 1
    readLogicalRow :: LogicalRow
    readLogicalRow =
      fromIntegral (shiftR issueWide 1)

    -- Each issue produces four consecutive coefficients:
    -- issue 0 -> logical row 0
    -- issue 1 -> logical row 1
    writeLogicalRow :: LogicalRow
    writeLogicalRow =
      fromIntegral
        (truncateB issueWide :: Unsigned 5)

    readRow :: RowIndex
    readRow =
      physicalRow sourceBase readLogicalRow

    writeRow :: RowIndex
    writeRow =
      physicalRow
        (nextBase sourceBase)
        writeLogicalRow

-- Twiddle order for the constant-geometry form.
--
-- stage 0: 1
-- stage 1: 2,3
-- stage 2: 4,5,6,7
-- ...
cgZetaIndex
  :: Index 8
  -> Unsigned 8
  -> Index 256
cgZetaIndex stage inputNumber =
  case stage of
    0 -> 1
    1 -> fromIntegral (2   + inputNumber `mod` 2)
    2 -> fromIntegral (4   + inputNumber `mod` 4)
    3 -> fromIntegral (8   + inputNumber `mod` 8)
    4 -> fromIntegral (16  + inputNumber `mod` 16)
    5 -> fromIntegral (32  + inputNumber `mod` 32)
    6 -> fromIntegral (64  + inputNumber `mod` 64)
    7 -> fromIntegral (128 + inputNumber)

-- Select four RAM outputs and form inputs for the two PEs.
makePEInputs
  :: CoeffControl
  -> ReadResults
  -> TwiddleResults
  -> Vec 2 PEInput
makePEInputs control memoryResults twiddleResults =
  if ccValid control
    then
      (operand00, operand01, twiddleResults !! 0)
        :>
      (operand10, operand11, twiddleResults !! 1)
        :>
      Nil
    else
      repeat (0, 0, 0)
  where
    -- Even issue:
    --
    -- PE0 reads RAM 0 and RAM 4.
    -- PE1 reads RAM 1 and RAM 5.
    --
    -- Odd issue:
    --
    -- PE0 reads RAM 2 and RAM 6.
    -- PE1 reads RAM 3 and RAM 7.

    operand00 :: Coeff
    operand00 =
      if ccOddBanks control
        then memoryResults !! 2
        else memoryResults !! 0

    operand01 :: Coeff
    operand01 =
      if ccOddBanks control
        then memoryResults !! 6
        else memoryResults !! 4

    operand10 :: Coeff
    operand10 =
      if ccOddBanks control
        then memoryResults !! 3
        else memoryResults !! 1

    operand11 :: Coeff
    operand11 =
      if ccOddBanks control
        then memoryResults !! 7
        else memoryResults !! 5


-- Produce the two synchronous twiddle-ROM addresses.
makeTwiddleAddresses
  :: CoeffControl
  -> TwiddleAddresses
makeTwiddleAddresses control =
  if ccValid control
    then
      zetaIndex0
        :> zetaIndex1
        :> Nil
    else
      repeat 0
  where
    issueWide :: Unsigned 8
    issueWide =
      resize
        (fromIntegral (ccIssue control) :: Unsigned 6)

    -- Two butterflies are issued each cycle.
    input0 :: Unsigned 8
    input0 =
      shiftL issueWide 1

    input1 :: Unsigned 8
    input1 =
      input0 + 1

    zetaIndex0 :: Index 256
    zetaIndex0 =
      cgZetaIndex
        (ccStage control)
        input0

    zetaIndex1 :: Index 256
    zetaIndex1 =
      cgZetaIndex
        (ccStage control)
        input1

-- Route four PE outputs back to one memory cluster.
makeWriteCommands
  :: CoeffControl
  -> Vec 2 PEOutput
  -> WriteCommands
makeWriteCommands control outputs
  | not (ccValid control) =
      repeat Nothing

  | ccWriteUpper control =
      Nothing
        :> Nothing
        :> Nothing
        :> Nothing
        :> Just (row, out0A)
        :> Just (row, out0B)
        :> Just (row, out1A)
        :> Just (row, out1B)
        :> Nil

  | otherwise =
      Just (row, out0A)
        :> Just (row, out0B)
        :> Just (row, out1A)
        :> Just (row, out1B)
        :> Nothing
        :> Nothing
        :> Nothing
        :> Nothing
        :> Nil
  where
    row =
      ccWriteRow control

    (out0A, out0B) =
      outputs !! 0

    (out1A, out1B) =
      outputs !! 1