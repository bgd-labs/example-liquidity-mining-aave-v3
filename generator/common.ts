import * as addressBook from '@bgd-labs/aave-address-book';
import {Options, PoolIdentifier, PoolIdentifierV3} from './types';
import {
  arbitrum,
  avalanche,
  mainnet,
  metis,
  optimism,
  polygon,
  base,
  bsc,
  gnosis,
  scroll,
  zkSync,
} from 'viem/chains';
import {Hex, getAddress, getContract} from 'viem';
import {CHAIN_ID_CLIENT_MAP} from '@bgd-labs/js-utils';
import {IERC20Detailed_ABI} from '@bgd-labs/aave-address-book/abis';
import BigNumber from 'bignumber.js';

export const AVAILABLE_CHAINS = [
  'Ethereum',
  'Optimism',
  'Arbitrum',
  'Polygon',
  'Avalanche',
  'Fantom',
  'Harmony',
  'Metis',
  'Base',
  'BNB',
  'Gnosis',
  'Scroll',
  'ZkSync',
] as const;

export function getAssets(pool: PoolIdentifier): string[] {
  const assets = addressBook[pool].ASSETS;
  return Object.keys(assets);
}

export function getSupplyAssets(pool: PoolIdentifier): string[] {
  const assets = addressBook[pool].ASSETS;
  const supplyAssets: string[] = [];

  for (const underlying of Object.keys(assets)) {
    supplyAssets.push(underlying + '_aToken');
  }
  return supplyAssets;
}

export function getSupplyBorrowAssets(pool: PoolIdentifier): string[] {
  const assets = addressBook[pool].ASSETS;
  const supplyBorrowAssets: string[] = [];

  for (const underlying of Object.keys(assets)) {
    supplyBorrowAssets.push(underlying + '_variableDebtToken');
    supplyBorrowAssets.push(underlying + '_aToken');
  }
  return supplyBorrowAssets;
}

export function getAddressOfSupplyBorrowAsset(pool: PoolIdentifier, asset: string): Hex {
  const isBorrowAsset: boolean = asset.includes('_variableDebtToken');
  const underlyingAsset = isBorrowAsset
    ? asset.replace('_variableDebtToken', '')
    : asset.replace('_aToken', '');
  return isBorrowAsset
    ? addressBook[pool].ASSETS[underlyingAsset].V_TOKEN
    : addressBook[pool].ASSETS[underlyingAsset].A_TOKEN;
}

export async function calculateExpectedWhaleRewards(
  whaleAddress: Hex,
  asset: Hex,
  rewardAmount: string,
  chainId: number
) {
  const assetContract = getContract({
    abi: IERC20Detailed_ABI,
    client: CHAIN_ID_CLIENT_MAP[chainId],
    address: asset,
  });
  const assetTotalSupply = await assetContract.read.totalSupply();
  const whaleBalance = await assetContract.read.balanceOf([whaleAddress]);

  const whaleRewardsShare = new BigNumber(whaleBalance.toString()).div(
    new BigNumber(assetTotalSupply.toString())
  );
  return whaleRewardsShare.multipliedBy(new BigNumber(rewardAmount)).decimalPlaces(2).toString();
}

export async function getTokenDecimals(asset: Hex, chainId: number): Promise<number> {
  const assetContract = getContract({
    abi: IERC20Detailed_ABI,
    client: CHAIN_ID_CLIENT_MAP[chainId],
    address: asset,
  });
  return assetContract.read.decimals();
}

export function getPoolChain(pool: PoolIdentifier) {
  const chain = AVAILABLE_CHAINS.find((chain) => pool.indexOf(chain) !== -1);
  if (!chain) throw new Error('cannot find chain for pool');
  return chain;
}

export function getExplorerLink(chainId: number, address: Hex) {
  const client = CHAIN_ID_CLIENT_MAP[chainId];
  let url = client.chain?.blockExplorers?.default.url;
  if (url && url.endsWith('/')) {
    url = url.slice(0, -1); // sanitize explorer url
  }
  return `${url}/address/${getAddress(address)}`;
}

export function getExplorerTokenHoldersLink(chainId: number, address: Hex) {
  const client = CHAIN_ID_CLIENT_MAP[chainId];
  let url = client.chain?.blockExplorers?.default.url;
  if (url && url.endsWith('/')) {
    url = url.slice(0, -1); // sanitize explorer url
  }
  return `${url}/token/${getAddress(address)}#balances`;
}

export function getDate() {
  const date = new Date();
  const years = date.getFullYear();
  const months = date.getMonth() + 1; // it's js so months are 0 indexed
  const day = date.getDate();
  return `${years}${months <= 9 ? '0' : ''}${months}${day <= 9 ? '0' : ''}${day}`;
}

/**
 * Prefix with the date for proper sorting
 * @param {*} options
 * @returns
 */
export function generateFolderName(options: Options) {
  const isLMSetup = options.feature == 'SETUP_LM';
  return isLMSetup
    ? `${options.date}_LMSetup${options.pool}_${options.shortName}`
    : `${options.date}_LMUpdate${options.pool}_${options.shortName}`;
}

/**
 * Suffix with the date as prefixing would generate invalid contract names
 * @param {*} options
 * @param {*} chain
 * @returns
 */
export function generateContractName(options: Options, pool?: PoolIdentifier) {
  let name = pool ? `${pool}_` : '';
  const isLMSetup = options.feature == 'SETUP_LM';
  name += isLMSetup ? 'LMSetup' : 'LMUpdate';
  name += `${options.shortName}`;
  name += `_${options.date}`;
  return name;
}

export function getChainAlias(chain) {
  return chain === 'Ethereum' ? 'mainnet' : chain.toLowerCase();
}

export function pascalCase(str: string) {
  return str
    .replace(/[\W]/g, ' ') // remove special chars as this is used for solc contract name
    .replace(/(\w)(\w*)/g, function (g0, g1, g2) {
      return g1.toUpperCase() + g2;
    })
    .replace(/ /g, '');
}

export const CHAIN_TO_CHAIN_ID = {
  Ethereum: mainnet.id,
  Polygon: polygon.id,
  Optimism: optimism.id,
  Arbitrum: arbitrum.id,
  Avalanche: avalanche.id,
  Metis: metis.id,
  Base: base.id,
  BNB: bsc.id,
  Gnosis: gnosis.id,
  Scroll: scroll.id,
  ZkSync: zkSync.id,
};

export function flagAsRequired(message: string, required?: boolean) {
  return required ? `${message}*` : message;
}
