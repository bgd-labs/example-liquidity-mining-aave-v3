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
test-maticx-rewards :; forge test -vvv --match-contract EmissionTestMATICXPolygon
test-Avax-LM-rewards :; FOUNDRY_PROFILE=avax forge test -vvv --match-contract EmissionTestAVAXLMAvax
test-lido-rewards :; FOUNDRY_PROFILE=mainnet forge test -vvv --match-contract EmissionTestETHLMETH
test-arbGHO-rewards :; FOUNDRY_PROFILE=arbitrum forge test -vvv --match-contract EmissionTestARBGHOLMETH

# scripts

deploy-sd-transfer-strategy :;  forge script scripts/RewardsConfigHelpers.s.sol:SDDeployTransferStrategy --rpc-url polygon --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --verify -vvvv
deploy-stmatic-transfer-strategy :;  forge script scripts/RewardsConfigHelpers.s.sol:STMATICDeployTransferStrategy --rpc-url polygon --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --verify -vvvv
deploy-mainnet-sd-transfer-strategy :; forge script scripts/RewardsConfigHelpers.s.sol:SDMainnetDeployTransferStrategy --rpc-url mainnet  -- sender ${SENDER} --private-key ${PRIVATE_KEY} --verify -vvvv --slow --broadcast
deploy-avax-transfer-strategy :; forge script scripts/RewardsConfigHelpers.s.sol:AVAXDeployTransferStrategy --rpc-url avalanche  --sender ${SENDER} --private-key ${PRIVATE_KEY} --verify -vvvv --slow --broadcast
deploy-arb-transfer-strategy :; forge script scripts/RewardsConfigHelpers.s.sol:ARBDeployTransferStrategy --rpc-url arbitrum  --sender ${SENDER} --private-key ${PRIVATE_KEY} --verify -vvvv --slow --broadcast