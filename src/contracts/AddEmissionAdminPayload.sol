// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IEmissionManager} from '../interfaces/IEmissionManager.sol';
import {IProposalGenericExecutor} from '../interfaces/IProposalGenericExecutor.sol';

/**
 * @title AddEmissionAdminPayload
 * @author BGD Labs
 * @dev Generic proposal to be executed via cross-chain governance.
 * Once executed this payload would add an EMISSION_ADMIN for a REWARD token on the specified EMISSION_MANAGER.
 */
contract AddEmissionAdminPayload is IProposalGenericExecutor {
  IEmissionManager public immutable EMISSION_MANAGER;

  address public immutable REWARD;

  address public immutable EMISSION_ADMIN;

  constructor(IEmissionManager emissionManager, address reward, address emissionAdmin) {
    EMISSION_MANAGER = emissionManager;
    REWARD = reward;
    EMISSION_ADMIN = emissionAdmin;
  }

  function execute() public {
    EMISSION_MANAGER.setEmissionAdmin(REWARD, EMISSION_ADMIN);
  }
}
