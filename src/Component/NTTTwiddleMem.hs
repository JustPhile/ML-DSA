{-# LANGUAGE DataKinds #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Component.NTTTwiddleMem
  ( TwiddleAddress
  , TwiddleAddresses
  , TwiddleResults
  , twiddleMemory
  ) where

import Clash.Prelude
import Component.NTTCore (Coeff)
import Component.NTTConstants (zetasMont)
import Prelude hiding ((!!))

type TwiddleAddress = Index 256
type TwiddleAddresses = Vec 2 TwiddleAddress
type TwiddleResults = Vec 2 Coeff

-- Two synchronous read lanes.
--
-- blockRam has one-cycle read latency. Because blockRam is single-read-port,
-- the constant twiddle table is duplicated to provide two simultaneous reads.
twiddleMemory
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom TwiddleAddresses
  -> Signal dom TwiddleResults
twiddleMemory addressSignal =
  bundle
    (twiddle0 :> twiddle1 :> Nil)
  where
    addressSignals :: Vec 2 (Signal dom TwiddleAddress)
    addressSignals =
      unbundle addressSignal

    address0 :: Signal dom TwiddleAddress
    address0 =
      addressSignals !! 0

    address1 :: Signal dom TwiddleAddress
    address1 =
      addressSignals !! 1

    noWrite
      :: Signal dom
           (Maybe (TwiddleAddress, Coeff))
    noWrite =
      pure Nothing

    twiddle0 :: Signal dom Coeff
    twiddle0 =
      blockRam
        zetasMont
        address0
        noWrite

    twiddle1 :: Signal dom Coeff
    twiddle1 =
      blockRam
        zetasMont
        address1
        noWrite

{-# NOINLINE twiddleMemory #-}