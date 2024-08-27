// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol'; // TODO: import Lido when lib is updated
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';
import 'forge-std/console.sol';

contract EmissionExtensionTestETHLMETH is BaseTest {
  // @dev Used to simplify the definition of a program of emissions
  //  asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  //  emission Total emission of a `reward` token during the whole distribution duration defined
  // E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  // 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second

  address constant wETHLIDO_A_Token = 0xfA1fDbBD71B0aA16162D76914d69cD8CB3Ef92da;// TODO: hardcoded for now will use lib when address book is updated
  address constant wETH_ORACLE = AaveV3EthereumAssets.WETH_ORACLE;


  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  struct NewEmissionPerAsset {
    address asset;
    address[] rewards;
    uint88[] newEmissionsPerSecond;
  }

  struct NewDistributionEndPerAsset {
    address asset;
    address reward;
    uint32 newDistributionEnd;
  }

  address constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd; // ACI
  address constant REWARD_ASSET = wETHLIDO_A_Token;

  uint256 constant NEW_TOTAL_DISTRIBUTION = 80 ether;
  uint88 constant NEW_DURATION_DISTRIBUTION_END = 14 days;

  IEACAggregatorProxy constant REWARD_ORACLE = IEACAggregatorProxy(wETH_ORACLE);

  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0x4fDB95C607EDe09A548F60685b56C034992B194a); // new deployed strategy

  uint256 constant TOTAL_DISTRIBUTION = 80 ether; // 80 awETH/14 Days
  uint88 constant DURATION_DISTRIBUTION = 14 days;
  
  // Not needed as ACI is first LP in market
  // address wETHLIDO_WHALE = 0xac140648435d03f784879cd789130F22Ef588Fcd;
  address WETH_A_TOKEN_WHALE = 0x464C71f6c2F760DdA6093dCB91C24c39e5d6e18c; // collector

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20611541); // change this when ready
  }

  function test_setNewEmissionPerSecond() public {
    NewEmissionPerAsset memory newEmissionPerAsset = _getNewEmissionPerSecond();

    vm.startPrank(EMISSION_ADMIN);

    // The emission admin can change the emission per second of the reward after the rewards have been configured.
    // Here we change the initial emission per second to the new one.
    IEmissionManager(AaveV3Ethereum.EMISSION_MANAGER).setEmissionPerSecond(
      newEmissionPerAsset.asset,
      newEmissionPerAsset.rewards,
      newEmissionPerAsset.newEmissionsPerSecond
    );
    emit log_named_bytes(
      'calldata to execute tx on EMISSION_MANAGER to set the new emission per second from the emissions admin (safe)',
      abi.encodeWithSelector(
        IEmissionManager.setEmissionPerSecond.selector,
        newEmissionPerAsset.asset,
        newEmissionPerAsset.rewards,
        newEmissionPerAsset.newEmissionsPerSecond
      )
    );

    vm.stopPrank();

    vm.warp(block.timestamp + 14 days);

    address[] memory assets = new address[](1);
    assets[0] = wETHLIDO_A_Token;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(WETH_A_TOKEN_WHALE);

    vm.startPrank(WETH_A_TOKEN_WHALE);

    IAaveIncentivesController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      WETH_A_TOKEN_WHALE,
      REWARD_ASSET
    );

    vm.stopPrank();

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(WETH_A_TOKEN_WHALE);

    // Approx estimated rewards with current emission in 1 month, considering the new emissions per second set.
    uint256 deviationAccepted = 80 ether;
    assertApproxEqAbs(
      balanceBefore,
      balanceAfter,
      deviationAccepted,
      'Invalid delta on claimed rewards'
    );
  }

  function _getNewEmissionPerSecond() internal pure returns (NewEmissionPerAsset memory) {
    NewEmissionPerAsset memory newEmissionPerAsset;

    address[] memory rewards = new address[](1);
    rewards[0] = REWARD_ASSET;
    uint88[] memory newEmissionsPerSecond = new uint88[](1);
    newEmissionsPerSecond[0] = _toUint88(NEW_TOTAL_DISTRIBUTION / DURATION_DISTRIBUTION);

    newEmissionPerAsset.asset = wETHLIDO_A_Token;
    newEmissionPerAsset.rewards = rewards;
    newEmissionPerAsset.newEmissionsPerSecond = newEmissionsPerSecond;

    return newEmissionPerAsset;
  }

  function _getNewDistributionEnd() internal view returns (NewDistributionEndPerAsset memory) {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset;

    newDistributionEndPerAsset.asset = wETHLIDO_A_Token;
    newDistributionEndPerAsset.reward = REWARD_ASSET;
    newDistributionEndPerAsset.newDistributionEnd = _toUint32(
      block.timestamp + NEW_DURATION_DISTRIBUTION_END
    );

    return newDistributionEndPerAsset;
  }

  function _toUint32(uint256 value) internal pure returns (uint32) {
    require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
    return uint32(value);
  }

// function test_extendDistributionEnd() public {
//     // Initial setup
//     // test_activation();

//     // Calculate new distribution end (14 days after the initial end)
//     uint32 newDistributionEnd = uint32(block.timestamp + 14 days);

//     vm.startPrank(EMISSION_ADMIN);

//     // Call setDistributionEnd with single values instead of arrays
//     IEmissionManager(AaveV3Ethereum.EMISSION_MANAGER).setDistributionEnd(
//         wETHLIDO_A_Token,
//         REWARD_ASSET,
//         newDistributionEnd
//     );

//     emit log_named_bytes(
//         'calldata to execute tx on EMISSION_MANAGER to extend the distribution end from the emissions admin (safe)',
//         abi.encodeWithSelector(
//             IEmissionManager.setDistributionEnd.selector,
//             wETHLIDO_A_Token,
//             REWARD_ASSET,
//             newDistributionEnd
//         )
//     );

//     vm.stopPrank();

//     // Test claiming rewards after extension
//     vm.warp(block.timestamp + 14 days); // 14 days initial

//     _testClaimRewardsForWhale(WETH_A_TOKEN_WHALE, wETHLIDO_A_Token, 0.2 ether);
// }

  function _testClaimRewardsForWhale(address whale, address asset, uint256 expectedReward) internal {
    
    vm.startPrank(whale);

    vm.warp(block.timestamp + 14 days);

    address[] memory assets = new address[](1);
    assets[0] = asset;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(whale);

    IAaveIncentivesController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      whale,
      REWARD_ASSET
    );

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(whale);

    uint256 deviationAccepted = expectedReward; // Approx estimated rewards with current emission in 1 month
    assertApproxEqAbs(
      balanceBefore,
      balanceAfter,
      deviationAccepted,
      'Invalid delta on claimed rewards'
    );

    vm.stopPrank();
  }

  function _getAssetConfigs() internal view returns (RewardsDataTypes.RewardsConfigInput[] memory) {
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

  function _getEmissionsPerAsset() internal pure returns (EmissionPerAsset[] memory) {
    EmissionPerAsset[] memory emissionsPerAsset = new EmissionPerAsset[](1);
    emissionsPerAsset[0] = EmissionPerAsset({asset: wETHLIDO_A_Token, emission: 80 ether});

    uint256 totalDistribution;
    for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
      totalDistribution += emissionsPerAsset[i].emission;
    }
    require(totalDistribution == TOTAL_DISTRIBUTION, 'INVALID_SUM_OF_EMISSIONS');

    return emissionsPerAsset;
  }

  function _toUint88(uint256 value) internal pure returns (uint88) {
    require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
    return uint88(value);
  }
}