// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Ethereum, AaveV3EthereumAssets} from 'aave-address-book/AaveV3Ethereum.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';

import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {BaseTest} from './utils/BaseTest.sol';

contract EmissionTestaUSDSEthereum is BaseTest {
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
  IEACAggregatorProxy constant REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3EthereumAssets.USDS_ORACLE);

  /// @dev already deployed and configured for aUSDS asset
  /// EMISSION_ADMIN
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0x4fDB95C607EDe09A548F60685b56C034992B194a);

  uint256 constant TOTAL_DISTRIBUTION = 100_000 ether; // 100_000 aUSDS/week, 6 months
  uint88 constant NEW_DURATION_DISTRIBUTION_END = 7 days;

  address aUSDS_WHALE = 0xF0A9234e0C5F50127B82960BAe21F05f9dD9aaF4;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20970256);
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

    NewEmissionPerAsset memory newEmission = _getNewEmissionPerSecond();
    IEmissionManager(AaveV3Ethereum.EMISSION_MANAGER).setEmissionPerSecond(
      newEmission.asset,
      newEmission.rewards,
      newEmission.newEmissionsPerSecond
    );
    bytes memory emmission = abi.encodeWithSelector(
      IEmissionManager.setEmissionPerSecond.selector,
      newEmission.asset,
      newEmission.rewards,
      newEmission.newEmissionsPerSecond
    );
    emit log_named_bytes('newEmission', emmission);

    bytes memory approval = abi.encodeWithSelector(
      IERC20(REWARD_ASSET).approve.selector,
      TRANSFER_STRATEGY,
      type(uint256).max
    );
    emit log_named_bytes('approval', approval);

    vm.stopPrank();

    uint256 leftover = IERC20(REWARD_ASSET).allowance(EMISSION_ADMIN, address(TRANSFER_STRATEGY));

    // emit log_uint(leftover);

    _testClaimRewardsForWhale(
      aUSDS_WHALE,
      AaveV3EthereumAssets.USDS_A_TOKEN,
      leftover + TOTAL_DISTRIBUTION
    );
  }

  function _testClaimRewardsForWhale(
    address whale,
    address asset,
    uint256 expectedReward
  ) internal {
    vm.startPrank(whale);

    vm.warp(block.timestamp + 7 days);

    address[] memory assets = new address[](1);
    assets[0] = asset;

    uint256 balanceBefore = IERC20(REWARD_ASSET).balanceOf(whale);

    IAaveIncentivesController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
      assets,
      type(uint256).max,
      whale,
      REWARD_ASSET
    );

    uint256 balanceAfter = IERC20(REWARD_ASSET).balanceOf(whale);

    uint256 deviationAccepted = (expectedReward * 10) / 100; // the whale has ~10% of the aUSDC supply

    // emit log_uint(balanceBefore);
    // emit log_uint(balanceAfter);
    // emit log_uint(deviationAccepted);

    assertApproxEqAbs(
      balanceBefore,
      balanceAfter,
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
    newEmissionsPerSecond[0] = _toUint88(TOTAL_DISTRIBUTION / NEW_DURATION_DISTRIBUTION_END);

    newEmissionPerAsset.asset = AaveV3EthereumAssets.USDS_A_TOKEN;
    newEmissionPerAsset.rewards = rewards;
    newEmissionPerAsset.newEmissionsPerSecond = newEmissionsPerSecond;

    return newEmissionPerAsset;
  }

  function _getNewDistributionEnd() internal view returns (NewDistributionEndPerAsset memory) {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset;

    newDistributionEndPerAsset.asset = AaveV3EthereumAssets.USDS_A_TOKEN;
    newDistributionEndPerAsset.reward = REWARD_ASSET;
    newDistributionEndPerAsset.newDistributionEnd = _toUint32(
      block.timestamp + NEW_DURATION_DISTRIBUTION_END
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
