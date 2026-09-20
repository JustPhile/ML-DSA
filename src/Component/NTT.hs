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

import Component.NTTCoeffController
  ( IssueIndex
  , CoeffControl(..)
  , zeroCoeffControl
  , makeCoeffControl
  , makePEInputs
  , makeWriteCommands
  )

import Component.NTTCoeffMem
  ( LogicalRow
  , ReadAddresses
  , ReadResults
  , RowIndex
  , WriteCommands
  , coeffMemory
  , nextBase
  , physicalRow
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
  , stateLoadRow   :: Index 32
  , stateUnloadRow :: Index 32
  , stateInput     :: Poly
  , stateOutput    :: Poly
  }
  deriving (Generic, NFDataX)

$(makePipelineDelay "delay10" 10)

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
  (Bool, Index 32)

zeroUnloadMeta :: UnloadMeta
zeroUnloadMeta =
  (False, 0)

makeLoadCommands
  :: Index 32
  -> Poly
  -> WriteCommands
makeLoadCommands loadRow poly =
  Just (physicalMemoryRow, poly !! index0)
    :> Just (physicalMemoryRow, poly !! index1)
    :> Just (physicalMemoryRow, poly !! index2)
    :> Just (physicalMemoryRow, poly !! index3)
    :> Just (physicalMemoryRow, poly !! index4)
    :> Just (physicalMemoryRow, poly !! index5)
    :> Just (physicalMemoryRow, poly !! index6)
    :> Just (physicalMemoryRow, poly !! index7)
    :> Nil
  where
    physicalMemoryRow :: RowIndex
    physicalMemoryRow =
      fromIntegral loadRow

    rowWide :: Unsigned 8
    rowWide =
      resize
        (fromIntegral loadRow :: Unsigned 5)

    lowerBase :: Unsigned 8
    lowerBase =
      shiftL rowWide 2

    upperBase :: Unsigned 8
    upperBase =
      lowerBase + 128

    index0, index1, index2, index3 :: Index 256
    index4, index5, index6, index7 :: Index 256

    index0 = fromIntegral lowerBase
    index1 = fromIntegral (lowerBase + 1)
    index2 = fromIntegral (lowerBase + 2)
    index3 = fromIntegral (lowerBase + 3)

    index4 = fromIntegral upperBase
    index5 = fromIntegral (upperBase + 1)
    index6 = fromIntegral (upperBase + 2)
    index7 = fromIntegral (upperBase + 3)

makeUnloadReadAddresses
  :: Unsigned 6
  -> Index 32
  -> ReadAddresses
makeUnloadReadAddresses sourceBase unloadRow =
  repeat row
  where
    logicalRow :: LogicalRow
    logicalRow =
      fromIntegral unloadRow

    row :: RowIndex
    row =
      physicalRow sourceBase logicalRow

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
            replace index7 (ramOutputs !! 7) $
            replace index6 (ramOutputs !! 6) $
            replace index5 (ramOutputs !! 5) $
            replace index4 (ramOutputs !! 4) $
            replace index3 (ramOutputs !! 3) $
            replace index2 (ramOutputs !! 2) $
            replace index1 (ramOutputs !! 1) $
            replace index0 (ramOutputs !! 0) $
            stateOutput state
        }
  where
    rowWide :: Unsigned 8
    rowWide =
      resize
        (fromIntegral unloadRow :: Unsigned 5)

    lowerBase :: Unsigned 8
    lowerBase =
      shiftL rowWide 2

    upperBase :: Unsigned 8
    upperBase =
      lowerBase + 128

    index0, index1, index2, index3 :: Index 256
    index4, index5, index6, index7 :: Index 256

    index0 = fromIntegral lowerBase
    index1 = fromIntegral (lowerBase + 1)
    index2 = fromIntegral (lowerBase + 2)
    index3 = fromIntegral (lowerBase + 3)

    index4 = fromIntegral upperBase
    index5 = fromIntegral (upperBase + 1)
    index6 = fromIntegral (upperBase + 2)
    index7 = fromIntegral (upperBase + 3)

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
        if stateLoadRow stateAfterUnload == 31
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
        if stateIssue stateAfterUnload == 63
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
        if stateUnloadRow stateAfterUnload == 31
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
      liftA2
        selectReadAddresses
        stateSignal
        controlSignal

    selectReadAddresses :: NTTState -> CoeffControl -> ReadAddresses
    selectReadAddresses state control =
      case statePhase state of
        UnloadIssue ->
          makeUnloadReadAddresses
            (stateBase state)
            (stateUnloadRow state)

        _ ->
          ccReadAddresses control

    -- blockRam has one-cycle read latency.
    readControlReg :: Signal dom CoeffControl
    readControlReg =
      register zeroCoeffControl controlSignal

    memoryOutputs :: Signal dom ReadResults
    memoryOutputs =
      coeffMemory
        memoryReadAddresses
        memoryWriteCommands

    peInputSignal :: Signal dom (Vec 2 PEInput)
    peInputSignal =
      liftA2
        makePEInputs
        readControlReg
        memoryOutputs

    peOutputSignal :: Signal dom (Vec 2 PEOutput)
    peOutputSignal =
      peArray2 peInputSignal

    -- Align write metadata with the 10-cycle PE pipeline.
    writeControlSignal :: Signal dom CoeffControl
    writeControlSignal =
      delay10
        zeroCoeffControl
        readControlReg

    computeWriteCommands :: Signal dom WriteCommands
    computeWriteCommands =
      liftA2
        makeWriteCommands
        writeControlSignal
        peOutputSignal

    memoryWriteCommands :: Signal dom WriteCommands
    memoryWriteCommands =
      liftA2
        selectWriteCommands
        stateSignal
        computeWriteCommands

    selectWriteCommands :: NTTState -> WriteCommands -> WriteCommands
    selectWriteCommands state computeCommands =
      case statePhase state of
        Load ->
          makeLoadCommands
            (stateLoadRow state)
            (stateInput state)

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