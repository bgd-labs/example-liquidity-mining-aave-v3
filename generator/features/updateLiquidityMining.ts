import * as addressBook from '@bgd-labs/aave-address-book';
import {Hex, getContract, Address} from 'viem';
import {CodeArtifact, FEATURE, FeatureModule} from '../types';
import {LiquidityMiningUpdate} from './types';
import {
  supplyUnderlyingAssetsSelectPrompt,
  supplyBorrowAssetSelectPrompt,
  translateAssetToAssetLibUnderlying,
  translateSupplyBorrowAssetToWhaleConstant,
} from '../prompts/assetsSelectPrompt';
import {addressPrompt} from '../prompts/addressPrompt';
import {percentPrompt} from '../prompts/percentPrompt';
import {CHAIN_ID_CLIENT_MAP} from '@bgd-labs/js-utils';
import {numberPromptInDays} from '../prompts/numberPrompt';
import {
  getTokenDecimals,
  getExplorerTokenHoldersLink,
  getAddressOfSupplyBorrowAsset,
  getPoolChain,
  CHAIN_TO_CHAIN_ID,
  calculateExpectedWhaleRewards,
} from '../common';

export async function fetchLiquidityMiningUpdateParams({pool}): Promise<LiquidityMiningUpdate> {
  let rewardToken = await supplyUnderlyingAssetsSelectPrompt({
    message: 'Select the reward asset for the LM:',
    pool,
    required: true,
  });
  let rewardTokenAddress: Hex;
  if (rewardToken == 'custom') {
    rewardToken = await addressPrompt({
      message: 'Enter the address of the reward asset for which LM should be updated:',
      required: true,
    });
    rewardTokenAddress = rewardToken as Hex;
  } else {
    rewardTokenAddress = rewardToken.includes('_aToken')
      ? addressBook[pool].ASSETS[rewardToken.replace('_aToken', '')].A_TOKEN
      : addressBook[pool].ASSETS[rewardToken].UNDERLYING;
    rewardToken = translateAssetToAssetLibUnderlying(rewardToken, pool);
  }
  const asset = await supplyBorrowAssetSelectPrompt({
    message: 'Enter the asset for which the LM should be updated:',
    pool,
    required: true,
  });
  const distributionEnd = await numberPromptInDays({
    message: 'Enter the new distribution time in days from the current timestamp:',
    required: true,
  });
  const chainId: number = CHAIN_TO_CHAIN_ID[getPoolChain(pool)];

  const rewardAmount = await percentPrompt({
    message: `Enter the new updated reward amount (in token units) for the reward token to be distributed`,
    required: true,
  });
  const supplyBorrowAssetAddress = getAddressOfSupplyBorrowAsset(pool, asset);
  const whaleAddress = await addressPrompt({
    message: `Enter the whale address to test rewards for ${asset} from ${getExplorerTokenHoldersLink(
      chainId,
      supplyBorrowAssetAddress
    )} `,
    required: true,
  });
  const whaleExpectedReward = await calculateExpectedWhaleRewards(
    whaleAddress,
    supplyBorrowAssetAddress,
    rewardAmount,
    chainId
  );
  const rewardTokenDecimals = await getTokenDecimals(rewardTokenAddress, chainId);

  const emissionManagerContract = getContract({
    abi: [
      {
        inputs: [{type: 'address'}],
        name: 'getEmissionAdmin',
        outputs: [{type: 'address'}],
        stateMutability: 'view',
        type: 'function',
      },
    ],
    client: CHAIN_ID_CLIENT_MAP[chainId],
    address: addressBook[pool].EMISSION_MANAGER,
  });
  const emissionsAdmin = (await emissionManagerContract.read.getEmissionAdmin([
    rewardTokenAddress,
  ])) as Address;

  return {
    emissionsAdmin,
    rewardToken,
    rewardTokenDecimals,
    asset,
    distributionEnd,
    rewardAmount,
    whaleAddress,
    whaleExpectedReward,
  };
}

export const updateLiquidityMining: FeatureModule<LiquidityMiningUpdate> = {
  value: FEATURE.UPDATE_LM,
  description: 'Updating existing liquidity mining',
  async cli({pool}) {
    console.log(`Fetching information for updating liquidity mining on ${pool}`);
    const response: LiquidityMiningUpdate = await fetchLiquidityMiningUpdateParams({pool});
    return response;
  },
  build({pool, cfg}) {
    const response: CodeArtifact = {
      code: {
        constants: [
          `address public constant override REWARD_ASSET = ${cfg.rewardToken};`,
          `uint256 public constant override NEW_TOTAL_DISTRIBUTION = ${cfg.rewardAmount} * 10 ** ${cfg.rewardTokenDecimals};`,
          `address public constant override EMISSION_ADMIN = ${cfg.emissionsAdmin};`,
          `address public constant override EMISSION_MANAGER = ${pool}.EMISSION_MANAGER;`,
          `uint256 public constant NEW_DURATION_DISTRIBUTION_END = ${cfg.distributionEnd} days;`,
          `address public constant ${translateSupplyBorrowAssetToWhaleConstant(
            cfg.asset,
            pool
          )} = ${cfg.whaleAddress};\n`,
          `address public constant override DEFAULT_INCENTIVES_CONTROLLER = ${pool}.DEFAULT_INCENTIVES_CONTROLLER;\n`,
        ],
        fn: [
          `
          function test_claimRewards() public {
            NewEmissionPerAsset memory newEmissionPerAsset = _getNewEmissionPerSecond();
            NewDistributionEndPerAsset memory newDistributionEndPerAsset = _getNewDistributionEnd();

            vm.startPrank(EMISSION_ADMIN);
            IEmissionManager(${pool}.EMISSION_MANAGER).setEmissionPerSecond(
              newEmissionPerAsset.asset,
              newEmissionPerAsset.rewards,
              newEmissionPerAsset.newEmissionsPerSecond
            );
            IEmissionManager(${pool}.EMISSION_MANAGER).setDistributionEnd(
              newDistributionEndPerAsset.asset,
              newDistributionEndPerAsset.reward,
              newDistributionEndPerAsset.newDistributionEnd
            );

            _testClaimRewardsForWhale(
              ${translateSupplyBorrowAssetToWhaleConstant(cfg.asset, pool)},
              ${translateAssetToAssetLibUnderlying(cfg.asset, pool)},
              NEW_DURATION_DISTRIBUTION_END,
              ${cfg.whaleExpectedReward} * 10 ** ${cfg.rewardTokenDecimals}
            );
          }

          function _getNewEmissionPerSecond() internal override pure returns (NewEmissionPerAsset memory) {
            NewEmissionPerAsset memory newEmissionPerAsset;

            address[] memory rewards = new address[](1);
            rewards[0] = REWARD_ASSET;
            uint88[] memory newEmissionsPerSecond = new uint88[](1);
            newEmissionsPerSecond[0] = _toUint88(NEW_TOTAL_DISTRIBUTION / NEW_DURATION_DISTRIBUTION_END);

            newEmissionPerAsset.asset = ${translateAssetToAssetLibUnderlying(cfg.asset, pool)};
            newEmissionPerAsset.rewards = rewards;
            newEmissionPerAsset.newEmissionsPerSecond = newEmissionsPerSecond;

            return newEmissionPerAsset;
          }

          function _getNewDistributionEnd() internal override view returns (NewDistributionEndPerAsset memory) {
            NewDistributionEndPerAsset memory newDistributionEndPerAsset;

            newDistributionEndPerAsset.asset = ${translateAssetToAssetLibUnderlying(
              cfg.asset,
              pool
            )};
            newDistributionEndPerAsset.reward = REWARD_ASSET;
            newDistributionEndPerAsset.newDistributionEnd = _toUint32(
              block.timestamp + NEW_DURATION_DISTRIBUTION_END
            );

            return newDistributionEndPerAsset;
          }
          `,
        ],
      },
    };
    return response;
  },
};
