{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NumericUnderscores #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Component.NTTCore
  ( Coeff
  , Product
  , butterfly
  , butterflyPipeline
  , montgomeryMul
  ) where

import Clash.Prelude
import GHC.Generics (Generic)

type Coeff = Unsigned 23
type Product = Unsigned 46

type MontWord = Unsigned 24
type MontWide = Unsigned 48

qCoeff :: Coeff
qCoeff = 8_380_417

-- -q^(-1) mod 2^24
qInv :: MontWord
qInv = 8_380_415

data Mont1 = Mont1
  { m1A :: Coeff
  , m1X :: Product
  , m1M :: MontWord
  }
  deriving (Generic, NFDataX)

data Mont2 = Mont2
  { m2A   :: Coeff
  , m2X   :: Product
  , m2Mq  :: MontWide
  }
  deriving (Generic, NFDataX)



data Mont3 = Mont3
  { m3A   :: Coeff
  , m3Sum :: Unsigned 49
  }
  deriving (Generic, NFDataX)

data Mont3Low = Mont3Low
  { m3lA      :: Coeff
  , m3lXHigh  :: Unsigned 22
  , m3lMqHigh :: Unsigned 24
  , m3lLow    :: Unsigned 24
  , m3lCarry  :: Unsigned 1
  }
  deriving (Generic, NFDataX)

montStage1 :: (Coeff, Product) -> Mont1
montStage1 (a, x) =
  Mont1 a x m
  where
    xLow :: MontWord
    xLow =
      truncateB x

    mIntermediate :: Unsigned 47
    mIntermediate =
      (resize xLow `shiftL` 23)
        - (resize xLow `shiftL` 13)
        - resize xLow

    m :: MontWord
    m =
      truncateB mIntermediate

montStage2 :: Mont1 -> Mont2
montStage2 packet =
  Mont2
    (m1A packet)
    (m1X packet)
    mq
  where
    mWide :: MontWide
    mWide =
      resize (m1M packet)

    mq :: MontWide
    mq =
      (mWide `shiftL` 23)
        - (mWide `shiftL` 13)
        + mWide

montStage3Low :: Mont2 -> Mont3Low
montStage3Low packet =
  Mont3Low
    { m3lA      = m2A packet
    , m3lXHigh  = xHigh
    , m3lMqHigh = mqHigh
    , m3lLow    = lowResult
    , m3lCarry  = carryOut
    }
  where
    x :: Product
    x =
      m2X packet

    mq :: MontWide
    mq =
      m2Mq packet

    -- Lower 24 bits
    xLow :: Unsigned 24
    xLow =
      truncateB x

    mqLow :: Unsigned 24
    mqLow =
      truncateB mq

    -- 25 bits so we preserve the carry
    lowSum :: Unsigned 25
    lowSum =
      resize xLow + resize mqLow

    lowResult :: Unsigned 24
    lowResult =
      truncateB lowSum

    carryOut :: Unsigned 1
    carryOut =
      truncateB (shiftR lowSum 24)

    -- Upper bits
    xHigh :: Unsigned 22
    xHigh =
      truncateB (shiftR x 24)

    mqHigh :: Unsigned 24
    mqHigh =
      truncateB (shiftR mq 24)

montStage3High :: Mont3Low -> Mont3
montStage3High packet =
  Mont3
    { m3A   = m3lA packet
    , m3Sum = fullSum
    }
  where
    highSum :: Unsigned 25
    highSum =
      resize (m3lXHigh packet)
        + resize (m3lMqHigh packet)
        + resize (m3lCarry packet)

    -- Concatenate:
    --
    -- highSum[24:0] ++ low[23:0]
    --
    -- 25 + 24 = 49 bits
    fullBits :: BitVector 49
    fullBits =
      pack highSum ++# pack (m3lLow packet)

    fullSum :: Unsigned 49
    fullSum =
      unpack fullBits

finalReduce :: Mont3 -> (Coeff, Coeff)
finalReduce packet =
  (m3A packet, truncateB reduced)
  where
    shifted :: Unsigned 25
    shifted =
      truncateB
        (shiftR (m3Sum packet) 24)

    qWide :: Unsigned 25
    qWide =
      8_380_417

    reduced :: Unsigned 25
    reduced =
      if shifted >= qWide
        then shifted - qWide
        else shifted

montgomeryReduce :: Product -> Coeff
montgomeryReduce x =
  let
    xLow :: MontWord
    xLow =
      truncateB x

    mIntermediate :: Unsigned 47
    mIntermediate =
      (resize xLow `shiftL` 23)
        - (resize xLow `shiftL` 13)
        - resize xLow

    m :: MontWord
    m =
      truncateB mIntermediate

    mWide :: MontWide
    mWide =
      resize m

    mq :: MontWide
    mq =
      (mWide `shiftL` 23)
        - (mWide `shiftL` 13)
        + mWide

    sumWide :: Unsigned 49
    sumWide =
      resize x + resize mq

    shifted :: Unsigned 25
    shifted =
      truncateB (shiftR sumWide 24)

    qWide :: Unsigned 25
    qWide =
      8_380_417

    reduced :: Unsigned 25
    reduced =
      if shifted >= qWide
        then shifted - qWide
        else shifted
  in
    truncateB reduced

data MulPartial = MulPartial
  { mpA    :: Coeff
  , mpLow  :: Unsigned 35
  , mpHigh :: Unsigned 34
  }
  deriving (Generic, NFDataX)

-- ============================================================
-- Pipelined multiplier
-- ============================================================

data MulPartial1 = MulPartial1
  { mp1A    :: Coeff
  , mp1P00  :: Unsigned 26
  , mp1P01  :: Unsigned 26
  , mp1P10  :: Unsigned 26
  , mp1P11  :: Unsigned 26
  , mp1P20  :: Unsigned 26
  , mp1P21  :: Unsigned 26
  , mp1P30  :: Unsigned 26
  , mp1P31  :: Unsigned 25
  }
  deriving (Generic, NFDataX)


data MulPartial2 = MulPartial2
  { mp2A  :: Coeff
  , mp2P0 :: Unsigned 29
  , mp2P1 :: Unsigned 29
  , mp2P2 :: Unsigned 29
  , mp2P3 :: Unsigned 28
  }
  deriving (Generic, NFDataX)


data MulPartial3 = MulPartial3
  { mp3A    :: Coeff
  , mp3Low  :: Unsigned 35
  , mp3High :: Unsigned 34
  }
  deriving (Generic, NFDataX)

mulStage1 :: (Coeff, Coeff, Coeff) -> MulPartial1
mulStage1 (a, b, zeta) =
  MulPartial1
    { mp1A   = a
    , mp1P00 = zeta `mul` b00
    , mp1P01 = zeta `mul` b01
    , mp1P10 = zeta `mul` b10
    , mp1P11 = zeta `mul` b11
    , mp1P20 = zeta `mul` b20
    , mp1P21 = zeta `mul` b21
    , mp1P30 = zeta `mul` b30
    , mp1P31 = zeta `mul` b31
    }
  where
    -- b[5:0]
    b00 :: Unsigned 3
    b00 =
      truncateB b

    b01 :: Unsigned 3
    b01 =
      truncateB (shiftR b 3)

    -- b[11:6]
    b10 :: Unsigned 3
    b10 =
      truncateB (shiftR b 6)

    b11 :: Unsigned 3
    b11 =
      truncateB (shiftR b 9)

    -- b[17:12]
    b20 :: Unsigned 3
    b20 =
      truncateB (shiftR b 12)

    b21 :: Unsigned 3
    b21 =
      truncateB (shiftR b 15)

    -- b[22:18] = 3 + 2
    b30 :: Unsigned 3
    b30 =
      truncateB (shiftR b 18)

    b31 :: Unsigned 2
    b31 =
      truncateB (shiftR b 21)


mulStage2 :: MulPartial1 -> MulPartial2
mulStage2 packet =
  MulPartial2
    { mp2A  = mp1A packet
    , mp2P0 = p0
    , mp2P1 = p1
    , mp2P2 = p2
    , mp2P3 = p3
    }
  where
    -- chunk0: b[5:0]
    p00Wide :: Unsigned 29
    p00Wide =
      resize (mp1P00 packet)

    p01Wide :: Unsigned 29
    p01Wide =
      resize (mp1P01 packet) `shiftL` 3

    p0 :: Unsigned 29
    p0 =
      p00Wide + p01Wide


    -- chunk1: b[11:6]
    p10Wide :: Unsigned 29
    p10Wide =
      resize (mp1P10 packet)

    p11Wide :: Unsigned 29
    p11Wide =
      resize (mp1P11 packet) `shiftL` 3

    p1 :: Unsigned 29
    p1 =
      p10Wide + p11Wide


    -- chunk2: b[17:12]
    p20Wide :: Unsigned 29
    p20Wide =
      resize (mp1P20 packet)

    p21Wide :: Unsigned 29
    p21Wide =
      resize (mp1P21 packet) `shiftL` 3

    p2 :: Unsigned 29
    p2 =
      p20Wide + p21Wide


    -- chunk3: b[22:18]
    p30Wide :: Unsigned 28
    p30Wide =
      resize (mp1P30 packet)

    p31Wide :: Unsigned 28
    p31Wide =
      resize (mp1P31 packet) `shiftL` 3

    p3 :: Unsigned 28
    p3 =
      p30Wide + p31Wide

mulStage3 :: MulPartial2 -> MulPartial3
mulStage3 packet =
  MulPartial3
    { mp3A    = mp2A packet
    , mp3Low  = lowCombined
    , mp3High = highCombined
    }
  where
    -- P0 + (P1 << 6)
    p0Wide :: Unsigned 35
    p0Wide =
      resize (mp2P0 packet)

    p1Wide :: Unsigned 35
    p1Wide =
      resize (mp2P1 packet) `shiftL` 6

    lowCombined :: Unsigned 35
    lowCombined =
      p0Wide + p1Wide


    -- P2 + (P3 << 6)
    p2Wide :: Unsigned 34
    p2Wide =
      resize (mp2P2 packet)

    p3Wide :: Unsigned 34
    p3Wide =
      resize (mp2P3 packet) `shiftL` 6

    highCombined :: Unsigned 34
    highCombined =
      p2Wide + p3Wide

mulStage4 :: MulPartial3 -> (Coeff, Product)
mulStage4 packet =
  (mp3A packet, productWide)
  where
    lowWide :: Product
    lowWide =
      resize (mp3Low packet)

    highWide :: Product
    highWide =
      resize (mp3High packet) `shiftL` 12

    productWide :: Product
    productWide =
      lowWide + highWide

-- Montgomery multiplication
montgomeryMul :: Coeff -> Coeff -> Coeff
montgomeryMul a b =
  montgomeryReduce (a `mul` b)


-- Modular addition/subtraction
addModQ :: Coeff -> Coeff -> Coeff
addModQ a b =
  let
    sumWide :: MontWord
    sumWide =
      resize a + resize b

    qWide :: MontWord
    qWide =
      resize qCoeff
  in
    if sumWide >= qWide
      then truncateB (sumWide - qWide)
      else truncateB sumWide


subModQ :: Coeff -> Coeff -> Coeff
subModQ a b =
  if a >= b
    then a - b
    else qCoeff - (b - a)

-- Original combinational butterfly
butterfly
  :: (Coeff, Coeff, Coeff)
  -> (Coeff, Coeff)
butterfly (a, b, zeta) =
  let
    t =
      montgomeryMul zeta b
  in
    ( addModQ a t
    , subModQ a t
    )

-- Pipelined butterfly
butterflyPipeline
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom (Coeff, Coeff, Coeff)
  -> Signal dom (Coeff, Coeff)
butterflyPipeline input =
  outputReg
  where

    -- Stage 1: eight small partial multipliers. 7 x (23x3) + 1 x (23x2)
    mulPartial1Stage :: Signal dom MulPartial1
    mulPartial1Stage =
      fmap mulStage1 input

    mulPartial1Reg :: Signal dom MulPartial1
    mulPartial1Reg =
      register
        (MulPartial1 0 0 0 0 0 0 0 0 0)
        mulPartial1Stage

    -- Stage 2: reconstruct 6-bit / 5-bit products
    mulPartial2Stage :: Signal dom MulPartial2
    mulPartial2Stage =
      fmap mulStage2 mulPartial1Reg

    mulPartial2Reg :: Signal dom MulPartial2
    mulPartial2Reg =
      register
        (MulPartial2 0 0 0 0 0)
        mulPartial2Stage

    -- Stage 3: combine into low-12 / high-11 products
    mulPartial3Stage :: Signal dom MulPartial3
    mulPartial3Stage =
      fmap mulStage3 mulPartial2Reg

    mulPartial3Reg :: Signal dom MulPartial3
    mulPartial3Reg =
      register
        (MulPartial3 0 0 0)
        mulPartial3Stage

    -- Stage 4: full 23x23 product reconstruction
    mulCombineStage :: Signal dom (Coeff, Product)
    mulCombineStage =
      fmap mulStage4 mulPartial3Reg

    mulReg :: Signal dom (Coeff, Product)
    mulReg =
      register
        (0, 0)
        mulCombineStage

    -- Stage 3: Montgomery: calculate m
    mont1Stage :: Signal dom Mont1
    mont1Stage =
      fmap montStage1 mulReg

    mont1Reg :: Signal dom Mont1
    mont1Reg =
      register
        (Mont1 0 0 0)
        mont1Stage


    -- Stage 4: Montgomery: calculate m*q
    mont2Stage :: Signal dom Mont2
    mont2Stage =
      fmap montStage2 mont1Reg

    mont2Reg :: Signal dom Mont2
    mont2Reg =
      register
        (Mont2 0 0 0)
        mont2Stage


    -- Stage 5: Montgomery x + mq: calculate lower 24 bits and carry
    mont3LowStage :: Signal dom Mont3Low
    mont3LowStage =
      fmap montStage3Low mont2Reg

    mont3LowReg :: Signal dom Mont3Low
    mont3LowReg =
      register
        (Mont3Low 0 0 0 0 0)
        mont3LowStage


    -- Stage 6: Montgomery x + mq: calculate upper bits using registered carry
    mont3HighStage :: Signal dom Mont3
    mont3HighStage =
      fmap montStage3High mont3LowReg

    mont3Reg :: Signal dom Mont3
    mont3Reg =
      register
        (Mont3 0 0)
        mont3HighStage


    -- Stage 7: shift + conditional subtract q
    reduceStage :: Signal dom (Coeff, Coeff)
    reduceStage =
      fmap finalReduce mont3Reg

    reduceReg :: Signal dom (Coeff, Coeff)
    reduceReg =
      register
        (0, 0)
        reduceStage


    -- Stage 8: butterfly modular add/sub
    addSubStage :: Signal dom (Coeff, Coeff)
    addSubStage =
      fmap
        (\(a, t) ->
          ( addModQ a t
          , subModQ a t
          )
        )
        reduceReg

    outputReg :: Signal dom (Coeff, Coeff)
    outputReg =
      register
        (0, 0)
        addSubStage