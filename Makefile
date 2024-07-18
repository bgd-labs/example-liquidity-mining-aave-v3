# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes --via-ir
test   :; forge test -vvv

test-contract :; forge test --match-contract ${filter} -vv

test-sd-rewards :; forge test -vvv --match-contract EmissionTestSDPolygon
test-stmatic-rewards :; forge test -vvv --match-contract EmissionTestSTMATICPolygon
test-Ethx-rewards :; FOUNDRY_PROFILE=mainnet forge test -vvv --match-contract EmissionTestEthXMainnet
test-BTCb-Avax-rewards :; FOUNDRY_PROFILE=avax forge test -vvv --match-contract EmissionTestBTCbAvax
test-wAVAX-Avax-rewards :; FOUNDRY_PROFILE=avax forge test -vvv --match-contract EmissionTestwAVAXAvax
test-USDC-Avax-rewards :; FOUNDRY_PROFILE=avax forge test -vvv --match-contract EmissionTestUSDCAvax
test-maticx-rewards :; forge test -vvv --match-contract EmissionTestMATICXPolygon

# scripts
deploy-sd-transfer-strategy :;  forge script scripts/RewardsConfigHelpers.s.sol:SDDeployTransferStrategy --rpc-url polygon --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --verify -vvvv
deploy-stmatic-transfer-strategy :;  forge script scripts/RewardsConfigHelpers.s.sol:STMATICDeployTransferStrategy --rpc-url polygon --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --verify -vvvv
deploy-mainnet-sd-transfer-strategy :; forge script scripts/RewardsConfigHelpers.s.sol:SDMainnetDeployTransferStrategy --rpc-url mainnet  -- sender ${SENDER} --private-key ${PRIVATE_KEY} --verify -vvvv --slow --broadcast
deploy-avax-transfer-strategy :; forge script scripts/RewardsConfigHelpers.s.sol:AVAXDeployTransferStrategy --rpc-url avalanche  --sender ${SENDER} --private-key ${PRIVATE_KEY} --verify -vvvv --slow --broadcast