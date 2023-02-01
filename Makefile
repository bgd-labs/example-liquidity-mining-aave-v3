# include .env file and export its env vars
# (-include to ignore error if it does not exist)
-include .env

# deps
update:; forge update

# Build & test
build  :; forge build --sizes --via-ir
test   :; forge test -vvv
test-sd-rewards :; forge test -vvv --match-contract EmissionTestSDPolygon

# scripts
deploy-sd-transfer-strategy :;  forge script scripts/RewardsConfigHelpers.s.sol:SDDeployTransferStrategy --rpc-url polygon --broadcast --legacy --ledger --mnemonic-indexes ${MNEMONIC_INDEX} --sender ${LEDGER_SENDER} --verify -vvvv
