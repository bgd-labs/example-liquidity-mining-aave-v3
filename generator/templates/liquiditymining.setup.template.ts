import {generateContractName, getChainAlias, getPoolChain} from '../common';
import {Options, PoolConfig, PoolIdentifier} from '../types';
import {prefixWithImports} from '../utils/importsResolver';
import {prefixWithPragma} from '../utils/constants';

export const liquidityMiningSetupTemplate = (
  options: Options,
  poolConfig: PoolConfig,
  pool: PoolIdentifier
) => {
  const chain = getPoolChain(pool);
  const contractName = generateContractName(options, pool);

  const constants = poolConfig.artifacts
    .map((artifact) => artifact.code?.constants)
    .flat()
    .filter((f) => f !== undefined)
    .join('\n');
  const functions = poolConfig.artifacts
    .map((artifact) => artifact.code?.fn)
    .flat()
    .filter((f) => f !== undefined)
    .join('\n');

  const contract = `contract ${contractName} is LMSetupBaseTest {
   ${constants}

   function setUp() public {
    vm.createSelectFork(vm.rpcUrl('${getChainAlias(chain)}'), ${poolConfig.cache.blockNumber});
   }

   ${functions}
  }`;

  return prefixWithPragma(prefixWithImports(contract));
};
