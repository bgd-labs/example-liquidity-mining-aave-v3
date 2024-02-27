// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3BNB, AaveV3BNBAssets} from 'aave-address-book/AaveV3BNB.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';

import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';
import 'forge-std/console.sol';

contract EmissionTestFdUSDBNB is BaseTest {
  /// @dev Used to simplify the definition of a program of emissions
  /// @param asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  /// @param emission Total emission of a `reward` token during the whole distribution duration defined
  /// E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  /// 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second
  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  address constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd; // ACI
  address constant REWARD_ASSET = AaveV3BNBAssets.FDUSD_UNDERLYING;

  IEACAggregatorProxy constant REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3BNBAssets.FDUSD_ORACLE);

  /// @dev already deployed and configured for the both the fdUSD asset and the 0xac140648435d03f784879cd789130F22Ef588Fcd EMISSION_ADMIN
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0xF585F8cf39C1ef5353326e0352B9E237f9A52587);

  uint256 constant TOTAL_DISTRIBUTION = 30_000 ether; // 30'000 fdUSD/month, 1 month
  uint88 constant DURATION_DISTRIBUTION = 30 days;

  address FDUSD_WHALE = 0xF977814e90dA44bFA03b6295A0616a897441aceC;
  address v_FDUSD_WHALE = 0x8A4Be368254a6D66d4de397D7172c53028C9d230;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('bnb'), 36478868);
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

    IEmissionManager(AaveV3BNB.EMISSION_MANAGER).configureAssets(_getAssetConfigs());

    emit log_named_bytes(
      'calldata to submit from Gnosis Safe',
      abi.encodeWithSelector(
        IEmissionManager(AaveV3BNB.EMISSION_MANAGER).configureAssets.selector,
        _getAssetConfigs()
      )
    );

    vm.stopPrank();

    vm.startPrank(FDUSD_WHALE);
    IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, TOTAL_DISTRIBUTION);
    vm.stopPrank();

    vm.startPrank(v_FDUSD_WHALE);

    vm.warp(block.timestamp + 30 days);

    address[] memory assets = new address[](1);
    assets[0] = AaveV3BNBAssets.FDUSD_V_TOKEN;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(v_FDUSD_WHALE);

    IAaveIncentivesController(AaveV3BNB.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      v_FDUSD_WHALE,
      REWARD_ASSET
    );

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(v_FDUSD_WHALE);

    uint256 deviationAccepted = 3380 ether; // Approx estimated rewards with current emission in 1 month
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
      asset: AaveV3BNBAssets.FDUSD_V_TOKEN,
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
