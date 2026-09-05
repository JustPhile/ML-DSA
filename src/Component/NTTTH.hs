{-# LANGUAGE TemplateHaskell #-}

module Component.NTTTH
  ( makePipelineDelay
  ) where

import Clash.Prelude
import Language.Haskell.TH
import qualified Prelude as P

-- Generates:
--
-- delay10 initValue sig =
--   register initValue
--     (register initValue
--       ...
--         sig)
--
makePipelineDelay
  :: String
  -> Int
  -> Q [Dec]
makePipelineDelay functionName stages = do
  initName <- newName "initValue"
  sigName  <- newName "sig"

  let fnName = mkName functionName

      delayOne input =
        AppE
          (AppE
            (VarE 'register)
            (VarE initName))
          input

      body =
        P.iterate delayOne (VarE sigName) P.!! stages

  pure
    [ FunD
        fnName
        [ Clause
            [ VarP initName
            , VarP sigName
            ]
            (NormalB body)
            []
        ]
    ]