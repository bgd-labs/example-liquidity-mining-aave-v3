import {expect, describe, it} from 'vitest';
import {MOCK_OPTIONS_SETUP, liquidityMiningSetupConfig} from './mocks/configs';
import {generateFiles} from '../generator';
import {FEATURE, PoolConfigs} from '../types';
import {setupLiquidityMining} from './setupLiquidityMining';

describe('feature: setupLiquidityMining', () => {
  it('should return reasonable code', () => {
    const output = setupLiquidityMining.build({
      options: MOCK_OPTIONS_SETUP,
      pool: 'AaveV3EthereumLido',
      cfg: liquidityMiningSetupConfig,
      cache: {blockNumber: 42},
    });
    expect(output).toMatchSnapshot();
  });

  it('should properly generate files', async () => {
    const poolConfigs: PoolConfigs = {
      [MOCK_OPTIONS_SETUP.pool]: {
        pool: MOCK_OPTIONS_SETUP.pool,
        artifacts: [
          setupLiquidityMining.build({
            options: MOCK_OPTIONS_SETUP,
            pool: 'AaveV3EthereumLido',
            cfg: liquidityMiningSetupConfig,
            cache: {blockNumber: 42},
          }),
        ],
        configs: {[FEATURE.SETUP_LM]: liquidityMiningSetupConfig},
        cache: {blockNumber: 42},
      },
    };
    const files = await generateFiles(MOCK_OPTIONS_SETUP, poolConfigs);
    expect(files).toMatchSnapshot();
  });
});
