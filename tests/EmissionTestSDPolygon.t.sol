// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Polygon, AaveV3PolygonAssets} from 'aave-address-book/AaveV3Polygon.sol';
import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {LMSetupBaseTest} from './utils/LMSetupBaseTest.sol';

contract EmissionTestSDPolygon is LMSetupBaseTest {
  address public constant override REWARD_ASSET = 0x1d734A02eF1e1f5886e66b0673b71Af5B53ffA94; // SD token
  address public constant override DEFAULT_INCENTIVES_CONTROLLER =
    AaveV3Polygon.DEFAULT_INCENTIVES_CONTROLLER;
  uint256 public constant override TOTAL_DISTRIBUTION = 81_120 ether; // 13'520 SD/month, 6 months
  /// @dev already deployed and configured for the both the SD asset and the 0x51358004cFe135E64453d7F6a0dC433CAba09A2a EMISSION_ADMIN
  ITransferStrategyBase public constant override TRANSFER_STRATEGY =
    ITransferStrategyBase(0xC51e6E38d406F98049622Ca54a6096a23826B426);
  IEACAggregatorProxy public constant override REWARD_ORACLE =
    IEACAggregatorProxy(0x30E9671a8092429A358a4E31d41381aa0D10b0a0); // SD/USD

  uint88 constant DURATION_DISTRIBUTION = 180 days;
  address constant EMISSION_ADMIN = 0x51358004cFe135E64453d7F6a0dC433CAba09A2a; // Stader Safe
  address constant SD_WHALE = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
  address constant aPolMATICX_WHALE = 0x807c561657E4Bf582Eee6C34046B0507Fc359960;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('polygon'), 39010930);

    deal(REWARD_ASSET, EMISSION_ADMIN, TOTAL_DISTRIBUTION);
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

    vm.prank(SD_WHALE);
    IERC20(REWARD_ASSET).transfer(EMISSION_ADMIN, 50_000 ether);

    _testClaimRewardsForWhale(
      aPolMATICX_WHALE,
      AaveV3PolygonAssets.MaticX_A_TOKEN,
      DURATION_DISTRIBUTION,
      13_093 ether
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
      asset: AaveV3PolygonAssets.MaticX_A_TOKEN,
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
