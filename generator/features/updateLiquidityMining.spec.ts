import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS_UPDATE, liquidityMiningUpdateConfig} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';
import {updateLiquidityMining} from './updateLiquidityMining';

describe('feature: updateLiquidityMining', () => {
  it('should return reasonable code', () => {
    const output = updateLiquidityMining.build({
      options: MOCK_OPTIONS_UPDATE,
      pool: 'AaveV3EthereumLido',
      cfg: liquidityMiningUpdateConfig,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      [MOCK_OPTIONS_UPDATE.pool]: {
        pool: MOCK_OPTIONS_UPDATE.pool,
        artifacts: [
          updateLiquidityMining.build({
            options: MOCK_OPTIONS_UPDATE,
            pool: 'AaveV3EthereumLido',
            cfg: liquidityMiningUpdateConfig,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.UPDATE_LM]: liquidityMiningUpdateConfig},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles(MOCK_OPTIONS_UPDATE, poolConfigs);
    expect(files).toMatchSnapshot();
  });
});
