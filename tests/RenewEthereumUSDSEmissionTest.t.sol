// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';

import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';

contract RenewEthereumUSDSEmissionTest is BaseTest {
  /// @dev Used to simplify the configuration of new emissions per second after the emissions program has been created
  /// @param asset The asset for which new emissions per second needs to be configured
  /// @param rewards The rewards for which new emissions per second needs to be configured
  /// @param newEmissionsPerSecond The new emissions per second of the `reward` tokens
  struct NewEmissionPerAsset {
    address asset;
    address[] rewards;
    uint88[] newEmissionsPerSecond;
  }

  /// @dev Used to simplify the configuration of new distribution end after the emissions program has been created
  /// @param asset The asset for which new distribution end needs to be configured
  /// @param reward The reward for which new distribution end needs to be configured
  /// @param newDistributionEnd The new distribution end of the asset and reward
  struct NewDistributionEndPerAsset {
    address asset;
    address reward;
    uint32 newDistributionEnd;
  }

  address constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd; // aci.eth
  address constant REWARD_ASSET = AaveV3EthereumAssets.USDS_A_TOKEN;
  address constant ASSET = AaveV3EthereumAssets.USDS_A_TOKEN;
  IEACAggregatorProxy constant REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3EthereumAssets.USDS_ORACLE);

  /// @dev already deployed and configured for aUSDS asset
  /// EMISSION_ADMIN
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0x4fDB95C607EDe09A548F60685b56C034992B194a);

  uint256 constant TOTAL_DISTRIBUTION = 100_000 ether; // 100 aUSDS
  uint88 constant NEW_DURATION_DISTRIBUTION = 1 weeks; // 1 week

  address WHALE_1 = 0xa0037d4494E9341826c23B970D4C40Fe3D02F4Fc; // 0.5% of the supply

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 21029291);
  }

  function test_extend() public {
    vm.startPrank(EMISSION_ADMIN);

    emit log_named_address('emissionManager', AaveV3Ethereum.EMISSION_MANAGER);

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

    // emit log_named_address('token', REWARD_ASSET);
    // bytes memory approval = abi.encodeWithSelector(
    //   IERC20(REWARD_ASSET).approve.selector,
    //   TRANSFER_STRATEGY,
    //   type(uint256).max
    // );
    // emit log_named_bytes('approval', approval);

    vm.stopPrank();

    _testClaimRewardsForWhale(WHALE_1, ASSET, 0.005013 ether); // 5%
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
    ).getUserRewards(assets, whale, ASSET);

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(whale);

    vm.warp(block.timestamp + NEW_DURATION_DISTRIBUTION);

    IAaveIncentivesController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      whale,
      REWARD_ASSET
    );

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(whale);

    uint256 rewardsClaimed = balanceAfter - balanceBefore;
    uint256 rewardsExpected = (TOTAL_DISTRIBUTION * expectedRewardPercentage) / 10 ** 18;

    // emit log_named_uint('unclaimedRewards', unclaimedRewards);
    // emit log_named_uint('rewardsClaimed', rewardsClaimed);
    // emit log_named_uint('rewardsClaimed - unclaimedRewards', rewardsClaimed - unclaimedRewards);
    // emit log_named_uint('rewardsExpected', rewardsExpected);

    uint256 deviationAccepted = 0.05 ether; // 5% of deviation accepted
    assertApproxEqRel(
      rewardsClaimed - unclaimedRewards,
      rewardsExpected,
      deviationAccepted,
      'Invalid delta on claimed rewards'
    );

    vm.stopPrank();
  }

  function _getNewEmissionPerSecond() internal pure returns (NewEmissionPerAsset memory) {
    NewEmissionPerAsset memory newEmissionPerAsset;

    address[] memory rewards = new address[](1);
    rewards[0] = REWARD_ASSET;
    uint88[] memory newEmissionsPerSecond = new uint88[](1);
    newEmissionsPerSecond[0] = _toUint88(TOTAL_DISTRIBUTION / NEW_DURATION_DISTRIBUTION);

    newEmissionPerAsset.asset = ASSET;
    newEmissionPerAsset.rewards = rewards;
    newEmissionPerAsset.newEmissionsPerSecond = newEmissionsPerSecond;

    return newEmissionPerAsset;
  }

  function _getNewDistributionEnd() internal view returns (NewDistributionEndPerAsset memory) {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset;

    newDistributionEndPerAsset.asset = ASSET;
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
