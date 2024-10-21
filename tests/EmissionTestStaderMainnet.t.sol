// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';

import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';
import 'forge-std/console.sol';

contract EmissionTestStaderMainnet is BaseTest {
  // @dev Used to simplify the definition of a program of emissions
  //  asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  //  emission Total emission of a `reward` token during the whole distribution duration defined
  // E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  // 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second

  // SD is not part of the onboarded assets on Aave, we can't call lib so we import it here

  address constant SD = 0x30D20208d987713f46DFD34EF128Bb16C404D10f;
  address constant a_ETHx = AaveV3EthereumAssets.ETHx_A_TOKEN;

  struct NewDistributionEndPerAsset {
    address asset;
    address reward;
    uint32 newDistributionEnd;
  }

  address constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd; // ACI
  address constant REWARD_ASSET = SD;
  uint256 constant TOTAL_DISTRIBUTION = 25_000 ether; 
  uint88 constant NEW_DURATION_DISTRIBUTION = 30 days; // 2 weeks
  /// @dev already deployed and configured for the both the SD asset and the 0xac140648435d03f784879cd789130F22Ef588Fcd EMISSION_ADMIN
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0x0605a898535E9116Ff820347c536E3442F216Eb8);

  address a_ETHx_WHALE = 0x22a65f880Bf67b6B62Aa6cCa4f28B6Ee085EE6BA;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 21016516);
  }

  function test_extend() public {
    vm.startPrank(EMISSION_ADMIN);

    NewDistributionEndPerAsset memory newDistributionEndPerAsset = _getNewDistributionEnd();
    IEmissionManager(AaveV3Ethereum.EMISSION_MANAGER).setDistributionEnd(
      newDistributionEndPerAsset.asset,
      newDistributionEndPerAsset.reward,
      newDistributionEndPerAsset.newDistributionEnd
    );
    bytes memory distributionEnd = abi.encodeWithSelector(
      IEmissionManager.setDistributionEnd.selector,
      newDistributionEndPerAsset.asset,
      newDistributionEndPerAsset.reward,
      newDistributionEndPerAsset.newDistributionEnd
    );
    emit log_named_bytes('newDistributionEnd', distributionEnd);

    emit log_named_address('token', REWARD_ASSET);
    bytes memory approval = abi.encodeWithSelector(
      IERC20(REWARD_ASSET).approve.selector,
      TRANSFER_STRATEGY,
      type(uint256).max
    );
    emit log_named_bytes('approval', approval);

    vm.stopPrank();

    _testClaimRewardsForWhale(a_ETHx_WHALE, a_ETHx, 0.255455 ether); //25% of the supply
  }

  function _testClaimRewardsForWhale(
    address whale,
    address asset,
    uint256 expectedRewardPercentage
  ) internal {
    vm.startPrank(whale);

    address[] memory assets = new address[](1);
    assets[0] = asset;

    uint256 unclaimedRewards = IAaveIncentivesController(
      AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER
    ).getUserRewards(assets, whale, REWARD_ASSET);

    vm.warp(block.timestamp + NEW_DURATION_DISTRIBUTION);

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(whale);

    IAaveIncentivesController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      whale,
      REWARD_ASSET
    );

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(whale);

    uint256 rewardsClaimed = balanceAfter - balanceBefore;
    uint256 rewardsExpected = (TOTAL_DISTRIBUTION * expectedRewardPercentage) / 10 ** 18;

    emit log_named_uint('unclaimedRewards', unclaimedRewards);
    emit log_named_uint('rewardsClaimed', rewardsClaimed);
    emit log_named_uint('rewardsClaimed - unclaimedRewards', rewardsClaimed - unclaimedRewards);
    emit log_named_uint('rewardsExpected', rewardsExpected);

    // uint256 deviationAccepted = 10 ** 16; // 1% of deviation accepted
    uint256 deviationAccepted = 10 ** 16; // 1% of deviation accepted
    assertApproxEqRel(
      rewardsClaimed - unclaimedRewards,
      rewardsExpected,
      deviationAccepted,
      'Invalid delta on claimed rewards'
    );

    vm.stopPrank();
  }

  function _getNewDistributionEnd() internal view returns (NewDistributionEndPerAsset memory) {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset;

    newDistributionEndPerAsset.asset = a_ETHx;
    newDistributionEndPerAsset.reward = REWARD_ASSET;
    newDistributionEndPerAsset.newDistributionEnd = _toUint32(
      block.timestamp + NEW_DURATION_DISTRIBUTION
    );

    return newDistributionEndPerAsset;
  }

  function _toUint88(uint256 value) internal pure returns (uint88) {
    require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
    return uint88(value);
  }
  
  function _toUint32(uint256 value) internal pure returns (uint32) {
    require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
    return uint32(value);
  }
}
