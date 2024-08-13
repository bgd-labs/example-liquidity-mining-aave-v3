// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Arbitrum, AaveV3ArbitrumAssets} from 'aave-address-book/AaveV3Arbitrum.sol'; // TODO: import Lido when lib is updated
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';
import 'forge-std/console.sol';

contract EmissionTestARBGHOLMETH is BaseTest {
  // @dev Used to simplify the definition of a program of emissions
  //  asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  //  emission Total emission of a `reward` token during the whole distribution duration defined
  // E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  // 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second

  address constant ArbGHO_A_Token = 0xeBe517846d0F36eCEd99C735cbF6131e1fEB775D; // TODO: hardcoded for now will use lib when address book is updated
  address constant ARB_ORACLE = 0xb2A824043730FE05F3DA2efaFa1CBbe83fa548D6;
  address constant ARB = 0x912CE59144191C1204E64559FE8253a0e49E6548;

  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  address constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd; // ACI
  address constant REWARD_ASSET = ARB;

  IEACAggregatorProxy constant REWARD_ORACLE = IEACAggregatorProxy(ARB_ORACLE);

  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0xbe20E31e8fAf90568ca4D10E25efaD6da34EBC3A); // new deployed strategy

  uint256 constant TOTAL_DISTRIBUTION = 5200 ether; // 5200 ARB/14 Days
  uint88 constant DURATION_DISTRIBUTION = 14 days;

  // Not needed as ACI is first LP in market
  address constant ARB_WHALE = 0xF3FC178157fb3c87548bAA86F9d24BA38E649B58;
  address constant GHO_A_TOKEN_WHALE = 0x49a1efFce91d603A9A5aE8F0f676f7EBcD2a6029; // Large aToken Holder

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('arbitrum'), 242383736); // change this when ready
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

    IEmissionManager(AaveV3Arbitrum.EMISSION_MANAGER).configureAssets(_getAssetConfigs());

    emit log_named_bytes(
      'calldata to submit from Gnosis Safe',
      abi.encodeWithSelector(
        IEmissionManager(AaveV3Arbitrum.EMISSION_MANAGER).configureAssets.selector,
        _getAssetConfigs()
      )
    );

    vm.stopPrank();

    vm.startPrank(ARB_WHALE);
    IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, TOTAL_DISTRIBUTION);
    vm.stopPrank();

    _testClaimRewardsForWhale(GHO_A_TOKEN_WHALE, ARB, 2_600 ether);
  }
  // Not needed for initial LM

  // function test_extendDistributionEnd() public {
  //   // Initial setup
  //   test_activation();

  //   // Calculate new distribution end (14 days after the initial end)
  //   uint32 newDistributionEnd = uint32(block.timestamp + 14 days);

  //   vm.startPrank(EMISSION_ADMIN);

  //   // Call setDistributionEnd with single values instead of arrays
  //   IEmissionManager(AaveV3Arbitrum.EMISSION_MANAGER).setDistributionEnd(
  //     ARB,
  //     REWARD_ASSET,
  //     newDistributionEnd
  //   );

  //   emit log_named_bytes(
  //     'calldata to execute tx on EMISSION_MANAGER to extend the distribution end from the emissions admin (safe)',
  //     abi.encodeWithSelector(
  //       IEmissionManager.setDistributionEnd.selector,
  //       ARB,
  //       REWARD_ASSET,
  //       newDistributionEnd
  //     )
  //   );

  //   vm.stopPrank();

  //   // Test claiming rewards after extension
  //   vm.warp(block.timestamp + 14 days); // 14 days initial

  //   _testClaimRewardsForWhale(GHO_A_TOKEN_WHALE, ARB, 0.2 ether);
  // }

  function _testClaimRewardsForWhale(
    address whale,
    address asset,
    uint256 expectedReward
  ) internal {
    vm.startPrank(whale);

    vm.warp(block.timestamp + 14 days);

    address[] memory assets = new address[](1);
    assets[0] = asset;

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
    emissionsPerAsset[0] = EmissionPerAsset({asset: ARB, emission: 5200 ether});

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
