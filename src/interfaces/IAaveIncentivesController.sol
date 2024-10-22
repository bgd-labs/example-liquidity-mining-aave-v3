// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveIncentivesController {
  function getUserRewards(
    address[] calldata assets,
    address user,
    address reward
  ) external returns (uint256);

  function getDistributionEnd(
    address assets,
    address reward
  ) external view returns (uint256);

  function getEmissionManager() external view returns (address);

  function getRewardsData(
    address asset,
    address reward
  ) external view returns (
      uint256,
      uint256,
      uint256,
      uint256
  );

  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to,
    address reward
  ) external returns (uint256);
}
