// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {IScaledBalanceToken} from 'aave-v3-core/contracts/interfaces/IScaledBalanceToken.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../../src/interfaces/IEmissionManager.sol';

abstract contract LMSetupBaseTest is Test {
  /// @dev Used to simplify the definition of a program of emissions
  /// @param asset The asset on which to put reward on, usually Aave aTokens or vTokens (variable debt tokens)
  /// @param emission Total emission of a `reward` token during the whole distribution duration defined
  /// E.g. With an emission of 10_000 MATICX tokens during 1 month, an emission of 50% for variableDebtPolWMATIC would be
  /// 10_000 * 1e18 * 50% / 30 days in seconds = 1_000 * 1e18 / 2_592_000 = ~ 0.0003858 * 1e18 MATICX per second
  struct EmissionPerAsset {
    address asset;
    uint256 emission;
  }

  function test_validateLMParams() public {
    RewardsDataTypes.RewardsConfigInput[] memory rewardConfigs = _getAssetConfigs();

    for (uint i = 0; i < rewardConfigs.length; i++) {
      assertGt(rewardConfigs[i].distributionEnd, block.timestamp);

      _validateIndexDoesNotOverflow(rewardConfigs[i]);
      _validateIndexNotZero(rewardConfigs[i]);
    }
  }

  function _getEmissionsPerAsset() virtual internal pure returns (EmissionPerAsset[] memory);

  function _getAssetConfigs() virtual internal view returns (RewardsDataTypes.RewardsConfigInput[] memory);

  function _validateIndexDoesNotOverflow(RewardsDataTypes.RewardsConfigInput memory rewardConfig) internal {
    uint256 maxTimeDelta = block.timestamp;
    uint256 totalSupplyLowerBound = 100 * (10 ** IERC20(rewardConfig.asset).decimals()); // 100 asset unit
    uint256 index = _calcualteAssetIndex(rewardConfig.asset, maxTimeDelta, rewardConfig.emissionPerSecond, totalSupplyLowerBound);

    assertLt(index, type(uint104).max / 1_000);
  }

  function _validateIndexNotZero(RewardsDataTypes.RewardsConfigInput memory rewardConfig) internal {
    uint256 timeDeltaLowerBound = 1;
    uint256 maxTotalSupply = IScaledBalanceToken(rewardConfig.asset).scaledTotalSupply() * 1_000; // 1000 times the current totalSupply
    uint256 index = _calcualteAssetIndex(rewardConfig.asset, timeDeltaLowerBound, rewardConfig.emissionPerSecond, maxTotalSupply);

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
}
