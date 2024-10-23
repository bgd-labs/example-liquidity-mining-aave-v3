// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Avalanche, AaveV3AvalancheAssets} from 'aave-address-book/AaveV3Avalanche.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';
import 'forge-std/console.sol';

contract EmissionTestsAVAXLMAvaxExtend is BaseTest {
  // @dev Used to simplify the definition of a program of emissions
  //  asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  //  emission Total emission of a `reward` token during the whole distribution duration defined
  // E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  // 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second

  address constant sAVAX = AaveV3AvalancheAssets.sAVAX_UNDERLYING;
  address constant sAVAX_ORACLE = AaveV3AvalancheAssets.sAVAX_ORACLE;

  address constant BTCb_A_TOKEN = AaveV3AvalancheAssets.BTCb_A_TOKEN;
  address constant WAVAX_V_TOKEN = AaveV3AvalancheAssets.WAVAX_V_TOKEN;
  address constant USDC_A_TOKEN = AaveV3AvalancheAssets.USDC_A_TOKEN;
  address constant USDC_V_TOKEN = AaveV3AvalancheAssets.USDC_V_TOKEN;
  address constant sAVAX_A_TOKEN = AaveV3AvalancheAssets.sAVAX_A_TOKEN;
  address constant USDt_A_TOKEN = AaveV3AvalancheAssets.USDt_A_TOKEN;

  struct EmissionPerAsset {
    address asset;
    bytes data;
  }

  address constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd; // ACI
  address constant REWARD_ASSET = sAVAX;

  IEACAggregatorProxy constant REWARD_ORACLE = IEACAggregatorProxy(sAVAX_ORACLE);

  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0xF585F8cf39C1ef5353326e0352B9E237f9A52587); // new deployed strategy

  uint256 constant TOTAL_DISTRIBUTION = 11_102 ether; // 12'600 wAVAX/15 Days
  uint88 constant DURATION_DISTRIBUTION = 14 days;

  address BTCb_A_Token_WHALE = 0xD48573cDA0fed7144f2455c5270FFa16Be389d04;
  address WAVAX_V_TOKEN_WHALE = 0xD48573cDA0fed7144f2455c5270FFa16Be389d04;
  address USDC_A_TOKEN_WHALE = 0x59B59F17F211dd6C9A4B796BFf5227a5a9A3ae9f;
  address USDC_V_TOKEN_WHALE = 0x50B1Ba98Cf117c9682048D56628B294ebbAA4ec2;
  address sAVAX_A_TOKEN_WHALE = 0x65ec90d241C22450E3Bccd4723cD6A135A794A5A;
  address USDt_A_TOKEN_WHALE = 0x43B87443CC4a6dd2a8b8801D26D1641Bb04060C8;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('avalanche'), 52129521);
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

    EmissionPerAsset[] memory newDistributionEnds = _getDistributionEnds();

    for (uint256 i = 0; i < newDistributionEnds.length; i++) {
      emit log_named_address('Asset: ', newDistributionEnds[i].asset);
      emit log_named_bytes('newDistributionEnds calldata: ', newDistributionEnds[i].data);
    }

    // vm.stopPrank();
    //vm.startPrank(wAVAX_WHALE);
    //IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, TOTAL_DISTRIBUTION);
    //vm.stopPrank();

    _testClaimRewardsForWhale(BTCb_A_Token_WHALE, BTCb_A_TOKEN, 2 * 1_708 ether);
    _testClaimRewardsForWhale(WAVAX_V_TOKEN_WHALE, WAVAX_V_TOKEN, 2 * 427 ether);
    _testClaimRewardsForWhale(USDC_A_TOKEN_WHALE, USDC_A_TOKEN, 2 * 1_708 ether);
    _testClaimRewardsForWhale(USDC_V_TOKEN_WHALE, USDC_V_TOKEN, 2 * 427 ether);
    _testClaimRewardsForWhale(sAVAX_A_TOKEN_WHALE, sAVAX_A_TOKEN, 2 * 427 ether);
    _testClaimRewardsForWhale(USDt_A_TOKEN_WHALE, USDt_A_TOKEN, 2 * 854 ether);
  }

  function _testClaimRewardsForWhale(
    address whale,
    address asset,
    uint256 expectedReward
  ) internal {
    vm.startPrank(whale);

    vm.warp(block.timestamp + 15 days);

    address[] memory assets = new address[](1);
    assets[0] = asset;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(whale);

    IAaveIncentivesController(AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
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

  function _getDistributionEnds() internal returns (EmissionPerAsset[] memory) {
    uint32 distributionEnd = uint32(block.timestamp + DURATION_DISTRIBUTION);

    address[] memory assets = new address[](6);
    assets[0] = BTCb_A_TOKEN;
    assets[1] = WAVAX_V_TOKEN;
    assets[2] = USDC_A_TOKEN;
    assets[3] = USDC_V_TOKEN;
    assets[4] = sAVAX_A_TOKEN;
    assets[5] = USDt_A_TOKEN;

    EmissionPerAsset[] memory newDistributionEnds = new EmissionPerAsset[](assets.length);
    for (uint256 i = 0; i < assets.length; i++) {
      IEmissionManager(AaveV3Avalanche.EMISSION_MANAGER).setDistributionEnd(
        assets[i],
        REWARD_ASSET,
        distributionEnd
      );
      bytes memory data = abi.encodeWithSelector(
        IEmissionManager.setDistributionEnd.selector,
        assets[i],
        REWARD_ASSET,
        distributionEnd
      );
      EmissionPerAsset memory emissionPerAsset = EmissionPerAsset(assets[i], data);
      newDistributionEnds[i] = emissionPerAsset;
    }

    return newDistributionEnds;
  }

  function _toUint88(uint256 value) internal pure returns (uint88) {
    require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
    return uint88(value);
  }
}
