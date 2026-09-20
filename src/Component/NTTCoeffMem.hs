{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

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

import Clash.Prelude
import Component.NTTCore (Coeff)
import GHC.Generics (Generic)
import Prelude hiding ((!!), repeat)

type BankIndex  = Index 4
type BlockIndex = Index 2
type RowIndex   = Index 48
type LogicalRow = Index 32
type RamIndex   = Index 8

type RamContents = Vec 48 Coeff

type ReadAddresses = Vec 8 RowIndex

type WriteCommand = Maybe (RowIndex, Coeff)

type WriteCommands = Vec 8 WriteCommand

type ReadResults = Vec 8 Coeff

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
    bankWide :: Unsigned 3
    bankWide =
      resize
        (fromIntegral (addressBank address) :: Unsigned 2)

    blockWide :: Unsigned 3
    blockWide =
      resize
        (fromIntegral (addressBlock address) :: Unsigned 1)

    ramNumber :: Unsigned 3
    ramNumber =
      shiftL bankWide 1 + blockWide

coeffMemory
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom ReadAddresses
  -> Signal dom WriteCommands
  -> Signal dom ReadResults
coeffMemory readAddressSignal writeCommandSignal =
  bundle
    ( ram0
    :> ram1
    :> ram2
    :> ram3
    :> ram4
    :> ram5
    :> ram6
    :> ram7
    :> Nil
    )
  where
    readAddressSignals
      :: Vec 8 (Signal dom RowIndex)
    readAddressSignals =
      unbundle readAddressSignal

    writeCommandSignals
      :: Vec 8 (Signal dom WriteCommand)
    writeCommandSignals =
      unbundle writeCommandSignal

    ram0, ram1, ram2, ram3 :: Signal dom Coeff
    ram4, ram5, ram6, ram7 :: Signal dom Coeff

    ram0 =
      blockRam
        (repeat 0 :: RamContents)
        (readAddressSignals !! 0)
        (writeCommandSignals !! 0)

    ram1 =
      blockRam
        (repeat 0 :: RamContents)
        (readAddressSignals !! 1)
        (writeCommandSignals !! 1)

    ram2 =
      blockRam
        (repeat 0 :: RamContents)
        (readAddressSignals !! 2)
        (writeCommandSignals !! 2)

    ram3 =
      blockRam
        (repeat 0 :: RamContents)
        (readAddressSignals !! 3)
        (writeCommandSignals !! 3)

    ram4 =
      blockRam
        (repeat 0 :: RamContents)
        (readAddressSignals !! 4)
        (writeCommandSignals !! 4)

    ram5 =
      blockRam
        (repeat 0 :: RamContents)
        (readAddressSignals !! 5)
        (writeCommandSignals !! 5)

    ram6 =
      blockRam
        (repeat 0 :: RamContents)
        (readAddressSignals !! 6)
        (writeCommandSignals !! 6)

    ram7 =
      blockRam
        (repeat 0 :: RamContents)
        (readAddressSignals !! 7)
        (writeCommandSignals !! 7)

-- Initial placement of one logical coefficient.
initialAddress :: Index 256 -> PhysicalAddress
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
      testBit indexWide 7

    -- Original logical index bit 1.
    bankWithinCluster :: Unsigned 1
    bankWithinCluster =
      truncateB (shiftR indexWide 1)

    -- Clash uses banks 0–3, corresponding to paper Banks 1–4.
    bank :: BankIndex
    bank =
      if secondHalf
        then
          fromIntegral
            (2 + resize bankWithinCluster :: Unsigned 3)
        else
          fromIntegral
            (resize bankWithinCluster :: Unsigned 3)

    -- Original logical index bit 0.
    block :: BlockIndex
    block =
      fromIntegral
        (truncateB indexWide :: Unsigned 1)

    -- Original logical index bits 6–2.
    row :: RowIndex
    row =
      fromIntegral
        (truncateB (shiftR indexWide 2) :: Unsigned 5)

-- The 32 live coefficients rotate through the 48-row memory.
nextBase :: Unsigned 6 -> Unsigned 6
nextBase base =
  case base of
    0  -> 32
    32 -> 16
    16 -> 0
    _  -> 0

-- The maximum input is 32 + 31 = 63, so one subtraction is enough.
wrapRow48 :: Unsigned 6 -> RowIndex
wrapRow48 value =
  if value >= 48
    then fromIntegral (value - 48)
    else fromIntegral value

physicalRow :: Unsigned 6 -> LogicalRow -> RowIndex
physicalRow base logicalRow =
  wrapRow48
    (base + resize (fromIntegral logicalRow :: Unsigned 5))