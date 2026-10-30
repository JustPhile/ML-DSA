{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Component.NTTCoeffMem
  ( BankIndex
  , BlockIndex
  , RowIndex
  , LogicalRow
  , RamIndex
  , ReadAddresses
  , WriteCommand
  , WriteCommands
  , ReadResults
  , PhysicalAddress(..)
  , initialAddress
  , nextBase
  , wrapRow48
  , physicalRow
  , physicalRamIndex
  , coeffMemory
  ) where

import Component.NTTConfig
  ( PECount
  , CoeffRamCount
  , CoeffRamDepth
  , LogicalRowCount
  )

import Clash.Prelude
import qualified Clash.Prelude as C
import Component.NTTCore (Coeff)
import GHC.Generics (Generic)
import Prelude hiding ((!!), repeat)

type BankIndex =
  Index 4

type BlockIndex =
  Index PECount

type RowIndex =
  Index CoeffRamDepth

type LogicalRow =
  Index LogicalRowCount

type RamIndex =
  Index CoeffRamCount

type RamContents =
  Vec CoeffRamDepth Coeff

type ReadAddresses =
  Vec CoeffRamCount RowIndex

type WriteCommand =
  Maybe (RowIndex, Coeff)

type WriteCommands =
  Vec CoeffRamCount WriteCommand

type ReadResults =
  Vec CoeffRamCount Coeff

data PhysicalAddress = PhysicalAddress
  { addressBank  :: BankIndex
  , addressBlock :: BlockIndex
  , addressRow   :: RowIndex
  }
  deriving (Generic, NFDataX, Eq, Show)

physicalRamIndex
  :: PhysicalAddress
  -> RamIndex
physicalRamIndex address =
  fromIntegral ramNumber
  where
    bankWide :: Unsigned 8
    bankWide =
      fromIntegral (addressBank address)

    blockWide :: Unsigned 8
    blockWide =
      fromIntegral (addressBlock address)

    peCountWide :: Unsigned 8
    peCountWide =
      natToNum @PECount

    ramNumber :: Unsigned 8
    ramNumber =
      bankWide * peCountWide + blockWide

oneCoeffRam
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom RowIndex
  -> Signal dom WriteCommand
  -> Signal dom Coeff
oneCoeffRam readAddress writeCommand =
  blockRam
    (repeat 0 :: RamContents)
    readAddress
    writeCommand

{-# INLINE oneCoeffRam #-}

coeffMemory
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom ReadAddresses
  -> Signal dom WriteCommands
  -> Signal dom ReadResults
coeffMemory readAddressSignal writeCommandSignal =
  bundle ramOutputs
  where
    readAddressSignals
      :: Vec CoeffRamCount (Signal dom RowIndex)
    readAddressSignals =
      unbundle readAddressSignal

    writeCommandSignals
      :: Vec CoeffRamCount (Signal dom WriteCommand)
    writeCommandSignals =
      unbundle writeCommandSignal

    ramOutputs
      :: Vec CoeffRamCount (Signal dom Coeff)
    ramOutputs =
      C.zipWith
        oneCoeffRam
        readAddressSignals
        writeCommandSignals

{-# NOINLINE coeffMemory #-}

initialAddress
  :: Index 256
  -> PhysicalAddress
initialAddress logicalIndex =
  PhysicalAddress
    { addressBank  = bank
    , addressBlock = block
    , addressRow   = row
    }
  where
    indexWide :: Unsigned 8
    indexWide =
      fromIntegral logicalIndex

    secondHalf :: Bool
    secondHalf =
      indexWide >= 128

    withinHalf :: Unsigned 8
    withinHalf =
      if secondHalf
        then indexWide - 128
        else indexWide

    peCountWide :: Unsigned 8
    peCountWide =
      natToNum @PECount

    block :: BlockIndex
    block =
      fromIntegral
        (withinHalf `mod` peCountWide)

    bankWithinCluster :: Unsigned 1
    bankWithinCluster =
      truncateB
        (withinHalf `div` peCountWide)

    bankBase :: Unsigned 3
    bankBase =
      if secondHalf
        then 2
        else 0

    bank :: BankIndex
    bank =
      fromIntegral
        (bankBase + resize bankWithinCluster)

    row :: RowIndex
    row =
      fromIntegral
        (withinHalf `div` (2 * peCountWide))

nextBase
  :: Unsigned 6
  -> Unsigned 6
nextBase base
  | base == 0 =
      logicalRows

  | base == logicalRows =
      halfRows

  | otherwise =
      0
  where
    logicalRows :: Unsigned 6
    logicalRows =
      fromIntegral
        (natToNum @LogicalRowCount)

    halfRows :: Unsigned 6
    halfRows =
      shiftR logicalRows 1

wrapRow48
  :: Unsigned 6
  -> RowIndex
wrapRow48 value =
  if value >= ramDepth
    then fromIntegral (value - ramDepth)
    else fromIntegral value
  where
    ramDepth :: Unsigned 6
    ramDepth =
      natToNum @CoeffRamDepth

physicalRow
  :: Unsigned 6
  -> LogicalRow
  -> RowIndex
physicalRow base logicalRow =
  wrapRow48
    (base + fromIntegral logicalRow)