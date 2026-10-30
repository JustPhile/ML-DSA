{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeApplications #-}

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
import Component.NTTCore
  ( Coeff
  , PEInput
  , PEOutput
  )

import Component.NTTCoeffMem
  ( LogicalRow
  , RamIndex
  , ReadAddresses
  , ReadResults
  , RowIndex
  , WriteCommand
  , WriteCommands
  , nextBase
  , physicalRow
  )

import Component.NTTTwiddleMem
  ( TwiddleAddresses
  , TwiddleResults
  )

import Component.NTTConfig
  ( PECount
  , IssueCount
  )
  
import GHC.Generics (Generic)
import Prelude hiding ((!!), not, repeat, zipWith3)

type IssueIndex = Index IssueCount
type PEInputs = Vec PECount PEInput
type PEOutputs = Vec PECount PEOutput

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
makeCoeffControl :: Bool
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
    , ccWriteUpper    = issueWide >= issuesPerCluster
    , ccWriteRow      = writeRow
    , ccLast          = issue == maxBound
    }
  where
    issueWide :: Unsigned 8
    issueWide =
      fromIntegral issue

    issueCountWide :: Unsigned 8
    issueCountWide =
      natToNum @IssueCount

    -- 32 for 2 PEs, 16 for 4 PEs, 8 for 8 PEs.
    issuesPerCluster :: Unsigned 8
    issuesPerCluster =
      shiftR issueCountWide 1

    -- Consecutive even/odd issues read the same row.
    readLogicalRow :: LogicalRow
    readLogicalRow =
      fromIntegral (shiftR issueWide 1)

    -- Destination rows repeat once output moves to the upper cluster.
    writeLogicalRow :: LogicalRow
    writeLogicalRow =
      fromIntegral
        (issueWide `mod` issuesPerCluster)

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

makePEInputs
  :: CoeffControl
  -> ReadResults
  -> TwiddleResults
  -> PEInputs
makePEInputs control memoryResults twiddleResults
  | not (ccValid control) =
      repeat (0, 0, 0)

  | otherwise =
      zipWith3
        (\operand0 operand1 twiddle ->
          (operand0, operand1, twiddle)
        )
        operands0
        operands1
        twiddleResults
  where
    -- ReadResults is laid out as:
    --
    -- bank 0: PECount RAMs
    -- bank 1: PECount RAMs
    -- bank 2: PECount RAMs
    -- bank 3: PECount RAMs
    ramBanks :: Vec 4 (Vec PECount Coeff)
    ramBanks =
      unconcat d4 memoryResults

    operands0 :: Vec PECount Coeff
    operands0 =
      if ccOddBanks control
        then ramBanks !! 1
        else ramBanks !! 0

    operands1 :: Vec PECount Coeff
    operands1 =
      if ccOddBanks control
        then ramBanks !! 3
        else ramBanks !! 2


makeTwiddleAddresses
  :: CoeffControl
  -> TwiddleAddresses
makeTwiddleAddresses control
  | not (ccValid control) =
      repeat 0

  | otherwise =
      imap makeAddress (repeat 0)
  where
    peCountWide :: Unsigned 8
    peCountWide =
      natToNum @PECount

    issueWide :: Unsigned 8
    issueWide =
      fromIntegral (ccIssue control)

    inputBase :: Unsigned 8
    inputBase =
      issueWide * peCountWide

    makeAddress
      lane
      _ =
        cgZetaIndex
          (ccStage control)
          (inputBase + fromIntegral lane)

-- Route four PE outputs back to one memory cluster.
makeWriteCommands
  :: CoeffControl
  -> PEOutputs
  -> WriteCommands
makeWriteCommands control outputs
  | not (ccValid control) =
      repeat Nothing

  | otherwise =
      imap makeCommand (repeat Nothing)
  where
    row :: RowIndex
    row =
      ccWriteRow control

    peCountWide :: Unsigned 8
    peCountWide =
      natToNum @PECount

    -- Each cluster contains two banks, with PECount RAMs per bank.
    clusterWidth :: Unsigned 8
    clusterWidth =
      2 * peCountWide

    makeCommand
      :: RamIndex
      -> WriteCommand
      -> WriteCommand
    makeCommand ramIndex _
      | ramIsUpper /= ccWriteUpper control =
          Nothing

      | otherwise =
          Just
            ( row
            , if selectOutputB then outputB else outputA
            )
      where
        ramNumber :: Unsigned 8
        ramNumber =
          fromIntegral ramIndex

        ramIsUpper :: Bool
        ramIsUpper =
          ramNumber >= clusterWidth

        localRamNumber :: Unsigned 8
        localRamNumber =
          if ramIsUpper
            then ramNumber - clusterWidth
            else ramNumber

        outputLane :: Index PECount
        outputLane =
          fromIntegral (shiftR localRamNumber 1)

        selectOutputB :: Bool
        selectOutputB =
          testBit localRamNumber 0

        (outputA, outputB) =
          outputs !! outputLane