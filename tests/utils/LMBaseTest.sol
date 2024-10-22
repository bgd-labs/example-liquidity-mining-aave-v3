// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {IAaveIncentivesController} from '../../src/interfaces/IAaveIncentivesController.sol';

abstract contract LMBaseTest is Test {
  /// @dev Used to simplify the definition of a program of emissions
  /// @param asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  /// @param emission Total emission of a `reward` token during the whole distribution duration defined
  /// E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  /// 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second
  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

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

  function _testClaimRewardsForWhale(
    address whale,
    address asset,
    uint256 timeAfterToClaim,
    uint256 expectedReward
  ) internal {
    vm.startPrank(whale);
    uint256 initialTimestamp = block.timestamp;
    address[] memory assets = new address[](1);
    assets[0] = asset;

    // claim previous unclaimed rewards
    IAaveIncentivesController(this.DEFAULT_INCENTIVES_CONTROLLER()).claimRewards(
      assets,
      type(uint256).max,
      whale,
      this.REWARD_ASSET()
    );
    uint256 balanceBefore = IERC20(this.REWARD_ASSET()).balanceOf(whale);

    // rewards claimed after 5 mins should not be 0
    vm.warp(block.timestamp + 5 minutes);
    uint256 rewardsAfterFewMins = IAaveIncentivesController(this.DEFAULT_INCENTIVES_CONTROLLER())
      .claimRewards(assets, type(uint256).max, whale, this.REWARD_ASSET());
    assertGt(rewardsAfterFewMins, 0);

    vm.warp(block.timestamp + timeAfterToClaim);
    IAaveIncentivesController(this.DEFAULT_INCENTIVES_CONTROLLER()).claimRewards(
      assets,
      type(uint256).max,
      whale,
      this.REWARD_ASSET()
    );
    uint256 balanceAfter = IERC20(this.REWARD_ASSET()).balanceOf(whale);

    assertApproxEqRel(
      balanceAfter - balanceBefore,
      expectedReward, // Approx estimated rewards with current emissions
      0.05e18, // 5% delta
      'Invalid delta on claimed rewards'
    );

    vm.stopPrank();
    vm.warp(initialTimestamp);
  }

  function _calcualteAssetIndex(
    address asset,
    uint256 timeDelta,
    uint256 emissionPerSecond,
    uint256 assetTotalSupply
  ) internal view returns (uint256) {
    uint256 firstTerm = emissionPerSecond * timeDelta * (10 ** IERC20(asset).decimals());
    assembly {
      firstTerm := div(firstTerm, assetTotalSupply)
    }
    return firstTerm;
  }

  function _toUint88(uint256 value) internal pure returns (uint88) {
    require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
    return uint88(value);
  }

  function _toUint32(uint256 value) internal pure returns (uint32) {
    require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
    return uint32(value);
  }

  function REWARD_ASSET() external virtual returns (address);

  function DEFAULT_INCENTIVES_CONTROLLER() external virtual returns (address);
}
