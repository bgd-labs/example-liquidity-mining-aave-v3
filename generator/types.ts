import * as addressBook from '@bgd-labs/aave-address-book';
import {LiquidityMiningSetup, LiquidityMiningUpdate} from './features/types';

export const V3_POOLS = [
  'AaveV3Ethereum',
  'AaveV3EthereumLido',
  'AaveV3EthereumEtherFi',
  'AaveV3Polygon',
  'AaveV3Avalanche',
  'AaveV3Optimism',
  'AaveV3Arbitrum',
  'AaveV3Metis',
  'AaveV3Base',
  'AaveV3Gnosis',
  'AaveV3Scroll',
  'AaveV3BNB',
  'AaveV3ZkSync',
] as const satisfies readonly (keyof typeof addressBook)[];

export const POOLS = [...V3_POOLS] as const satisfies readonly (keyof typeof addressBook)[];

export type PoolIdentifier = (typeof POOLS)[number];
export type PoolIdentifierV3 = (typeof V3_POOLS)[number];

export interface Options {
  force?: boolean;
  feature: FEATURE;
  pool: PoolIdentifier;
  title: string;
  shortName: string;
  configFile?: string;
  date: string;
}

export type PoolConfigs = Partial<Record<PoolIdentifier, PoolConfig>>;

export type CodeArtifact = {
  code?: {
    constants?: string[];
    fn?: string[];
    execute?: string[];
  };
};

export enum FEATURE {
  SETUP_LM = 'SETUP_LM',
  UPDATE_LM = 'UPDATE_LM',
}

export interface FeatureModule<T extends {} = {}> {
  description: string;
  value: FEATURE;
  cli: (args: {options: Options; pool: PoolIdentifier; cache: PoolCache}) => Promise<T>;
  build: (args: {options: Options; pool: PoolIdentifier; cache: PoolCache; cfg: T}) => CodeArtifact;
}

export type ConfigFile = {
  rootOptions: Options;
  poolOptions: Partial<Record<PoolIdentifier, Omit<PoolConfig, 'artifacts'>>>;
};

export type PoolCache = {blockNumber: number};

export interface PoolConfig {
  artifacts: CodeArtifact[];
  configs: {
    [FEATURE.SETUP_LM]?: LiquidityMiningSetup;
    [FEATURE.UPDATE_LM]?: LiquidityMiningUpdate;
  };
  cache: PoolCache;
}

export type Files = {
  jsonConfig: string;
  payloadTest: {pool: PoolIdentifier; payloadTest: string; contractName: string};
};
