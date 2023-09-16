// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Metis, AaveV3MetisAssets} from 'aave-address-book/AaveV3Metis.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';

contract EmissionTestMetMetis is BaseTest {
  /// @dev Used to simplify the definition of a program of emissions
  /// @param asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  /// @param emission Total emission of a `reward` token during the whole distribution duration defined
  /// E.g. With an emission of 100_000 METIS tokens during 6 month, an emission of 14.2857% for variableDebtWeth for 6 months would be
  /// 100_000 * 1e18 * 14.2857% / 180 days in seconds = 14285.7 * 1e18 / 15_552_000 = ~ 0.000918576 * 1e18 METIS per second
  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  address constant EMISSION_ADMIN = 0x97177cD80475f8b38945c1E77e12F0c9d50Ac84D; // Metis team
  address constant REWARD_ASSET = AaveV3MetisAssets.Metis_UNDERLYING;
  IEACAggregatorProxy constant REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3MetisAssets.Metis_ORACLE);

  /// @dev already deployed and configured transfer strategy contract
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0xC353D1A5C4242F400b61EEe34dC2213cdAb4Ef80);

  uint256 constant TOTAL_DISTRIBUTION = 6750 ether; // 6750 Metis/month
  uint88 constant DURATION_DISTRIBUTION = 30 days;

  address METIS_WHALE = 0xD3545B9E29cefd2273d2C6f64b4Ee8ebBaE5Af11;
  address vWETH_WHALE = 0x77d0Fb80eb7902c9A8952A47e0D189dB845fceb7;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('metis'), 8284260);
  }

  function test_metis_activation() public {
    vm.startPrank(EMISSION_ADMIN);
    /// @dev IMPORTANT!!
    /// The emissions admin should have REWARD_ASSET funds, and have approved the TOTAL_DISTRIBUTION
    /// amount to the transfer strategy. If not, REWARDS WILL ACCRUE FINE AFTER `configureAssets()`, BUT THEY
    /// WILL NOT BE CLAIMABLE UNTIL THERE IS FUNDS AND ALLOWANCE.
    /// It is possible to approve less than TOTAL_DISTRIBUTION and doing it progressively over time as users
    /// accrue more, but that is a decision of the emission's admin
    IERC20(REWARD_ASSET).approve(address(TRANSFER_STRATEGY), TOTAL_DISTRIBUTION);

    IEmissionManager(AaveV3Metis.EMISSION_MANAGER).configureAssets(_getAssetConfigs());

    emit log_named_bytes(
      'calldata to submit from Gnosis Safe',
      abi.encodeWithSelector(
        IEmissionManager(AaveV3Metis.EMISSION_MANAGER).configureAssets.selector,
        _getAssetConfigs()
      )
    );

    vm.stopPrank();

    // fund the emissions admin
    vm.startPrank(METIS_WHALE);
    IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, 6750 ether);
    vm.stopPrank();

    // test claim rewards
    vm.startPrank(vWETH_WHALE);
    vm.warp(block.timestamp + 30 days);

    address[] memory assets = new address[](1);
    assets[0] = AaveV3MetisAssets.WETH_V_TOKEN;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(vWETH_WHALE);

    IAaveIncentivesController(AaveV3Metis.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      vWETH_WHALE,
      REWARD_ASSET
    );

    uint256 vWethWhaleBalance = IERC20(AaveV3MetisAssets.WETH_V_TOKEN).balanceOf(vWETH_WHALE);
    uint256 vWethSupply = IERC20(AaveV3MetisAssets.WETH_V_TOKEN).totalSupply();

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(vWETH_WHALE);

    uint256 expectedRewards = vWethWhaleBalance * (675 ether) / vWethSupply;
    uint256 deviationAccepted = 5 ether;
    assertApproxEqAbs(
      balanceAfter - balanceBefore,
      expectedRewards,
      deviationAccepted,
      'Invalid delta on claimed rewards'
    );
    vm.stopPrank();
  }

  function _getAssetConfigs() internal returns (RewardsDataTypes.RewardsConfigInput[] memory) {
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

  function _getEmissionsPerAsset() internal returns (EmissionPerAsset[] memory) {
    EmissionPerAsset[] memory emissionsPerAsset = new EmissionPerAsset[](7);

    emissionsPerAsset[0] = EmissionPerAsset({
      asset: AaveV3MetisAssets.Metis_A_TOKEN,
      emission: TOTAL_DISTRIBUTION * 5 / 100 // 5% of the distribution
    });
    emissionsPerAsset[1] = EmissionPerAsset({
      asset: AaveV3MetisAssets.WETH_A_TOKEN,
      emission: TOTAL_DISTRIBUTION * 10 / 100 // 10% of the distribution
    });
    emissionsPerAsset[2] = EmissionPerAsset({
      asset: AaveV3MetisAssets.mDAI_V_TOKEN,
      emission: TOTAL_DISTRIBUTION * 15 / 100 // 15% of the distribution
    });
    emissionsPerAsset[3] = EmissionPerAsset({
      asset: AaveV3MetisAssets.Metis_V_TOKEN,
      emission: TOTAL_DISTRIBUTION * 5 / 100 // 5% of the distribution
    });
    emissionsPerAsset[4] = EmissionPerAsset({
      asset: AaveV3MetisAssets.mUSDC_V_TOKEN,
      emission: TOTAL_DISTRIBUTION * 275 / 1000 // 27.5% of the distribution
    });
    emissionsPerAsset[5] = EmissionPerAsset({
      asset: AaveV3MetisAssets.mUSDT_V_TOKEN,
      emission: TOTAL_DISTRIBUTION * 275 / 1000 // 27.5% of the distribution
    });
    emissionsPerAsset[6] = EmissionPerAsset({
      asset: AaveV3MetisAssets.WETH_V_TOKEN,
      emission: TOTAL_DISTRIBUTION * 10 / 100 // 10% of the distribution
    });

    uint256 totalDistribution;
    for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
      totalDistribution += emissionsPerAsset[i].emission;
    }
    assertApproxEqAbs(totalDistribution, TOTAL_DISTRIBUTION, 0.5 ether, 'INVALID_SUM_OF_EMISSIONS');

    return emissionsPerAsset;
  }

  function _toUint88(uint256 value) internal pure returns (uint88) {
    require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
    return uint88(value);
  }
}
