{-# LANGUAGE TemplateHaskell #-}

module Component.NTTTH
  ( makePipelineDelay
  ) where

import Clash.Prelude
import qualified Language.Haskell.TH as TH


-- ============================================================
-- Generic pipeline delay
-- ============================================================

makePipelineDelay :: String -> Int -> TH.Q [TH.Dec]
makePipelineDelay functionName stages = do
  let fnName = TH.mkName functionName

  initName <- TH.newName "initValue"
  sigName  <- TH.newName "sig"

  body <-
    makeDelayChain
      stages
      (TH.varE initName)
      (TH.varE sigName)

  declaration <-
    TH.funD
      fnName
      [ TH.clause
          [TH.varP initName, TH.varP sigName]
          (TH.normalB body)
          []
      ]

  pure [declaration]


makeDelayChain :: Int -> TH.ExpQ -> TH.ExpQ -> TH.ExpQ
makeDelayChain 0 _ sig =
  sig

makeDelayChain stages initValue sig =
  [|
    register
      $initValue
      $(makeDelayChain (stages - 1) initValue sig)
  |]
