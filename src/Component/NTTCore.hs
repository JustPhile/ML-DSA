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


montStage3 :: Mont2 -> Mont3
montStage3 packet =
  Mont3
    (m2A packet)
    sumWide
  where
    sumWide :: Unsigned 49
    sumWide =
      resize (m2X packet)
        + resize (m2Mq packet)

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
--
-- b = bLow + (bHigh << 12)
--
-- zeta * b =
--   zeta * bLow
--   + ((zeta * bHigh) << 12)
-- ============================================================

mulStage1 :: (Coeff, Coeff, Coeff) -> MulPartial
mulStage1 (a, b, zeta) =
  MulPartial
    { mpA    = a
    , mpLow  = lowProduct
    , mpHigh = highProduct
    }
  where
    bLow :: Unsigned 12
    bLow =
      truncateB b

    bHigh :: Unsigned 11
    bHigh =
      truncateB (shiftR b 12)

    lowProduct :: Unsigned 35
    lowProduct =
      zeta `mul` bLow

    highProduct :: Unsigned 34
    highProduct =
      zeta `mul` bHigh


mulStage2 :: MulPartial -> (Coeff, Product)
mulStage2 packet =
  (mpA packet, productWide)
  where
    lowWide :: Product
    lowWide =
      resize (mpLow packet)

    highWide :: Product
    highWide =
      resize (mpHigh packet) `shiftL` 12

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

    -- Stage 1: two smaller multipliers: 23x12 and 23x11
    mulPartialStage :: Signal dom MulPartial
    mulPartialStage =
      fmap mulStage1 input

    mulPartialReg :: Signal dom MulPartial
    mulPartialReg =
      register
        (MulPartial 0 0 0)
        mulPartialStage


    -- Stage 2: reconstruct 23x23 product from partial products
    mulCombineStage :: Signal dom (Coeff, Product)
    mulCombineStage =
      fmap mulStage2 mulPartialReg

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


    -- Stage 5: Montgomery: x + mq
    mont3Stage :: Signal dom Mont3
    mont3Stage =
      fmap montStage3 mont2Reg

    mont3Reg :: Signal dom Mont3
    mont3Reg =
      register
        (Mont3 0 0)
        mont3Stage


    -- Stage 6: shift + conditional subtract q
    reduceStage :: Signal dom (Coeff, Coeff)
    reduceStage =
      fmap finalReduce mont3Reg

    reduceReg :: Signal dom (Coeff, Coeff)
    reduceReg =
      register
        (0, 0)
        reduceStage


    -- Stage 7:
    -- butterfly modular add/sub
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