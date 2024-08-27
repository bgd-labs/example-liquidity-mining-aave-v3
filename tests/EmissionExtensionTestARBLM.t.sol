// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol'; // TODO: import Lido when lib is updated
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';
import 'forge-std/console.sol';

contract EmissionExtensionTestARBLMGHO is BaseTest {
  // @dev Used to simplify the definition of a program of emissions
  //  asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  //  emission Total emission of a `reward` token during the whole distribution duration defined
  // E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  // 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second

  address constant GHO_A_TOKEN = AaveV3ArbitrumAssets.GHO_A_TOKEN;// TODO: hardcoded for now will use lib when address book is updated
  address constant ARB_ORACLE = AaveV3ArbitrumAssets.ARB_ORACLE;
  address constant ARB = AaveV3ArbitrumAssets.ARB_UNDERLYING;


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
  address constant REWARD_ASSET = ARB;

  uint256 constant NEW_TOTAL_DISTRIBUTION = 72_800 ether;
  uint88 constant NEW_DURATION_DISTRIBUTION_END = 15 days;

  IEACAggregatorProxy constant REWARD_ORACLE = IEACAggregatorProxy(ARB_ORACLE);

  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0x991bf7661F1F2695ac8AEFc4F9a19718d6424dc0); // new deployed strategy

  uint256 constant TOTAL_DISTRIBUTION = 72_800 ether; // 80 awETH/14 Days
  uint88 constant DURATION_DISTRIBUTION = 15 days;
  
  // Not needed as ACI is first LP in market
  // address wETHLIDO_WHALE = 0xac140648435d03f784879cd789130F22Ef588Fcd;
  address GHO_A_TOKEN_WHALE = 0xda39E48523770197EF3CbB70C1bf1cCCF9B4b1E7; 

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), 247245171); // change this when ready
  }

  function test_setNewEmissionPerSecond() public {
    NewEmissionPerAsset memory newEmissionPerAsset = _getNewEmissionPerSecond();

    vm.startPrank(EMISSION_ADMIN);

    // The emission admin can change the emission per second of the reward after the rewards have been configured.
    // Here we change the initial emission per second to the new one.
    IEmissionManager(AaveV3Arbitrum.EMISSION_MANAGER).setEmissionPerSecond(
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

    vm.warp(block.timestamp + 15 days);

    address[] memory assets = new address[](1);
    assets[0] = GHO_A_TOKEN;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(GHO_A_TOKEN_WHALE);

    vm.startPrank(GHO_A_TOKEN_WHALE);

    IAaveIncentivesController(AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      GHO_A_TOKEN_WHALE,
      REWARD_ASSET
    );

    vm.stopPrank();

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(GHO_A_TOKEN_WHALE);

    // Approx estimated rewards with current emission in 1 month, considering the new emissions per second set.
    uint256 deviationAccepted = 13_470 ether;
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

    newEmissionPerAsset.asset = GHO_A_TOKEN;
    newEmissionPerAsset.rewards = rewards;
    newEmissionPerAsset.newEmissionsPerSecond = newEmissionsPerSecond;

    return newEmissionPerAsset;
  }

  function _getNewDistributionEnd() internal view returns (NewDistributionEndPerAsset memory) {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset;

    newDistributionEndPerAsset.asset = GHO_A_TOKEN;
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

  function _testClaimRewardsForWhale(address whale, address asset, uint256 expectedReward) internal {
    
    vm.startPrank(whale);

    // claim before timewarp to grab all pending previous rewards

    address[] memory assets = new address[](1);
    assets[0] = asset;

    IAaveIncentivesController(AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      whale,
      REWARD_ASSET
    );

    vm.warp(block.timestamp + 15 days);

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(whale);

    IAaveIncentivesController(AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
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


  function _toUint88(uint256 value) internal pure returns (uint88) {
    require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
    return uint88(value);
  }
}