// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {IScaledBalanceToken} from 'aave-v3-origin/contracts/interfaces/IScaledBalanceToken.sol';
import {IAaveIncentivesController} from '../../src/interfaces/IAaveIncentivesController.sol';
import {ITransferStrategyBase} from '../../src/interfaces/IEmissionManager.sol';
import {LMBaseTest} from '../utils/LMBaseTest.sol';
import {IEmissionManager} from '../../src/interfaces/IEmissionManager.sol';

abstract contract LMUpdateBaseTest is LMBaseTest {
  function test_setNewEmissionPerSecond() public {
    NewEmissionPerAsset memory newEmissionPerAsset = _getNewEmissionPerSecond();
    vm.startPrank(this.EMISSION_ADMIN());

    // The emission admin can change the emission per second of the reward after the rewards have been configured.
    // Here we change the initial emission per second to the new one.
    IEmissionManager(this.EMISSION_MANAGER()).setEmissionPerSecond(
      newEmissionPerAsset.asset,
      newEmissionPerAsset.rewards,
      newEmissionPerAsset.newEmissionsPerSecond
    );
    emit log_named_bytes(
      'calldata to execute tx on EMISSION_MANAGER to set the new emission per second from the emissions admin (safe)',
      abi.encodeWithSelector(
        IEmissionManager.setEmissionPerSecond.selector,
        newEmissionPerAsset.asset,
        newEmissionPerAsset.rewards,
        newEmissionPerAsset.newEmissionsPerSecond
      )
    );
  }

  function test_setNewDistributionEnd() public {
    NewDistributionEndPerAsset memory newDistributionEndPerAsset = _getNewDistributionEnd();
    vm.startPrank(this.EMISSION_ADMIN());

    IEmissionManager(this.EMISSION_MANAGER()).setDistributionEnd(
      newDistributionEndPerAsset.asset,
      newDistributionEndPerAsset.reward,
      newDistributionEndPerAsset.newDistributionEnd
    );
    emit log_named_bytes(
      'calldata to execute tx on EMISSION_MANAGER to set the new distribution end from the emissions admin (safe)',
      abi.encodeWithSelector(
        IEmissionManager.setDistributionEnd.selector,
        newDistributionEndPerAsset.asset,
        newDistributionEndPerAsset.reward,
        newDistributionEndPerAsset.newDistributionEnd
      )
    );
  }

  function test_transferStrategyHasSufficientAllowance() public {
    address transferStrategy = IAaveIncentivesController(this.DEFAULT_INCENTIVES_CONTROLLER())
      .getTransferStrategy(this.REWARD_ASSET());
    address rewardsVault = ITransferStrategyBase(transferStrategy).getRewardsVault();
    uint256 allowance = IERC20(this.REWARD_ASSET()).allowance(rewardsVault, transferStrategy);

    assertGe(allowance, this.NEW_TOTAL_DISTRIBUTION());
  }

  function test_rewardsVaultHasSufficientBalance() public {
    address transferStrategy = IAaveIncentivesController(this.DEFAULT_INCENTIVES_CONTROLLER())
      .getTransferStrategy(this.REWARD_ASSET());
    address rewardsVault = ITransferStrategyBase(transferStrategy).getRewardsVault();
    uint256 balance = IERC20(this.REWARD_ASSET()).balanceOf(rewardsVault);

    assertGe(balance, this.NEW_TOTAL_DISTRIBUTION());
  }

  function test_validateLMParams() public {
    NewDistributionEndPerAsset memory distributionEnds = _getNewDistributionEnd();
    NewEmissionPerAsset memory emissionsPerAsset = _getNewEmissionPerSecond();

    assertGt(distributionEnds.newDistributionEnd, block.timestamp - 1 hours);

    for (uint i = 0; i < emissionsPerAsset.rewards.length; i++) {
      _validateIndexDoesNotOverflow(
        emissionsPerAsset.asset,
        emissionsPerAsset.newEmissionsPerSecond[i]
      );
      _validateIndexNotZero(emissionsPerAsset.asset, emissionsPerAsset.newEmissionsPerSecond[i]);
    }
  }

  function _validateIndexDoesNotOverflow(address asset, uint256 emissionPerSecond) internal {
    uint256 maxTimeDelta = block.timestamp;
    uint256 totalSupplyLowerBound = 100 * (10 ** IERC20(asset).decimals()); // 100 asset unit
    uint256 index = _calcualteAssetIndex(
      asset,
      maxTimeDelta,
      emissionPerSecond,
      totalSupplyLowerBound
    );

    assertLt(index, type(uint104).max / 1_000);
  }

  function _validateIndexNotZero(address asset, uint256 emissionPerSecond) internal {
    uint256 timeDeltaLowerBound = 1;
    uint256 maxTotalSupply = IScaledBalanceToken(asset).scaledTotalSupply() * 1_000; // 1000 times the current totalSupply
    uint256 index = _calcualteAssetIndex(
      asset,
      timeDeltaLowerBound,
      emissionPerSecond,
      maxTotalSupply
    );

    assertGt(index, 100);
  }

  function _getNewDistributionEnd()
    internal
    view
    virtual
    returns (NewDistributionEndPerAsset memory);

  function _getNewEmissionPerSecond() internal pure virtual returns (NewEmissionPerAsset memory);

  function NEW_TOTAL_DISTRIBUTION() external virtual returns (uint256);

  function EMISSION_ADMIN() external virtual returns (address);

  function EMISSION_MANAGER() external virtual returns (address);
}
