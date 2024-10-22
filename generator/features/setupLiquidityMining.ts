import * as addressBook from '@bgd-labs/aave-address-book';
import {Hex} from 'viem';
import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {LiquidityMiningSetup} from './types';
import {
  supplyUnderlyingAssetsSelectPrompt,
  supplyBorrowAssetsSelectPrompt,
  translateAssetToOracleLibUnderlying,
  translateAssetToAssetLibUnderlying,
  translateSupplyBorrowAssetToWhaleConstant,
} from '../prompts/assetsSelectPrompt';
import {addressPrompt} from '../prompts/addressPrompt';
import {percentPrompt} from '../prompts/percentPrompt';
import {numberPromptInDays} from '../prompts/numberPrompt';
import {
  getTokenDecimals,
  getExplorerTokenHoldersLink,
  getAddressOfSupplyBorrowAsset,
  getPoolChain,
  CHAIN_TO_CHAIN_ID,
  calculateExpectedWhaleRewards,
} from '../common';

export async function fetchLiquidityMiningSetupParams({pool}): Promise<LiquidityMiningSetup> {
  let rewardToken = await supplyUnderlyingAssetsSelectPrompt({
    message: 'Select the reward asset for the LM:',
    pool,
    required: true,
  });
  let rewardOracle: string;
  let rewardTokenAddress: Hex;

  if (rewardToken == 'custom') {
    rewardToken = await addressPrompt({
      message: 'Enter the address of the reward asset:',
      required: true,
    });
    rewardOracle = await addressPrompt({
      message: 'Enter the address of the reward oracle:',
      required: true,
    });
    rewardTokenAddress = rewardToken as Hex;
  } else {
    rewardOracle = translateAssetToOracleLibUnderlying(rewardToken, pool);
    rewardTokenAddress = rewardToken.includes('_aToken')
      ? addressBook[pool].ASSETS[rewardToken.replace('_aToken', '')].A_TOKEN
      : addressBook[pool].ASSETS[rewardToken].UNDERLYING;
    rewardToken = translateAssetToAssetLibUnderlying(rewardToken, pool);
  }
  const emissionsAdmin = await addressPrompt({
    message: 'Enter the address of the emissionsAdmin:',
    required: true,
  });

  const distributionEnd = await numberPromptInDays({
    message: 'Enter the total distribution time for the LM in days:',
    required: true,
  });
  const transferStrategy = await addressPrompt({
    message: 'Enter the address of the transfer strategy contract deployed:',
    required: true,
  });
  const assets = await supplyBorrowAssetsSelectPrompt({
    message: 'Enter the assets for which the LM should be configured:',
    pool,
    required: true,
  });

  const rewardAmounts: string[] = [];
  const whaleAddresses: Hex[] = [];
  const whaleExpectedRewards: string[] = [];
  let totalReward: number = 0;
  const chainId: number = CHAIN_TO_CHAIN_ID[getPoolChain(pool)];
  const rewardTokenDecimals = await getTokenDecimals(rewardTokenAddress, chainId);

  for (const index in assets) {
    const rewardAmount = await percentPrompt({
      message: `Enter the reward amount (in token units) for the reward token to be distributed for ${assets[index]}`,
      required: true,
    });
    totalReward += Number(rewardAmount);
    const supplyBorrowAssetAddress = getAddressOfSupplyBorrowAsset(pool, assets[index]);
    const whaleAddress = await addressPrompt({
      message: `Enter the whale address to test rewards for ${
        assets[index]
      } from ${getExplorerTokenHoldersLink(chainId, supplyBorrowAssetAddress)} `,
      required: true,
    });
    rewardAmounts.push(rewardAmount);
    whaleAddresses.push(whaleAddress);
    whaleExpectedRewards.push(
      await calculateExpectedWhaleRewards(
        whaleAddress,
        supplyBorrowAssetAddress,
        rewardAmount,
        chainId
      )
    );
  }

  return {
    emissionsAdmin,
    rewardToken,
    rewardTokenDecimals,
    rewardOracle,
    assets,
    distributionEnd,
    transferStrategy,
    rewardAmounts,
    totalReward,
    whaleAddresses,
    whaleExpectedRewards,
  };
}

export const setupLiquidityMining: FeatureModule<LiquidityMiningSetup> = {
  value: FEATURE.SETUP_LM,
  description: 'Setup new liquidity mining',
  async cli({pool}) {
    console.log(`Fetching information for setting new liquidity mining on ${pool}`);
    const response: LiquidityMiningSetup = await fetchLiquidityMiningSetupParams({pool});
    return response;
  },
  build({pool, cfg}) {
    const response: CodeArtifact = {
      code: {
        constants: [
          cfg.rewardToken.includes('0x')
            ? `address public constant override REWARD_ASSET = ${cfg.rewardToken};`
            : `address public constant override REWARD_ASSET = ${pool}Assets.${cfg.rewardToken}_UNDERLYING;`,
          `uint88 constant DURATION_DISTRIBUTION = ${cfg.distributionEnd} days;`,
          `uint256 public constant override TOTAL_DISTRIBUTION = ${cfg.totalReward} * 10 ** ${cfg.rewardTokenDecimals};`,
          `address constant EMISSION_ADMIN = ${cfg.emissionsAdmin};\n`,
          `address public constant override DEFAULT_INCENTIVES_CONTROLLER = ${pool}.DEFAULT_INCENTIVES_CONTROLLER;\n`,
          `ITransferStrategyBase public constant override TRANSFER_STRATEGY = ITransferStrategyBase(${cfg.transferStrategy});\n`,
          `IEACAggregatorProxy public constant override REWARD_ORACLE = IEACAggregatorProxy(${cfg.rewardOracle});\n`,
          ...cfg.assets.map((asset, index) => {
            let whaleConstants = `address constant ${translateSupplyBorrowAssetToWhaleConstant(
              asset,
              pool
            )} = ${cfg.whaleAddresses[index]};`;
            return whaleConstants;
          }),
        ],
        fn: [
          `
          function test_activation() public {
            vm.prank(EMISSION_ADMIN);
            IEmissionManager(${pool}.EMISSION_MANAGER).configureAssets(_getAssetConfigs());

            emit log_named_bytes(
              'calldata to submit from Gnosis Safe',
              abi.encodeWithSelector(
                IEmissionManager(${pool}.EMISSION_MANAGER).configureAssets.selector,
                _getAssetConfigs()
              )
            );

            ${cfg.assets
              .map(
                (assets, ix) => `
                _testClaimRewardsForWhale(
                  ${translateSupplyBorrowAssetToWhaleConstant(assets, pool)},
                  ${translateAssetToAssetLibUnderlying(assets, pool)},
                  DURATION_DISTRIBUTION,
                  ${cfg.whaleExpectedRewards[ix]} * 10 ** ${cfg.rewardTokenDecimals}
                );`
              )
              .join('\n')}
          }

            function _getAssetConfigs() internal override view returns (RewardsDataTypes.RewardsConfigInput[] memory) {
              uint32 distributionEnd = uint32(block.timestamp + DURATION_DISTRIBUTION);

              EmissionPerAsset[] memory emissionsPerAsset = _getEmissionsPerAsset();

              RewardsDataTypes.RewardsConfigInput[]
                memory configs = new RewardsDataTypes.RewardsConfigInput[](emissionsPerAsset.length);
              for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
                configs[i] = RewardsDataTypes.RewardsConfigInput({
                  emissionPerSecond: _toUint88(emissionsPerAsset[i].emission / DURATION_DISTRIBUTION),
                  totalSupply: 0, // IMPORTANT this will not be taken into account by the contracts, so 0 is fine
                  distributionEnd: distributionEnd,
                  asset: emissionsPerAsset[i].asset,
                  reward: REWARD_ASSET,
                  transferStrategy: TRANSFER_STRATEGY,
                  rewardOracle: REWARD_ORACLE
                });
              }

              return configs;
            }

           function _getEmissionsPerAsset() internal override pure returns (EmissionPerAsset[] memory) {
            EmissionPerAsset[] memory emissionsPerAsset = new EmissionPerAsset[](${
              cfg.assets.length
            });
            ${cfg.assets
              .map(
                (assets, ix) => `
                emissionsPerAsset[${ix}] = EmissionPerAsset({
                  asset: ${translateAssetToAssetLibUnderlying(assets, pool)},
                  emission: ${cfg.rewardAmounts[ix]} * 10 ** ${cfg.rewardTokenDecimals}
                });`
              )
              .join('\n')}

            uint256 totalDistribution;
            for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
              totalDistribution += emissionsPerAsset[i].emission;
            }
            require(totalDistribution == TOTAL_DISTRIBUTION, 'INVALID_SUM_OF_EMISSIONS');

            return emissionsPerAsset;
          }
          `,
        ],
      },
    };
    return response;
  },
};
