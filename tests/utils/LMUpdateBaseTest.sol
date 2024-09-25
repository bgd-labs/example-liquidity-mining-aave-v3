// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {IScaledBalanceToken} from 'aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol';
import {RewardsDataTypes} from '../../src/interfaces/IEmissionManager.sol';

abstract contract LMUpdateBaseTest is Test {
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

  function _getNewDistributionEnd() internal virtual view returns (NewDistributionEndPerAsset memory);

  function _getNewEmissionPerSecond() internal virtual pure returns (NewEmissionPerAsset memory);

  function test_validateLMParams() public {
    NewDistributionEndPerAsset memory distributionEnds = _getNewDistributionEnd();
    NewEmissionPerAsset memory emissionsPerAsset = _getNewEmissionPerSecond();

    assertGt(distributionEnds.newDistributionEnd, block.timestamp - 1 hours);

    for (uint i = 0; i < emissionsPerAsset.rewards.length; i++) {
      _validateIndexDoesNotOverflow(emissionsPerAsset.asset, emissionsPerAsset.newEmissionsPerSecond[i]);
      _validateIndexNotZero(emissionsPerAsset.asset, emissionsPerAsset.newEmissionsPerSecond[i]);
    }
  }

  function _validateIndexDoesNotOverflow(address asset, uint256 emissionPerSecond) internal {
    uint256 maxTimeDelta = block.timestamp;
    uint256 totalSupplyLowerBound = 100 * (10 ** IERC20(asset).decimals()); // 100 asset unit
    uint256 index = _calcualteAssetIndex(asset, maxTimeDelta, emissionPerSecond, totalSupplyLowerBound);

    assertLt(index, type(uint104).max / 1_000);
  }

  function _validateIndexNotZero(address asset, uint256 emissionPerSecond) internal {
    uint256 timeDeltaLowerBound = 1;
    uint256 maxTotalSupply = IScaledBalanceToken(asset).scaledTotalSupply() * 1_000; // 1000 times the current totalSupply
    uint256 index = _calcualteAssetIndex(asset, timeDeltaLowerBound, emissionPerSecond, maxTotalSupply);

    assertGt(index, 100);
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
}
