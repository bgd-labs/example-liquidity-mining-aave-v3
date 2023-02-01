# Liquidity Mining on Aave V3 Example Repository

This repository contains:

- an [example proposal](./src/contracts/AddEmissionAdminPayload.sol) payload which could be used to setup liquidity mining on a governance controlled aave v3 pool
- a [test](./tests/EmissionTestOpOptimism.t.sol) simulating the configuration of certain assets to receive liquidity mining

## How to modify emissions of the LM program?

The function `_getEmissionsPerAsset()` on [EmissionTestOpOptimism.t.sol](./tests/EmissionTestOpOptimism.t.sol) defines the exact emissions for the particular case of $OP as reward token and a total distribution of 5'000'000 $OP during exactly 90 days.
The emissions can be modified there, with the only requirement being that `sum(all-emissions) == TOTAL_DISTRIBUTION`

You can run the test via `forge test -vv` which will emit the selector encoded calldata for `configureAssets` on the emission admin which you can use to execute the configuration changes e.g. via Safe.

### Setup

```sh
cp .env.example .env
forge install
```

### Test

```sh
forge test
```

## Copyright

2022 BGD Labs
