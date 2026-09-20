{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}

module Component.NTT
  ( topEntity
  , butterfly
  , montgomeryMul
  ) where

import Clash.Prelude
import Component.NTTConstants (zetasMont)
import Component.NTTCore
  ( Coeff
  , PECount
  , PEInput
  , PEOutput
  , butterfly
  , montgomeryMul
  , peArray2
  )
import Component.NTTTH (makePipelineDelay)
import GHC.Generics (Generic)
import Prelude hiding ((!!), map, not, repeat, zipWith, (&&))

type Poly = Vec 256 Coeff

type ButterflyMeta =
  ( Bool
  , Index 256
  , Index 256
  , Bool
  )

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

zeroMeta :: ButterflyMeta
zeroMeta =
  (False, 0, 0, False)

$(makePipelineDelay "delay10" 10)

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

makeReadRequest
  :: NTTState
  -> Index PECount
  -> ReadRequest
makeReadRequest state lane =
  ReadRequest
    { rrValid     = statePhase state == Issue
    , rrAIndex    = aIndex
    , rrBIndex    = bIndex
    , rrZetaIndex = zetaIndex
    , rrLast      = opNumber == 127
    }
  where
    laneOffset :: Unsigned 8
    laneOffset =
      fromIntegral lane

    opNumber :: Unsigned 8
    opNumber =
      stateOp state + laneOffset

    (aIndex, bIndex, zetaIndex) =
      makeIndices
        (stateStage state)
        opNumber

makeReadRequests
  :: NTTState
  -> Vec PECount ReadRequest
makeReadRequests state =
  map (makeReadRequest state) indicesI

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

readPackets
  :: NTTState
  -> Vec PECount ReadRequest
  -> Vec PECount ButterflyPacket
readPackets state requests =
  map (readPacket state) requests

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

pipelinePair
  :: forall dom.
     HiddenClockResetEnable dom
  => Signal dom (Vec PECount ButterflyPacket)
  -> Signal dom (Vec PECount ButterflyResponse)
pipelinePair packetSignal =
  responseSignal
  where
    arithmeticInputs
      :: Signal dom (Vec PECount PEInput)
    arithmeticInputs =
      fmap
        (map
          (\packet ->
            ( bpA packet
            , bpB packet
            , bpZeta packet
            )
          )
        )
        packetSignal

    arithmeticOutputs
      :: Signal dom (Vec PECount PEOutput)
    arithmeticOutputs =
      peArray2 arithmeticInputs

    metadata
      :: Signal dom (Vec PECount ButterflyMeta)
    metadata =
      fmap
        (map
          (\packet ->
            ( bpValid packet
            , bpAIndex packet
            , bpBIndex packet
            , bpLast packet
            )
          )
        )
        packetSignal

    metaDelayed
      :: Signal dom (Vec PECount ButterflyMeta)
    metaDelayed =
      delay10
        (repeat zeroMeta)
        metadata

    responseSignal =
      liftA2
        (zipWith makeResponse)
        metaDelayed
        arithmeticOutputs

    makeResponse
      :: ButterflyMeta
      -> PEOutput
      -> ButterflyResponse
    makeResponse
      (valid, aIndex, bIndex, lastResult)
      (outA, outB) =
        ButterflyResponse
          { rspValid  = valid
          , rspAIndex = aIndex
          , rspBIndex = bIndex
          , rspA      = outA
          , rspB      = outB
          , rspLast   = lastResult
          }

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

writeResponses
  :: Vec PECount ButterflyResponse
  -> NTTState
  -> NTTState
writeResponses responses state =
  writeResponse
    (responses !! 1)
    (writeResponse
      (responses !! 0)
      state)

-- ------------------------------------------------------------------
-- Controller
-- ------------------------------------------------------------------
nttNextState
  :: NTTState
  -> (Bool, Poly)
  -> Vec PECount ButterflyResponse
  -> NTTState
nttNextState state (start, inputPoly) responses =
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
          writeResponses responses state

        lastIssue =
          stateOp state == 126
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
              , stateOp    = stateOp state + 2
              }

    Drain ->
      let
        stateAfterWrite =
          writeResponses responses state

        lastResponse =
          responses !! 1

        finalReturned =
          rspValid lastResponse
            && rspLast lastResponse

        lastStage =
          stateStage state == 7
      in
        if finalReturned
          then
            if lastStage
              then
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
--   -> 10-cycle 2-PE butterfly pipeline
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

    requestSignal :: Signal dom (Vec PECount ReadRequest)
    requestSignal =
      fmap makeReadRequests stateSignal

    requestReg :: Signal dom (Vec PECount ReadRequest)
    requestReg =
      register
        (repeat zeroReadRequest)
        requestSignal

    packetCombinational
      :: Signal dom (Vec PECount ButterflyPacket)
    packetCombinational =
      liftA2
        readPackets
        stateSignal
        requestReg

    packetReg :: Signal dom (Vec PECount ButterflyPacket)
    packetReg =
      register
        (repeat zeroButterflyPacket)
        packetCombinational

    responseSignal :: Signal dom (Vec PECount ButterflyResponse)
    responseSignal =
      pipelinePair packetReg

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