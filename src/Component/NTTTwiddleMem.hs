{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Component.NTTTwiddleMem
  ( TwiddleAddress
  , TwiddleAddresses
  , TwiddleResults
  , twiddleMemory
  ) where

import Clash.Prelude
import qualified Clash.Prelude as C

import Component.NTTConfig (PECount)
import Component.NTTConstants (zetasMont)
import Component.NTTCore (Coeff)

type TwiddleAddress =
  Index 256

type TwiddleAddresses =
  Vec PECount TwiddleAddress

type TwiddleResults =
  Vec PECount Coeff

oneTwiddleRom
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom TwiddleAddress
  -> Signal dom Coeff
oneTwiddleRom address =
  blockRam
    zetasMont
    address
    (pure Nothing)

{-# INLINE oneTwiddleRom #-}

twiddleMemory
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom TwiddleAddresses
  -> Signal dom TwiddleResults
twiddleMemory addressSignal =
  bundle
    (C.map oneTwiddleRom addressSignals)
  where
    addressSignals
      :: Vec PECount (Signal dom TwiddleAddress)
    addressSignals =
      unbundle addressSignal

{-# NOINLINE twiddleMemory #-}