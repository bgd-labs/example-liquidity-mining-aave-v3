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

  address constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd; // aci
  address constant REWARD_ASSET = AaveV3EthereumAssets.USDS_A_TOKEN;
  IEACAggregatorProxy constant REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3EthereumAssets.USDS_ORACLE);

  /// @dev already deployed and configured for the both the MATICX asset and the 0x0c54a0BCCF5079478a144dBae1AFcb4FEdf7b263
  /// EMISSION_ADMIN
  ITransferStrategyBase constant TRANSFER_STRATEGY =
    ITransferStrategyBase(0x4fDB95C607EDe09A548F60685b56C034992B194a);

  uint256 constant TOTAL_DISTRIBUTION = 50_000 ether; // 10'000 MATICX/month, 6 months
  uint88 constant NEW_DURATION_DISTRIBUTION_END = 7 days;

  address asUSDS_WHALE = 0x230F86Fa0357fEB4e9F5043986383CFfb3DAB2bc;
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('mainnet'), 20966533);
  }

  function test_extend() public {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset = _getNewDistributionEnd();
    vm.startPrank(EMISSION_ADMIN);
    uint256 leftover = IERC20(REWARD_ASSET).allowance(EMISSION_ADMIN, address(TRANSFER_STRATEGY));
    IERC20(REWARD_ASSET).approve(address(TRANSFER_STRATEGY), leftover + TOTAL_DISTRIBUTION);
    IEmissionManager(AaveV3Ethereum.EMISSION_MANAGER).setDistributionEnd(
      newDistributionEndPerAsset.asset,
      newDistributionEndPerAsset.reward,
      newDistributionEndPerAsset.newDistributionEnd
    );
    emit log_named_bytes(
      'calldata to submit from Gnosis Safe',
      abi.encodeWithSelector(
      	IEmissionManager.setDistributionEnd.selector,
        newDistributionEndPerAsset.asset,
        newDistributionEndPerAsset.reward,
        newDistributionEndPerAsset.newDistributionEnd
      )
    );

    vm.stopPrank();

    //vm.startPrank(asUSDS_WHALE);
    //IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, 50_000 ether);

    //vm.stopPrank();
    _testClaimRewardsForWhale(asUSDS_WHALE, AaveV3EthereumAssets.USDS_A_TOKEN, leftover + TOTAL_DISTRIBUTION);
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

    IAaveIncentivesController(AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER).claimRewards(
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
