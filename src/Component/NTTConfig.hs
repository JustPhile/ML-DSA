{-# LANGUAGE DataKinds #-}
{-# LANGUAGE NoStarIsType #-}
{-# LANGUAGE TypeOperators #-}

module Component.NTTConfig
  ( PECount
  , IssueCount
  , CoeffRamCount
  , CoeffRamDepth
  , LogicalRowCount
  ) where

import Clash.Prelude
import GHC.TypeNats (Div)

-- Change this one line to 2, 4, or 8.
type PECount = 4

-- 128 butterflies per NTT stage.
type IssueCount = Div 128 PECount

-- Paper architecture: four banks, each containing PECount blocks.
type CoeffRamCount = 4 * PECount

-- Total coefficient capacity remains 384 = 1.5N.
type CoeffRamDepth = Div 96 PECount

-- Number of live logical rows in each memory rotation.
type LogicalRowCount = Div 64 PECount