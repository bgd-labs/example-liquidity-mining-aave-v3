import {Hex} from 'viem';

export interface LiquidityMiningSetup {
  emissionsAdmin: Hex;
  rewardToken: string;
  rewardTokenDecimals: number;
  rewardOracle: string;
  assets: string[];
  distributionEnd: string;
  transferStrategy: Hex;
  rewardAmounts: string[];
  totalReward: number;
  whaleAddresses: Hex[];
  whaleExpectedRewards: string[];
}

export interface LiquidityMiningUpdate {
  emissionsAdmin: Hex;
  rewardToken: string;
  rewardTokenDecimals: number;
  rewardAmount: string;
  asset: string;
  distributionEnd: string;
  whaleAddress: Hex;
  whaleExpectedReward: string;
}
