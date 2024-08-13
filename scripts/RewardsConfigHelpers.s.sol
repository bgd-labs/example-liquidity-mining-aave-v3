// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {PullRewardsTransferStrategy} from 'aave-v3-periphery/contracts/rewards/transfer-strategies/PullRewardsTransferStrategy.sol';
import {AaveV3Polygon} from 'aave-address-book/AaveV3Polygon.sol';
import {AaveV3Ethereum} from 'aave-address-book/AaveV3Ethereum.sol';
import {AaveV3Avalanche} from 'aave-address-book/AaveV3Avalanche.sol';
import {AaveV3Arbitrum} from 'aave-address-book/AaveV3Arbitrum.sol';

contract SDDeployTransferStrategy is Script {
  address internal constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd;
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

contract SDMainnetDeployTransferStrategy is Script {
  address internal constant REWARDS_VAULT = EMISSION_ADMIN;
  address internal constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd;

  function run() external {
    vm.startBroadcast();
    new PullRewardsTransferStrategy(
      AaveV3Ethereum.DEFAULT_INCENTIVES_CONTROLLER,
      EMISSION_ADMIN,
      REWARDS_VAULT
    );
    vm.stopBroadcast();
  }
}

contract AVAXDeployTransferStrategy is Script {
  address internal constant REWARDS_VAULT = EMISSION_ADMIN;
  address internal constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd;

  function run() external {
    vm.startBroadcast();
    new PullRewardsTransferStrategy(
      AaveV3Avalanche.DEFAULT_INCENTIVES_CONTROLLER,
      EMISSION_ADMIN,
      REWARDS_VAULT
    );
    vm.stopBroadcast();
  }
}

contract ARBDeployTransferStrategy is Script {
  address internal constant REWARDS_VAULT = EMISSION_ADMIN;
  address internal constant EMISSION_ADMIN = 0xac140648435d03f784879cd789130F22Ef588Fcd;

  function run() external {
    vm.startBroadcast();
    new PullRewardsTransferStrategy(
      AaveV3Arbitrum.DEFAULT_INCENTIVES_CONTROLLER,
      EMISSION_ADMIN,
      REWARDS_VAULT
    );
    vm.stopBroadcast();
  }
}
