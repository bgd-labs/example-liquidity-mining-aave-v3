// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {PullRewardsTransferStrategy} from 'aave-v3-origin/contracts/rewards/transfer-strategies/PullRewardsTransferStrategy.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';

contract SDDeployTransferStrategy is Script {
  address internal constant EMISSION_ADMIN = 0x51358004cFe135E64453d7F6a0dC433CAba09A2a;
  address internal constant REWARDS_VAULT = EMISSION_ADMIN;

  function run() external {
    vm.startBroadcast();
    new PullRewardsTransferStrategy(
      AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER,
      EMISSION_ADMIN,
      REWARDS_VAULT
    );
    vm.stopBroadcast();
  }
}

/// @dev same to be used for MATICX, as they share rewards vault and emission admin
contract STMATICDeployTransferStrategy is Script {
  address internal constant REWARDS_VAULT = EMISSION_ADMIN;
  address internal constant EMISSION_ADMIN = 0x0c54a0BCCF5079478a144dBae1AFcb4FEdf7b263;

  function run() external {
    vm.startBroadcast();
    new PullRewardsTransferStrategy(
      AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER,
      EMISSION_ADMIN,
      REWARDS_VAULT
    );
    vm.stopBroadcast();
  }
}
