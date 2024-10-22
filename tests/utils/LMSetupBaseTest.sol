// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {IScaledBalanceToken} from 'aave-v3-origin/contracts/interfaces/IScaledBalanceToken.sol';
import {ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../../src/interfaces/IEmissionManager.sol';
import {LMBaseTest} from '../utils/LMBaseTest.sol';

abstract contract LMSetupBaseTest is LMBaseTest {
  function test_validateLMParams() public {
    RewardsDataTypes.RewardsConfigInput[] memory rewardConfigs = _getAssetConfigs();

    for (uint i = 0; i < rewardConfigs.length; i++) {
      assertGt(rewardConfigs[i].distributionEnd, block.timestamp);

      _validateIndexDoesNotOverflow(rewardConfigs[i]);
      _validateIndexNotZero(rewardConfigs[i]);
    }
  }

  function test_transferStrategyHasSufficientAllowance() public {
    address rewardsVault = this.TRANSFER_STRATEGY().getRewardsVault();
    uint256 allowance = IERC20(this.REWARD_ASSET()).allowance(
      rewardsVault,
      address(this.TRANSFER_STRATEGY())
    );

    assertGe(allowance, this.TOTAL_DISTRIBUTION());
  }

  function test_rewardsVaultHasSufficientBalance() public {
    address rewardsVault = this.TRANSFER_STRATEGY().getRewardsVault();
    uint256 balance = IERC20(this.REWARD_ASSET()).balanceOf(rewardsVault);

    assertGe(balance, this.TOTAL_DISTRIBUTION());
  }

  function test_rewardOracleSanity() public {
    int256 rewardPrice = this.REWARD_ORACLE().latestAnswer();
    assertGt(uint256(rewardPrice), 0);
  }

  function _validateIndexDoesNotOverflow(
    RewardsDataTypes.RewardsConfigInput memory rewardConfig
  ) internal {
    uint256 maxTimeDelta = block.timestamp;
    uint256 totalSupplyLowerBound = 100 * (10 ** IERC20(rewardConfig.asset).decimals()); // 100 asset unit
    uint256 index = _calcualteAssetIndex(
      rewardConfig.asset,
      maxTimeDelta,
      rewardConfig.emissionPerSecond,
      totalSupplyLowerBound
    );

    assertLt(index, type(uint104).max / 1_000);
  }

  function _validateIndexNotZero(RewardsDataTypes.RewardsConfigInput memory rewardConfig) internal {
    uint256 timeDeltaLowerBound = 1;
    uint256 maxTotalSupply = IScaledBalanceToken(rewardConfig.asset).scaledTotalSupply() * 1_000; // 1000 times the current totalSupply
    uint256 index = _calcualteAssetIndex(
      rewardConfig.asset,
      timeDeltaLowerBound,
      rewardConfig.emissionPerSecond,
      maxTotalSupply
    );

    assertGt(index, 100);
  }

  function _getEmissionsPerAsset() internal pure virtual returns (EmissionPerAsset[] memory);

  function _getAssetConfigs()
    internal
    view
    virtual
    returns (RewardsDataTypes.RewardsConfigInput[] memory);

  function TRANSFER_STRATEGY() external virtual returns (ITransferStrategyBase);

  function REWARD_ORACLE() external virtual returns (IEACAggregatorProxy);

  function TOTAL_DISTRIBUTION() external virtual returns (uint256);
}
