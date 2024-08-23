// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';

import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';

contract EmissionTestSTMATICPolygon is BaseTest {
  /// @dev Used to simplify the definition of a program of emissions
  /// @param asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  /// @param emission Total emission of a `reward` token during the whole distribution duration defined
  /// E.g. With an emission of 10_000 stMATIC tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  /// 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 stMATIC per second
  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  address constant EMISSION_ADMIN = 0x0c54a0BCCF5079478a144dBae1AFcb4FEdf7b263; // Polygon Foundation
  address constant REWARD_ASSET = AaveV3PolygonAssets.stMATIC_UNDERLYING;
  IEACAggregatorProxy constant REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3PolygonAssets.stMATIC_ORACLE);

  /// @dev already deployed and configured for the both the stMATIC asset and the 0x0c54a0BCCF5079478a144dBae1AFcb4FEdf7b263
  /// EMISSION_ADMIN
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0x53F57eAAD604307889D87b747Fc67ea9DE430B01);

  uint256 constant TOTAL_DISTRIBUTION = 60_000 ether; // 10'000 stMATIC/month, 6 months
  uint88 constant DURATION_DISTRIBUTION = 180 days;

  address STMATIC_WHALE = 0x667Ed8Cb7cf2B83FF9922a1357B104F9F11eE6f9;
  address vWMATIC_WHALE = 0xe52F5349153b8eb3B89675AF45aC7502C4997E6A;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 60952532);
  }

  function test_activation() public {
    vm.startPrank(EMISSION_ADMIN);
    /// @dev IMPORTANT!!
    /// The emissions admin should have REWARD_ASSET funds, and have approved the TOTAL_DISTRIBUTION
    /// amount to the transfer strategy. If not, REWARDS WILL ACCRUE FINE AFTER `configureAssets()`, BUT THEY
    /// WILL NOT BE CLAIMABLE UNTIL THERE IS FUNDS AND ALLOWANCE.
    /// It is possible to approve less than TOTAL_DISTRIBUTION and doing it progressively over time as users
    /// accrue more, but that is a decision of the emission's admin
    IERC20(REWARD_ASSET).approve(address(TRANSFER_STRATEGY), TOTAL_DISTRIBUTION);

    IEmissionManager(AaveV3Polygon.EMISSION_MANAGER).configureAssets(_getAssetConfigs());

    emit log_named_bytes(
      'calldata to submit from Gnosis Safe',
      abi.encodeWithSelector(
        IEmissionManager(AaveV3Polygon.EMISSION_MANAGER).configureAssets.selector,
        _getAssetConfigs()
      )
    );

    vm.stopPrank();

    vm.startPrank(STMATIC_WHALE);
    IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, 50_000 ether);

    vm.stopPrank();

    vm.startPrank(vWMATIC_WHALE);

    vm.warp(block.timestamp + 30 days);

    address[] memory assets = new address[](1);
    assets[0] = AaveV3PolygonAssets.WMATIC_V_TOKEN;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(vWMATIC_WHALE);

    IAaveIncentivesController(AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      vWMATIC_WHALE,
      REWARD_ASSET
    );

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(vWMATIC_WHALE);

    uint256 deviationAccepted = 1300 ether; // Approx estimated rewards with current emission in 1 month
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
    emissionsPerAsset[0] = EmissionPerAsset({
      asset: AaveV3PolygonAssets.WMATIC_V_TOKEN,
      emission: TOTAL_DISTRIBUTION // 100% of the distribution
    });

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
