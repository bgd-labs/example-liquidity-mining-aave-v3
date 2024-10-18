// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3EthereumLido, AaveV3EthereumLidoAssets} from 'aave-address-book/AaveV3EthereumLido.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';

import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';

contract CreateEmissionTestAwstETHLidoEthereum is BaseTest {
  /// @dev Used to simplify the definition of a program of emissions
  /// @param asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  /// @param emission Total emission of a `reward` token during the whole distribution duration defined
  /// E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  /// 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second
  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  address constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd; // aci
  address constant REWARD_ASSET = AaveV3EthereumLidoAssets.wstETH_A_TOKEN;
  address constant ASSET = AaveV3EthereumLidoAssets.wstETH_A_TOKEN;
  IEACAggregatorProxy constant REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3EthereumLidoAssets.wstETH_ORACLE);

  /// @dev already deployed and configured for the both the wstETH asset
  /// EMISSION_ADMIN
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0x4fDB95C607EDe09A548F60685b56C034992B194a);

  uint256 constant TOTAL_DISTRIBUTION = 10.5 ether; // 10.5 wstETH/week
  uint88 constant DURATION_DISTRIBUTION = 7 days;

  address awstETH_WHALE = 0xD090D2C8475c5eBdd1434A48897d81b9aAA20594; // 0.9607% of the supply, so <1% of the rewards
  address awstETH_WHALE2 = 0x684566C9FFcAC7F6A04C3a9997000d2d58C00824; // more than 5% of the supply

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20991496);
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
    bytes memory approval = abi.encodeWithSelector(
      IERC20(REWARD_ASSET).approve.selector,
      address(TRANSFER_STRATEGY),
      TOTAL_DISTRIBUTION
    );

    emit log_named_bytes('Approval Asset Reward', approval);

    IEmissionManager(AaveV3EthereumLido.EMISSION_MANAGER).configureAssets(_getAssetConfigs());
    bytes memory emmission = abi.encodeWithSelector(
      IEmissionManager.configureAssets.selector,
      _getAssetConfigs()
    );

    emit log_named_bytes('Create Emission', emmission);

    vm.stopPrank();

    _testClaimRewardsForWhale(awstETH_WHALE, ASSET, 96 * 10 ** 14); // 0.96%
    _testClaimRewardsForWhale(awstETH_WHALE2, ASSET, 51 * 10 ** 15); // 5.1%
    // _testClaimRewardsForWhale(awstETH_WHALE2, ASSET, 6 * 10 ** 16); // 6% => revert
  }

  function _testClaimRewardsForWhale(
    address whale,
    address asset,
    uint256 expectedRewardPercentage
  ) internal {
    vm.startPrank(whale);

    vm.warp(block.timestamp + DURATION_DISTRIBUTION);

    address[] memory assets = new address[](1);
    assets[0] = asset;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(whale);

    IAaveIncentivesController(AaveV3EthereumLido.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      whale,
      REWARD_ASSET
    );

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(whale);

    uint256 rewardsClaimed = balanceAfter - balanceBefore;
    uint256 rewardsExpected = (TOTAL_DISTRIBUTION * expectedRewardPercentage) / 10 ** 18;

    uint256 deviationAccepted = 10 ** 16; // 1% of deviation accepted
    assertApproxEqRel(
      rewardsClaimed,
      rewardsExpected,
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
      asset: ASSET,
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
