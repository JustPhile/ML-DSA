{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE TypeApplications #-}

module Component.NTT
  ( topEntity
  , butterfly
  , montgomeryMul
  ) where

import Component.NTTConfig
  ( PECount
  )

import Component.NTTCore
  ( Coeff,
    PEInput,
    PEOutput,
    butterfly,
    montgomeryMul,
    peArray
  )

import Clash.Prelude
import qualified Clash.Prelude as C

import Component.NTTCoeffController
  ( IssueIndex
  , CoeffControl(..)
  , zeroCoeffControl
  , makeCoeffControl
  , makePEInputs
  , makeWriteCommands
  , makeTwiddleAddresses
  )

import Component.NTTCoeffMem
  ( LogicalRow
  , RamIndex
  , ReadAddresses
  , ReadResults
  , RowIndex
  , WriteCommands
  , coeffMemory
  , nextBase
  , physicalRow
  )
import Component.NTTTwiddleMem
  ( TwiddleAddresses
  , TwiddleResults
  , twiddleMemory
  )
import Component.NTTTH (makePipelineDelay)
import GHC.Generics (Generic)
import Prelude hiding ((!!), map, not, repeat, zipWith, (&&))

type Poly = Vec 256 Coeff

-- ------------------------------------------------------------------
-- Controller state
-- stateUseA == True  : read A, write B
-- stateUseA == False : read B, write A
-- ------------------------------------------------------------------

data NTTPhase
  = Idle
  | Load
  | Issue
  | Drain
  | UnloadIssue
  | UnloadDrain
  deriving (Generic, NFDataX, Eq)

data NTTState = NTTState
  { statePhase     :: NTTPhase
  , stateDone      :: Bool
  , stateStage     :: Index 8
  , stateIssue     :: IssueIndex
  , stateBase      :: Unsigned 6
  , stateLoadRow   :: LogicalRow
  , stateUnloadRow :: LogicalRow
  , stateInput     :: Poly
  , stateOutput    :: Poly
  }
  deriving (Generic, NFDataX)

$(makePipelineDelay "delay11" 11)

initialState :: NTTState
initialState =
  NTTState
    { statePhase     = Idle
    , stateDone      = False
    , stateStage     = 0
    , stateIssue     = 0
    , stateBase      = 0
    , stateLoadRow   = 0
    , stateUnloadRow = 0
    , stateInput     = repeat 0
    , stateOutput    = repeat 0
    }

type UnloadMeta =
  (Bool, LogicalRow)

zeroUnloadMeta :: UnloadMeta
zeroUnloadMeta =
  (False, 0)

memoryCoefficientIndex
  :: LogicalRow
  -> RamIndex
  -> Index 256
memoryCoefficientIndex logicalRow ramIndex =
  fromIntegral coefficientNumber
  where
    peCountWide :: Unsigned 8
    peCountWide =
      natToNum @PECount

    rowWide :: Unsigned 8
    rowWide =
      fromIntegral logicalRow

    ramWide :: Unsigned 8
    ramWide =
      fromIntegral ramIndex

    bankNumber :: Unsigned 8
    bankNumber =
      ramWide `div` peCountWide

    blockNumber :: Unsigned 8
    blockNumber =
      ramWide `mod` peCountWide

    clusterNumber :: Unsigned 8
    clusterNumber =
      bankNumber `div` 2

    bankWithinCluster :: Unsigned 8
    bankWithinCluster =
      bankNumber `mod` 2

    withinHalf :: Unsigned 8
    withinHalf =
      rowWide * (2 * peCountWide)
        + bankWithinCluster * peCountWide
        + blockNumber

    coefficientNumber :: Unsigned 8
    coefficientNumber =
      clusterNumber * 128 + withinHalf

makeLoadCommands
  :: LogicalRow
  -> Poly
  -> WriteCommands
makeLoadCommands loadRow poly =
  imap makeCommand (repeat Nothing)
  where
    physicalMemoryRow :: RowIndex
    physicalMemoryRow =
      fromIntegral loadRow

    makeCommand
      :: RamIndex
      -> Maybe (RowIndex, Coeff)
      -> Maybe (RowIndex, Coeff)
    makeCommand ramIndex _ =
      Just
        ( physicalMemoryRow
        , poly !! memoryCoefficientIndex loadRow ramIndex
        )

makeUnloadReadAddresses
  :: Unsigned 6
  -> LogicalRow
  -> ReadAddresses
makeUnloadReadAddresses sourceBase unloadRow =
  repeat
    (physicalRow sourceBase unloadRow)

collectUnloadRow
  :: UnloadMeta
  -> ReadResults
  -> NTTState
  -> NTTState
collectUnloadRow (valid, unloadRow) ramOutputs state
  | not valid =
      state

  | otherwise =
      state
        { stateOutput =
            C.foldl
              storeCoefficient
              (stateOutput state)
              (C.zip C.indicesI ramOutputs)
        }
  where
    storeCoefficient
      :: Poly
      -> (RamIndex, Coeff)
      -> Poly
    storeCoefficient poly (ramIndex, coefficient) =
      replace
        (memoryCoefficientIndex unloadRow ramIndex)
        coefficient
        poly

nttNextState
  :: NTTState
  -> (Bool, Poly)
  -> Bool
  -> UnloadMeta
  -> ReadResults
  -> NTTState
nttNextState
  state
  (start, inputPoly)
  finalReturned
  unloadMeta
  memoryOutputs =
    case statePhase stateAfterUnload of
      Idle ->
        if start
          then
            stateAfterUnload
              { statePhase     = Load
              , stateDone      = False
              , stateStage     = 0
              , stateIssue     = 0
              , stateBase      = 0
              , stateLoadRow   = 0
              , stateUnloadRow = 0
              , stateInput     = inputPoly
              , stateOutput    = repeat 0
              }
          else
            stateAfterUnload
              { stateDone = False
              }

      Load ->
        if stateLoadRow stateAfterUnload == maxBound
          then
            stateAfterUnload
              { statePhase = Issue
              , stateIssue = 0
              , stateDone  = False
              }
          else
            stateAfterUnload
              { stateLoadRow =
                  stateLoadRow stateAfterUnload + 1
              , stateDone = False
              }

      Issue ->
        if stateIssue stateAfterUnload == maxBound
          then
            stateAfterUnload
              { statePhase = Drain
              , stateDone  = False
              }
          else
            stateAfterUnload
              { stateIssue =
                  stateIssue stateAfterUnload + 1
              , stateDone = False
              }

      Drain ->
        if finalReturned
          then
            if stateStage stateAfterUnload == 7
              then
                stateAfterUnload
                  { statePhase     = UnloadIssue
                  , stateDone      = False
                  , stateBase      =
                      nextBase (stateBase stateAfterUnload)
                  , stateUnloadRow = 0
                  }
              else
                stateAfterUnload
                  { statePhase = Issue
                  , stateDone  = False
                  , stateStage =
                      stateStage stateAfterUnload + 1
                  , stateIssue = 0
                  , stateBase =
                      nextBase (stateBase stateAfterUnload)
                  }
          else
            stateAfterUnload
              { stateDone = False
              }

      UnloadIssue ->
        if stateUnloadRow stateAfterUnload == maxBound
          then
            stateAfterUnload
              { statePhase = UnloadDrain
              , stateDone  = False
              }
          else
            stateAfterUnload
              { stateUnloadRow =
                  stateUnloadRow stateAfterUnload + 1
              , stateDone = False
              }

      UnloadDrain ->
        stateAfterUnload
          { statePhase = Idle
          , stateDone  = True
          }
  where
    stateAfterUnload =
      collectUnloadRow
        unloadMeta
        memoryOutputs
        state

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
    , fmap stateOutput stateSignal
    )
  where

    controlSignal :: Signal dom CoeffControl
    controlSignal =
      fmap
        (\state ->
          makeCoeffControl
            (statePhase state == Issue)
            (stateStage state)
            (stateBase state)
            (stateIssue state)
        )
        stateSignal

    memoryReadAddresses :: Signal dom ReadAddresses
    memoryReadAddresses =
      liftA2 selectReadAddresses stateSignal controlSignal

    selectReadAddresses :: NTTState -> CoeffControl -> ReadAddresses
    selectReadAddresses state control =
      case statePhase state of
        UnloadIssue ->
          makeUnloadReadAddresses (stateBase state) (stateUnloadRow state)

        _ ->
          ccReadAddresses control

    twiddleAddressSignal :: Signal dom TwiddleAddresses
    twiddleAddressSignal =
      fmap makeTwiddleAddresses controlSignal

    -- Metadata matching the one-cycle memory latency.
    readControlReg :: Signal dom CoeffControl
    readControlReg =
      register zeroCoeffControl controlSignal

    memoryOutputs :: Signal dom ReadResults
    memoryOutputs =
      coeffMemory
        memoryReadAddresses
        memoryWriteCommands

    twiddleOutputs :: Signal dom TwiddleResults
    twiddleOutputs =
      twiddleMemory twiddleAddressSignal

    peInputCombinational :: Signal dom (Vec PECount PEInput)
    peInputCombinational =
      liftA3
        makePEInputs
        readControlReg
        memoryOutputs
        twiddleOutputs

    -- Timing-isolation register before multiplier stage 1.
    peInputSignal :: Signal dom (Vec PECount PEInput)
    peInputSignal =
      register
        (repeat (0, 0, 0))
        peInputCombinational

    peOutputSignal :: Signal dom (Vec PECount PEOutput)
    peOutputSignal =
      peArray peInputSignal

    -- 10 PE cycles plus the new PE-input register.
    writeControlSignal :: Signal dom CoeffControl
    writeControlSignal =
      delay11
        zeroCoeffControl
        readControlReg

    computeWriteCommands :: Signal dom WriteCommands
    computeWriteCommands =
      liftA2 makeWriteCommands writeControlSignal peOutputSignal

    memoryWriteCommands :: Signal dom WriteCommands
    memoryWriteCommands =
      liftA2 selectWriteCommands stateSignal computeWriteCommands

    selectWriteCommands :: NTTState -> WriteCommands -> WriteCommands
    selectWriteCommands state computeCommands =
      case statePhase state of
        Load ->
          makeLoadCommands (stateLoadRow state) (stateInput state)

        _ ->
          computeCommands

    finalReturned :: Signal dom Bool
    finalReturned =
      fmap
        (\control ->
          ccValid control && ccLast control
        )
        writeControlSignal

    stateSignal :: Signal dom NTTState
    stateSignal =
      register initialState nextStateSignal

    unloadMetaSignal :: Signal dom UnloadMeta
    unloadMetaSignal =
      fmap
        (\state ->
          (
            statePhase state == UnloadIssue,
            stateUnloadRow state
          )
        )
        stateSignal

    unloadMetaReg :: Signal dom UnloadMeta
    unloadMetaReg =
      register
        zeroUnloadMeta
        unloadMetaSignal

    nextStateSignal :: Signal dom NTTState
    nextStateSignal =
      nttNextState
        <$> stateSignal
        <*> inputSignal
        <*> finalReturned
        <*> unloadMetaReg
        <*> memoryOutputs

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