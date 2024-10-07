// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAaveIncentivesController {
  function claimRewards(
    address[] calldata assets,
    uint256 amount,
    address to,
    address reward
  ) external returns (uint256);

  function getTransferStrategy(address reward) external view returns (address);
}
