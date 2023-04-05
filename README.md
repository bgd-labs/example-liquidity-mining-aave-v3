# Liquidity Mining on Aave V3 Example Repository

This repository contains:

- an [example proposal](./src/contracts/AddEmissionAdminPayload.sol) payload which could be used to setup liquidity mining on a governance controlled aave v3 pool
- a [test](./tests/EmissionTestOpOptimism.t.sol) simulating the configuration of certain assets to receive liquidity mining
- a [test](./tests/EmissionConfigurationTestMATICXPolygon.t.sol) simulating the setting up of new configuration of certain assets after the liquidity mining program has been created

## How to modify emissions of the LM program?

The function `_getEmissionsPerAsset()` on [EmissionTestOpOptimism.t.sol](./tests/EmissionTestOpOptimism.t.sol) defines the exact emissions for the particular case of $OP as reward token and a total distribution of 5'000'000 $OP during exactly 90 days.
The emissions can be modified there, with the only requirement being that `sum(all-emissions) == TOTAL_DISTRIBUTION`

You can run the test via `forge test -vv` which will emit the selector encoded calldata for `configureAssets` on the emission admin which you can use to execute the configuration changes e.g. via Safe.

## How to configure emissions after the LM program has been created?

After the LM program has been created, the emissions per second and the distribution end could be changed later on by the emissions admin to reduce the LM rewards or change the end date for the distribution. This can be done by calling `setEmissionPerSecond()` and `setDistributionEnd()` on the Emission Manager contract. The test examples on [EmissionConfigurationTestMATICXPolygon.t.sol](./tests/EmissionConfigurationTestMATICXPolygon.t.sol) shows how to do so.

The function `_getNewEmissionPerSecond()` and `_getNewDistributionEnd()` defines the new emissions per second and new distribution end for the particular case, which could be modified there to change to modified emissions per second and distribution end.

Similarly you can also run the test via `forge test -vv` which will emit the selector encoded calldata for `setEmissionPerSecond` and `setDistributionEnd` which can be used to make the configuration changes.

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
