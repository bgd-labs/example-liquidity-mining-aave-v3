// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {LMSetupBaseTest} from './utils/LMSetupBaseTest.sol';

contract EmissionTestMATICXPolygon is LMSetupBaseTest {
  address public constant override DEFAULT_INCENTIVES_CONTROLLER =
    AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER;
  address public constant override REWARD_ASSET = AaveV3PolygonAssets.MaticX_UNDERLYING;
  uint256 public constant override TOTAL_DISTRIBUTION = 60_000 ether; // 10'000 MATICX/month, 6 months
  /// @dev already deployed and configured for the both the MATICX asset and the 0x0c54a0BCCF5079478a144dBae1AFcb4FEdf7b263 EMISSION_ADMIN
  ITransferStrategyBase public constant override TRANSFER_STRATEGY =
    ITransferStrategyBase(0x53F57eAAD604307889D87b747Fc67ea9DE430B01);
  IEACAggregatorProxy public constant override REWARD_ORACLE =
    IEACAggregatorProxy(AaveV3PolygonAssets.MaticX_ORACLE);

  uint88 public constant DURATION_DISTRIBUTION = 180 days;
  address constant EMISSION_ADMIN = 0x0c54a0BCCF5079478a144dBae1AFcb4FEdf7b263; // Polygon Foundation
  address MATICX_WHALE = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
  address vWMATIC_WHALE = 0xd0F7cB3Bf8560b1D8E20792A79F4D3aD5406014e;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 60952423);

    vm.prank(MATICX_WHALE);
    IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, TOTAL_DISTRIBUTION);

    vm.prank(EMISSION_ADMIN);
    IERC20(REWARD_ASSET).approve(address(TRANSFER_STRATEGY), TOTAL_DISTRIBUTION);
  }

  function test_activation() public {
    vm.prank(EMISSION_ADMIN);
    IEmissionManager(AaveV3Polygon.EMISSION_MANAGER).configureAssets(_getAssetConfigs());

    emit log_named_bytes(
      'calldata to submit from Gnosis Safe',
      abi.encodeWithSelector(
        IEmissionManager(AaveV3Polygon.EMISSION_MANAGER).configureAssets.selector,
        _getAssetConfigs()
      )
    );

    _testClaimRewardsForWhale(
      vWMATIC_WHALE,
      AaveV3PolygonAssets.WPOL_V_TOKEN,
      DURATION_DISTRIBUTION,
      7150 ether
    );
  }

  function _getAssetConfigs()
    internal
    view
    override
    returns (RewardsDataTypes.RewardsConfigInput[] memory)
  {
    uint32 distributionEnd = uint32(block.timestamp + DURATION_DISTRIBUTION);

    EmissionPerAsset[] memory emissionsPerAsset = _getEmissionsPerAsset();

    RewardsDataTypes.RewardsConfigInput[]
      memory configs = new RewardsDataTypes.RewardsConfigInput[](emissionsPerAsset.length);
    for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
      configs[i] = RewardsDataTypes.RewardsConfigInput({
        emissionPerSecond: _toUint88(emissionsPerAsset[i].emission / DURATION_DISTRIBUTION),
        totalSupply: 0, // IMPORTANT this will not be taken into account by the contracts, so 0 is fine
        distributionEnd: distributionEnd,
        asset: emissionsPerAsset[i].asset,
        reward: REWARD_ASSET,
        transferStrategy: TRANSFER_STRATEGY,
        rewardOracle: REWARD_ORACLE
      });
    }

    return configs;
  }

  function _getEmissionsPerAsset() internal pure override returns (EmissionPerAsset[] memory) {
    EmissionPerAsset[] memory emissionsPerAsset = new EmissionPerAsset[](1);
    emissionsPerAsset[0] = EmissionPerAsset({
      asset: AaveV3PolygonAssets.WPOL_V_TOKEN,
      emission: TOTAL_DISTRIBUTION // 100% of the distribution
    });

    uint256 totalDistribution;
    for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
      totalDistribution += emissionsPerAsset[i].emission;
    }
    require(totalDistribution == TOTAL_DISTRIBUTION, 'INVALID_SUM_OF_EMISSIONS');

    return emissionsPerAsset;
  }
}
