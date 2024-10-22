// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager, ITransferStrategyBase} from '../src/interfaces/IEmissionManager.sol';
import {LMUpdateBaseTest} from './utils/LMUpdateBaseTest.sol';

contract EmissionConfigurationTestMATICXPolygon is LMUpdateBaseTest {
  address public constant override DEFAULT_INCENTIVES_CONTROLLER =
    AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER;
  address public constant override REWARD_ASSET = AaveV3PolygonAssets.MaticX_UNDERLYING;
  uint256 public constant override NEW_TOTAL_DISTRIBUTION = 30_000 ether;
  address public constant override EMISSION_MANAGER = AaveV3Polygon.EMISSION_MANAGER;
  address public constant override EMISSION_ADMIN = 0x0c54a0BCCF5079478a144dBae1AFcb4FEdf7b263; // Polygon Foundation

  uint88 constant NEW_DURATION_DISTRIBUTION_END = 15 days;
  uint88 constant DURATION_DISTRIBUTION = 180 days;
  address constant vWMATIC_WHALE = 0xe52F5349153b8eb3B89675AF45aC7502C4997E6A;

  function setUp() public {
    // For this block LM for MATICX has already been initialized
    vm.createSelectFork(vm.rpcUrl('polygon'), 41047588);

    deal(REWARD_ASSET, EMISSION_ADMIN, NEW_TOTAL_DISTRIBUTION);
    address transferStrategy = IAaveIncentivesController(this.DEFAULT_INCENTIVES_CONTROLLER())
      .getTransferStrategy(this.REWARD_ASSET());
    vm.prank(EMISSION_ADMIN);
    IERC20(REWARD_ASSET).approve(transferStrategy, NEW_TOTAL_DISTRIBUTION);
  }

  function test_claimRewards() public {
    NewEmissionPerAsset memory newEmissionPerAsset = _getNewEmissionPerSecond();
    NewDistributionEndPerAsset memory newDistributionEndPerAsset = _getNewDistributionEnd();

    vm.startPrank(EMISSION_ADMIN);
    IEmissionManager(AaveV3Polygon.EMISSION_MANAGER).setEmissionPerSecond(
      newEmissionPerAsset.asset,
      newEmissionPerAsset.rewards,
      newEmissionPerAsset.newEmissionsPerSecond
    );
    IEmissionManager(AaveV3Polygon.EMISSION_MANAGER).setDistributionEnd(
      newDistributionEndPerAsset.asset,
      newDistributionEndPerAsset.reward,
      newDistributionEndPerAsset.newDistributionEnd
    );

    _testClaimRewardsForWhale(
      vWMATIC_WHALE,
      AaveV3PolygonAssets.WPOL_V_TOKEN,
      DURATION_DISTRIBUTION,
      41.72 ether
    );
  }

  function _getNewEmissionPerSecond() internal pure override returns (NewEmissionPerAsset memory) {
    NewEmissionPerAsset memory newEmissionPerAsset;

    address[] memory rewards = new address[](1);
    rewards[0] = REWARD_ASSET;
    uint88[] memory newEmissionsPerSecond = new uint88[](1);
    newEmissionsPerSecond[0] = _toUint88(NEW_TOTAL_DISTRIBUTION / DURATION_DISTRIBUTION);

    newEmissionPerAsset.asset = AaveV3PolygonAssets.WPOL_V_TOKEN;
    newEmissionPerAsset.rewards = rewards;
    newEmissionPerAsset.newEmissionsPerSecond = newEmissionsPerSecond;

    return newEmissionPerAsset;
  }

  function _getNewDistributionEnd()
    internal
    view
    override
    returns (NewDistributionEndPerAsset memory)
  {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset;

    newDistributionEndPerAsset.asset = AaveV3PolygonAssets.WPOL_V_TOKEN;
    newDistributionEndPerAsset.reward = REWARD_ASSET;
    newDistributionEndPerAsset.newDistributionEnd = _toUint32(
      block.timestamp + NEW_DURATION_DISTRIBUTION_END
    );

    return newDistributionEndPerAsset;
  }
}
