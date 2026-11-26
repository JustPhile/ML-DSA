{-# LANGUAGE DataKinds #-}
{-# LANGUAGE NoStarIsType #-}
{-# LANGUAGE TypeOperators #-}

module Component.NTTConfig
  ( PECount
  , ClusterCount
  , BanksPerCluster
  , BankCount
  , RamsPerCluster
  , CoeffRamCount
  , IssueCount
  , CoeffRamDepth
  , LogicalRowCount
  ) where

import Clash.Prelude
import GHC.TypeNats (Div)

type PECount = 2

type ClusterCount = 2

type BanksPerCluster = 2

type BankCount =
  ClusterCount * BanksPerCluster

type RamsPerCluster =
  BanksPerCluster * PECount

type CoeffRamCount =
  ClusterCount * RamsPerCluster

type IssueCount =
  Div 128 PECount

type LogicalRowCount =
  Div 64 PECount

type CoeffRamDepth =
  Div 96 PECount