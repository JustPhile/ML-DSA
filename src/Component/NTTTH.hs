{-# LANGUAGE TemplateHaskell #-}

module Component.NTTTH
  ( makePipelineDelay
  ) where

import Clash.Prelude
import qualified Language.Haskell.TH as TH
import qualified Prelude as P


-- ============================================================
-- Generic pipeline delay
-- ============================================================

makePipelineDelay :: String -> Int -> TH.Q [TH.Dec]
makePipelineDelay functionName stages = do
  initName <- TH.newName "initValue"
  sigName  <- TH.newName "sig"

  let
    fnName = TH.mkName functionName

    delayOne :: TH.Exp -> TH.Exp
    delayOne input = TH.AppE (TH.AppE (TH.VarE 'register) (TH.VarE initName)) input

    body :: TH.Exp
    body = P.iterate delayOne (TH.VarE sigName) P.!! stages

  pure [TH.FunD fnName [TH.Clause [TH.VarP initName, TH.VarP sigName] (TH.NormalB body) []]]
