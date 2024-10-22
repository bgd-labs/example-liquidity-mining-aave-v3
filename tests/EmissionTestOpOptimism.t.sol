// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {AaveV3Optimism} from 'aave-address-book/AaveV3Optimism.sol';
import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../src/interfaces/IEmissionManager.sol';
import {LMSetupBaseTest} from './utils/LMSetupBaseTest.sol';

contract EmissionTestOpOptimism is LMSetupBaseTest {
  address public constant override DEFAULT_INCENTIVES_CONTROLLER =
    AaveV3Optimism.DEFAULT_INCENTIVES_CONTROLLER;
  address public constant override REWARD_ASSET = 0x4200000000000000000000000000000000000042; // OP
  uint256 public constant override TOTAL_DISTRIBUTION = 5_000_000 ether; // 5m OP
  ITransferStrategyBase public constant override TRANSFER_STRATEGY =
    ITransferStrategyBase(0x80B2a024A0f347e774ec3bc58304978FB3DFc940);
  IEACAggregatorProxy public constant override REWARD_ORACLE =
    IEACAggregatorProxy(0x0D276FC14719f9292D5C1eA2198673d1f4269246); // OP/USD

  address constant EMISSION_ADMIN = 0x2501c477D0A35545a387Aa4A3EEe4292A9a8B3F0;
  uint88 constant DURATION_DISTRIBUTION = 90 days;

  function setUp() public {
    vm.createSelectFork(vm.rpcUrl('optimism'), 33341802);

    vm.prank(EMISSION_ADMIN);
    IERC20(REWARD_ASSET).approve(address(TRANSFER_STRATEGY), TOTAL_DISTRIBUTION);
  }

  function test_activation() public {
    vm.prank(EMISSION_ADMIN);
    IEmissionManager(AaveV3Optimism.EMISSION_MANAGER).configureAssets(_getAssetConfigs());

    emit log_bytes(
      abi.encodeWithSelector(
        IEmissionManager(AaveV3Optimism.EMISSION_MANAGER).configureAssets.selector,
        _getAssetConfigs()
      )
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
    EmissionPerAsset[] memory emissionsPerAsset = new EmissionPerAsset[](13);
    emissionsPerAsset[0] = EmissionPerAsset({
      asset: 0x625E7708f30cA75bfd92586e17077590C60eb4cD, // aOptUSDC
      emission: 517_500 ether // 10.35% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[1] = EmissionPerAsset({
      asset: 0xFCCf3cAbbe80101232d343252614b6A3eE81C989, // variableDebtOptUSDC
      emission: 1_207_500 ether // 24.15% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[2] = EmissionPerAsset({
      asset: 0x82E64f49Ed5EC1bC6e43DAD4FC8Af9bb3A2312EE, // aOptDAI
      emission: 315_000 ether // 6.3% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[3] = EmissionPerAsset({
      asset: 0x8619d80FB0141ba7F184CbF22fd724116D9f7ffC, // variableDebtOptDAI
      emission: 735_000 ether // 14.7% of TOTAL_DISTRIBUTION
    });

    emissionsPerAsset[4] = EmissionPerAsset({
      asset: 0x6ab707Aca953eDAeFBc4fD23bA73294241490620, // aOptUSDT
      emission: 180_000 ether // 3.6% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[5] = EmissionPerAsset({
      asset: 0xfb00AC187a8Eb5AFAE4eACE434F493Eb62672df7, // variableDebtOptUSDT
      emission: 420_000 ether // 8.4% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[6] = EmissionPerAsset({
      asset: 0x6d80113e533a2C0fe82EaBD35f1875DcEA89Ea97, // aOptSUSD
      emission: 120_000 ether // 2.4% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[7] = EmissionPerAsset({
      asset: 0x4a1c3aD6Ed28a636ee1751C69071f6be75DEb8B8, // variableDebtOptSUSD
      emission: 280_000 ether // 5.6% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[8] = EmissionPerAsset({
      asset: 0xe50fA9b3c56FfB159cB0FCA61F5c9D750e8128c8, // aOptWETH
      emission: 675_000 ether // 13.5% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[9] = EmissionPerAsset({
      asset: 0x0c84331e39d6658Cd6e6b9ba04736cC4c4734351, // variableDebtOptWETH
      emission: 75_000 ether // 1.5% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[10] = EmissionPerAsset({
      asset: 0x078f358208685046a11C85e8ad32895DED33A249, // aOptWBTC
      emission: 225_000 ether // 4.5% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[11] = EmissionPerAsset({
      asset: 0x92b42c66840C7AD907b4BF74879FF3eF7c529473, // variableDebtOptWBTC
      emission: 25_000 ether // 0.5% of TOTAL_DISTRIBUTION
    });
    emissionsPerAsset[12] = EmissionPerAsset({
      asset: 0xf329e36C7bF6E5E86ce2150875a84Ce77f477375, // aOptAAVE
      emission: 225_000 ether // 4.5% of TOTAL_DISTRIBUTION
    });

    uint256 totalDistribution;
    for (uint256 i = 0; i < emissionsPerAsset.length; i++) {
      totalDistribution += emissionsPerAsset[i].emission;
    }
    require(totalDistribution == TOTAL_DISTRIBUTION, 'INVALID_SUM_OF_EMISSIONS');

    return emissionsPerAsset;
  }
}
