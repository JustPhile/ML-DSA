{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Component.NTT
  ( topEntity
  , butterfly
  , montgomeryMul
  ) where

import Clash.Prelude
import Component.NTTConstants (zetasMont)
import Component.NTTCore
  ( Coeff
  , butterfly
  , butterflyPipeline
  , montgomeryMul
  )
import GHC.Generics (Generic)
import Prelude hiding ((!!), repeat, not, (&&))

type Poly = Vec 256 Coeff

-- ------------------------------------------------------------------
-- Controller state
-- stateUseA == True  : read A, write B
-- stateUseA == False : read B, write A
-- ------------------------------------------------------------------

data NTTPhase
  = Idle
  | Issue
  | Drain
  deriving (Generic, NFDataX, Eq)

data NTTState = NTTState
  { statePhase :: NTTPhase
  , stateDone  :: Bool
  , stateStage :: Index 8
  , stateOp    :: Unsigned 8
  , stateUseA  :: Bool
  , stateBufA  :: Poly
  , stateBufB  :: Poly
  }
  deriving (Generic, NFDataX)

initialState :: NTTState
initialState =
  NTTState
    { statePhase = Idle
    , stateDone  = False
    , stateStage = 0
    , stateOp    = 0
    , stateUseA  = True
    , stateBufA  = repeat 0
    , stateBufB  = repeat 0
    }

-- ------------------------------------------------------------------
-- NTT stage addressing
-- ------------------------------------------------------------------
stageParameters
  :: Index 8
  -> (Unsigned 9, Unsigned 9)
stageParameters stage =
  case stage of
    0 -> (128,   1)
    1 -> ( 64,   2)
    2 -> ( 32,   4)
    3 -> ( 16,   8)
    4 -> (  8,  16)
    5 -> (  4,  32)
    6 -> (  2,  64)
    7 -> (  1, 128)

makeIndices
  :: Index 8
  -> Unsigned 8
  -> (Index 256, Index 256, Index 256)
makeIndices stage opNumber =
  (aIndex, bIndex, zetaIndex)
  where
    (len, zetaBase) =
      stageParameters stage

    opWide :: Unsigned 9
    opWide =
      resize opNumber

    groupIndex :: Unsigned 9
    groupIndex =
      opWide `div` len

    position :: Unsigned 9
    position =
      opWide `mod` len

    groupSize :: Unsigned 9
    groupSize =
      2 * len

    aRaw :: Unsigned 9
    aRaw =
      groupIndex * groupSize + position

    bRaw :: Unsigned 9
    bRaw =
      aRaw + len

    aIndex :: Index 256
    aIndex =
      fromIntegral aRaw

    bIndex :: Index 256
    bIndex =
      fromIntegral bRaw

    zetaIndex :: Index 256
    zetaIndex =
      fromIntegral (zetaBase + groupIndex)

-- ------------------------------------------------------------------
-- Registered address request
-- ------------------------------------------------------------------
data ReadRequest = ReadRequest
  { rrValid     :: Bool
  , rrAIndex    :: Index 256
  , rrBIndex    :: Index 256
  , rrZetaIndex :: Index 256
  , rrLast      :: Bool
  }
  deriving (Generic, NFDataX)

zeroReadRequest :: ReadRequest
zeroReadRequest =
  ReadRequest
    { rrValid     = False
    , rrAIndex    = 0
    , rrBIndex    = 0
    , rrZetaIndex = 0
    , rrLast      = False
    }

makeReadRequest :: NTTState -> ReadRequest
makeReadRequest state =
  ReadRequest
    { rrValid     = statePhase state == Issue
    , rrAIndex    = aIndex
    , rrBIndex    = bIndex
    , rrZetaIndex = zetaIndex
    , rrLast      = stateOp state == 127
    }
  where
    (aIndex, bIndex, zetaIndex) =
      makeIndices
        (stateStage state)
        (stateOp state)

-- ------------------------------------------------------------------
-- Registered coefficient packet
-- ------------------------------------------------------------------
data ButterflyPacket = ButterflyPacket
  { bpValid  :: Bool
  , bpAIndex :: Index 256
  , bpBIndex :: Index 256
  , bpA      :: Coeff
  , bpB      :: Coeff
  , bpZeta   :: Coeff
  , bpLast   :: Bool
  }
  deriving (Generic, NFDataX)

zeroButterflyPacket :: ButterflyPacket
zeroButterflyPacket =
  ButterflyPacket
    { bpValid  = False
    , bpAIndex = 0
    , bpBIndex = 0
    , bpA      = 0
    , bpB      = 0
    , bpZeta   = 0
    , bpLast   = False
    }

readPacket
  :: NTTState
  -> ReadRequest
  -> ButterflyPacket
readPacket state request =
  ButterflyPacket
    { bpValid  = rrValid request
    , bpAIndex = rrAIndex request
    , bpBIndex = rrBIndex request
    , bpA      = sourcePoly !! rrAIndex request
    , bpB      = sourcePoly !! rrBIndex request
    , bpZeta   = zetasMont !! rrZetaIndex request
    , bpLast   = rrLast request
    }
  where
    sourcePoly =
      if stateUseA state
        then stateBufA state
        else stateBufB state

-- ------------------------------------------------------------------
-- Pipeline response
-- ------------------------------------------------------------------
data ButterflyResponse = ButterflyResponse
  { rspValid  :: Bool
  , rspAIndex :: Index 256
  , rspBIndex :: Index 256
  , rspA      :: Coeff
  , rspB      :: Coeff
  , rspLast   :: Bool
  }
  deriving (Generic, NFDataX)

zeroButterflyResponse :: ButterflyResponse
zeroButterflyResponse =
  ButterflyResponse
    { rspValid  = False
    , rspAIndex = 0
    , rspBIndex = 0
    , rspA      = 0
    , rspB      = 0
    , rspLast   = False
    }

pipelineLane
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom ButterflyPacket
  -> Signal dom ButterflyResponse
pipelineLane packetSignal =
  responseSignal
  where
    arithmeticInput :: Signal dom (Coeff, Coeff, Coeff)
    arithmeticInput =
      fmap
        (\packet ->
          ( bpA packet
          , bpB packet
          , bpZeta packet
          )
        )
        packetSignal

    arithmeticOutput :: Signal dom (Coeff, Coeff)
    arithmeticOutput =
      butterflyPipeline arithmeticInput

    metadata :: Signal dom (Bool, Index 256, Index 256, Bool)
    metadata =
      fmap
        (\packet ->
          ( bpValid packet
          , bpAIndex packet
          , bpBIndex packet
          , bpLast packet
          )
        )
        packetSignal

    -- butterflyPipeline currently has seven register stages.
    metaReg1 :: Signal dom (Bool, Index 256, Index 256, Bool)
    metaReg1 =
      register (False, 0, 0, False) metadata

    metaReg2 :: Signal dom (Bool, Index 256, Index 256, Bool)
    metaReg2 =
      register (False, 0, 0, False) metaReg1

    metaReg3 :: Signal dom (Bool, Index 256, Index 256, Bool)
    metaReg3 =
      register (False, 0, 0, False) metaReg2

    metaReg4 :: Signal dom (Bool, Index 256, Index 256, Bool)
    metaReg4 =
      register (False, 0, 0, False) metaReg3

    metaReg5 :: Signal dom (Bool, Index 256, Index 256, Bool)
    metaReg5 =
      register (False, 0, 0, False) metaReg4

    metaReg6 :: Signal dom (Bool, Index 256, Index 256, Bool)
    metaReg6 =
      register (False, 0, 0, False) metaReg5

    metaReg7 :: Signal dom (Bool, Index 256, Index 256, Bool)
    metaReg7 =
      register (False, 0, 0, False) metaReg6

    responseSignal :: Signal dom ButterflyResponse
    responseSignal =
      liftA2
        (\(valid, aIndex, bIndex, lastResult) (outA, outB) ->
          ButterflyResponse
            { rspValid  = valid
            , rspAIndex = aIndex
            , rspBIndex = bIndex
            , rspA      = outA
            , rspB      = outB
            , rspLast   = lastResult
            }
        )
        metaReg7
        arithmeticOutput

-- ------------------------------------------------------------------
-- Ping-pong writeback
-- ------------------------------------------------------------------
writeResponse
  :: ButterflyResponse
  -> NTTState
  -> NTTState
writeResponse response state
  | not (rspValid response) =
      state

  | stateUseA state =
      -- source A -> destination B
      state
        { stateBufB =
            replace
              (rspBIndex response)
              (rspB response)
              (replace
                (rspAIndex response)
                (rspA response)
                (stateBufB state))
        }

  | otherwise =
      -- source B -> destination A
      state
        { stateBufA =
            replace
              (rspBIndex response)
              (rspB response)
              (replace
                (rspAIndex response)
                (rspA response)
                (stateBufA state))
        }

-- ------------------------------------------------------------------
-- Controller
-- ------------------------------------------------------------------
nttNextState
  :: NTTState
  -> (Bool, Poly)
  -> ButterflyResponse
  -> NTTState
nttNextState state (start, inputPoly) response =
  case statePhase state of
    Idle ->
      if start
        then
          NTTState
            { statePhase = Issue
            , stateDone  = False
            , stateStage = 0
            , stateOp    = 0
            , stateUseA  = True
            , stateBufA  = inputPoly
            , stateBufB  = repeat 0
            }
        else
          state
            { stateDone = False
            }

    Issue ->
      let
        stateAfterWrite =
          writeResponse response state

        lastIssue =
          stateOp state == 127
      in
        if lastIssue
          then
            stateAfterWrite
              { statePhase = Drain
              , stateDone  = False
              }
          else
            stateAfterWrite
              { statePhase = Issue
              , stateDone  = False
              , stateOp    = stateOp state + 1
              }

    Drain ->
      let
        stateAfterWrite =
          writeResponse response state

        finalReturned =
          rspValid response && rspLast response

        lastStage =
          stateStage state == 7
      in
        if finalReturned
          then
            if lastStage
              then
                -- Toggle once more so stateUseA points to the
                -- buffer that now contains the final result.
                stateAfterWrite
                  { statePhase = Idle
                  , stateDone  = True
                  , stateOp    = 0
                  , stateUseA  = not (stateUseA state)
                  }
              else
                stateAfterWrite
                  { statePhase = Issue
                  , stateDone  = False
                  , stateStage = stateStage state + 1
                  , stateOp    = 0
                  , stateUseA  = not (stateUseA state)
                  }
          else
            stateAfterWrite
              { stateDone = False
              }

currentResult :: NTTState -> Poly
currentResult state =
  if stateUseA state
    then stateBufA state
    else stateBufB state

-- ------------------------------------------------------------------
-- Complete pipelined NTT
--
-- issue request
--   -> request register
--   -> coefficient read/register
--   -> 3-cycle butterfly pipeline
--   -> writeback
--
-- ------------------------------------------------------------------
nttPipelined
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom (Bool, Poly)
  -> Signal dom (Bool, Poly)
nttPipelined inputSignal =
  bundle
    ( fmap stateDone stateSignal
    , fmap currentResult stateSignal
    )
  where
    stateSignal :: Signal dom NTTState
    stateSignal =
      register initialState nextStateSignal

    requestSignal :: Signal dom ReadRequest
    requestSignal =
      fmap makeReadRequest stateSignal

    -- Stage A: register address/control.
    requestReg :: Signal dom ReadRequest
    requestReg =
      register zeroReadRequest requestSignal

    -- Stage B: dynamic coefficient read, then register it.
    packetCombinational :: Signal dom ButterflyPacket
    packetCombinational =
      liftA2
        readPacket
        stateSignal
        requestReg

    packetReg :: Signal dom ButterflyPacket
    packetReg =
      register zeroButterflyPacket packetCombinational

    -- Stages C/D/E: arithmetic pipeline in NTTCore.
    responseSignal :: Signal dom ButterflyResponse
    responseSignal =
      pipelineLane packetReg

    nextStateSignal :: Signal dom NTTState
    nextStateSignal =
      liftA3
        nttNextState
        stateSignal
        inputSignal
        responseSignal

-- ------------------------------------------------------------------
-- Top entity
-- ------------------------------------------------------------------
topEntity
  :: Clock System
  -> Reset System
  -> Enable System
  -> Signal System Bool
  -> Signal System Poly
  -> ( Signal System Bool
     , Signal System Poly
     )
topEntity clk rst en start poly =
  unbundle result
  where
    result =
      exposeClockResetEnable
        nttPipelined
        clk
        rst
        en
        (bundle (start, poly))

{-# ANN topEntity
  (Synthesize
    { t_name = "NTT256"
    , t_inputs =
        [ PortName "clk"
        , PortName "rst"
        , PortName "en"
        , PortName "start"
        , PortName "poly"
        ]
    , t_output =
        PortProduct ""
          [ PortName "done"
          , PortName "result"
          ]
    }) #-}