/**
 * @dev matches the code from known address book imports and generates an import statement satisfying the used libraries
 * @param code
 * @returns
 */
function generateAddressBookImports(code: string) {
  const imports: string[] = [];
  let root = '';
  // lookbehind for I to not match interfaces like IAaveV3ConfigEngine
  const addressBookMatch = code.match(/(?<!I)(AaveV[2..3][A-Za-z]+)(?<!(Assets)|(EModes))\b\./);
  if (addressBookMatch) {
    imports.push(addressBookMatch[1]);
    root = addressBookMatch[1];
  }
  const assetsMatch = code.match(/(AaveV[2..3][A-Za-z]+)Assets\./);
  if (assetsMatch) {
    imports.push(assetsMatch[1] + 'Assets');
    root = assetsMatch[1];
  }
  const eModesMatch = code.match(/(AaveV[2..3][A-Za-z]+)EModes\./);
  if (eModesMatch) {
    imports.push(eModesMatch[1] + 'EModes');
    root = eModesMatch[1];
  }
  if (imports.length > 0) return `import {${imports}} from 'aave-address-book/${root}.sol';\n`;
}

function findMatch(code: string, needle: string) {
  return RegExp(needle, 'g').test(code);
}

/**
 * @dev Returns the input string prefixed with imports
 * @param code
 * @returns
 */
export function prefixWithImports(code: string) {
  let imports = '';
  // address book imports
  const addressBookImports = generateAddressBookImports(code);
  if (addressBookImports) {
    imports += addressBookImports;
  }

  if (findMatch(code, 'IEmissionManager')) {
    imports += `import {IEmissionManager, ITransferStrategyBase, RewardsDataTypes, IEACAggregatorProxy} from '../../src/interfaces/IEmissionManager.sol';\n`;
  }
  if (findMatch(code, 'LMSetupBaseTest')) {
    imports += `import {LMSetupBaseTest} from '../utils/LMSetupBaseTest.sol';\n`;
  }
  if (findMatch(code, 'LMUpdateBaseTest')) {
    imports += `import {LMUpdateBaseTest} from '../utils/LMUpdateBaseTest.sol';\n`;
  }
  if (findMatch(code, 'IAaveIncentivesController')) {
    imports += `import {IAaveIncentivesController} from '../src/interfaces/IAaveIncentivesController.sol';\n`;
  }

  return imports + code;
}
