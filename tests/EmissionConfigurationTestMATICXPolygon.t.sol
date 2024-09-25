// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager} from '../src/interfaces/IEmissionManager.sol';
import {LMUpdateBaseTest} from './utils/LMUpdateBaseTest.sol';

contract EmissionConfigurationTestMATICXPolygon is LMUpdateBaseTest {
  address constant EMISSION_ADMIN = 0x0c54a0BCCF5079478a144dBae1AFcb4FEdf7b263; // Polygon Foundation
  address constant REWARD_ASSET = AaveV3PolygonAssets.MaticX_UNDERLYING;

  uint256 constant NEW_TOTAL_DISTRIBUTION = 30_000 ether;
  uint88 constant NEW_DURATION_DISTRIBUTION_END = 15 days;
  uint88 constant DURATION_DISTRIBUTION = 180 days;

  address vWMATIC_WHALE = 0xe52F5349153b8eb3B89675AF45aC7502C4997E6A;

  function setUp() public {
    // For this block LM for MATICX has already been initialized
    vm.createSelectFork(vm.rpcUrl('polygon'), 41047588);
  }

  function test_setNewEmissionPerSecond() public {
    NewEmissionPerAsset memory newEmissionPerAsset = _getNewEmissionPerSecond();

    vm.startPrank(EMISSION_ADMIN);

    // The emission admin can change the emission per second of the reward after the rewards have been configured.
    // Here we change the initial emission per second to the new one.
    IEmissionManager(AaveV3Polygon.EMISSION_MANAGER).setEmissionPerSecond(
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

    vm.warp(block.timestamp + 30 days);

    address[] memory assets = new address[](1);
    assets[0] = AaveV3PolygonAssets.WMATIC_V_TOKEN;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(vWMATIC_WHALE);

    vm.startPrank(vWMATIC_WHALE);

    IAaveIncentivesController(AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      vWMATIC_WHALE,
      REWARD_ASSET
    );

    vm.stopPrank();

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(vWMATIC_WHALE);

    // Approx estimated rewards with current emission in 1 month, considering the new emissions per second set.
    uint256 deviationAccepted = 650 ether;
    assertApproxEqAbs(
      balanceBefore,
      balanceAfter,
      deviationAccepted,
      'Invalid delta on claimed rewards'
    );
  }

  function test_setNewDistributionEnd() public {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset = _getNewDistributionEnd();

    vm.startPrank(EMISSION_ADMIN);

    IEmissionManager(AaveV3Polygon.EMISSION_MANAGER).setDistributionEnd(
      newDistributionEndPerAsset.asset,
      newDistributionEndPerAsset.reward,
      newDistributionEndPerAsset.newDistributionEnd
    );
    emit log_named_bytes(
      'calldata to execute tx on EMISSION_MANAGER to set the new distribution end from the emissions admin (safe)',
      abi.encodeWithSelector(
        IEmissionManager.setDistributionEnd.selector,
        newDistributionEndPerAsset.asset,
        newDistributionEndPerAsset.reward,
        newDistributionEndPerAsset.newDistributionEnd
      )
    );

    vm.stopPrank();

    vm.warp(block.timestamp + 30 days);

    address[] memory assets = new address[](1);
    assets[0] = AaveV3PolygonAssets.WMATIC_V_TOKEN;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(vWMATIC_WHALE);

    vm.startPrank(vWMATIC_WHALE);

    IAaveIncentivesController(AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      vWMATIC_WHALE,
      REWARD_ASSET
    );

    vm.stopPrank();

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(vWMATIC_WHALE);

    // Approx estimated rewards with current emission in 15 days, as we changed the distribution end.
    uint256 deviationAccepted = 650 ether;
    assertApproxEqAbs(
      balanceBefore,
      balanceAfter,
      deviationAccepted,
      'Invalid delta on claimed rewards'
    );
  }

  function _getNewEmissionPerSecond() internal override pure returns (NewEmissionPerAsset memory) {
    NewEmissionPerAsset memory newEmissionPerAsset;

    address[] memory rewards = new address[](1);
    rewards[0] = REWARD_ASSET;
    uint88[] memory newEmissionsPerSecond = new uint88[](1);
    newEmissionsPerSecond[0] = _toUint88(NEW_TOTAL_DISTRIBUTION / DURATION_DISTRIBUTION);

    newEmissionPerAsset.asset = AaveV3PolygonAssets.WMATIC_V_TOKEN;
    newEmissionPerAsset.rewards = rewards;
    newEmissionPerAsset.newEmissionsPerSecond = newEmissionsPerSecond;

    return newEmissionPerAsset;
  }

  function _getNewDistributionEnd() internal override view returns (NewDistributionEndPerAsset memory) {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset;

    newDistributionEndPerAsset.asset = AaveV3PolygonAssets.WMATIC_V_TOKEN;
    newDistributionEndPerAsset.reward = REWARD_ASSET;
    newDistributionEndPerAsset.newDistributionEnd = _toUint32(
      block.timestamp + NEW_DURATION_DISTRIBUTION_END
    );

    return newDistributionEndPerAsset;
  }
}
