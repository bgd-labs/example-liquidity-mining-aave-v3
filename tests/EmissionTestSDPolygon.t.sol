// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';

import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';

contract EmissionTestSDPolygon is BaseTest {
  /// @dev Used to simplify the definition of a program of emissions
  /// @param asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  /// @param emission Total emission of a `reward` token during the whole distribution duration defined
  /// E.g. With an emission of 13_520 SD tokens during 1 month, an emission of 50% for aPolMATICX would be
  /// 13_520 * 1e18 * 50% / 30 days in seconds = 1_352 * 1e18 / 2_592_000 = ~ 0.000521604 * 1e18 SD per second
  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  address constant EMISSION_ADMIN = 0x51358004cFe135E64453d7F6a0dC433CAba09A2a; // Stader Safe
  address constant REWARD_ASSET = 0x1d734A02eF1e1f5886e66b0673b71Af5B53ffA94; // SD token
  IEACAggregatorProxy constant REWARD_ORACLE =
    IEACAggregatorProxy(0x30E9671a8092429A358a4E31d41381aa0D10b0a0); // SD/USD

  /// @dev already deployed and configured for the both the SD asset and the 0x51358004cFe135E64453d7F6a0dC433CAba09A2a
  /// EMISSION_ADMIN
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0xC51e6E38d406F98049622Ca54a6096a23826B426);

  uint256 constant TOTAL_DISTRIBUTION = 81_120 ether; // 13'520 SD/month, 6 months
  uint88 constant DURATION_DISTRIBUTION = 180 days;

  address SD_WHALE = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
  address aPolMATICX_WHALE = 0x807c561657E4Bf582Eee6C34046B0507Fc359960;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 39010930);
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

    vm.startPrank(SD_WHALE);
    IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, 50_000 ether);

    vm.stopPrank();

    vm.startPrank(0x807c561657E4Bf582Eee6C34046B0507Fc359960);

    vm.warp(block.timestamp + 2_592_000);

    address[] memory assets = new address[](1);
    assets[0] = 0x80cA0d8C38d2e2BcbaB66aA1648Bd1C7160500FE;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(aPolMATICX_WHALE);

    IAaveIncentivesController(AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      aPolMATICX_WHALE,
      REWARD_ASSET
    );

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(aPolMATICX_WHALE);

    uint256 deviationAccepted = 2200 ether; // Approx estimated rewards with current emission in 1 month
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
      asset: AaveV3PolygonAssets.MaticX_A_TOKEN,
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
