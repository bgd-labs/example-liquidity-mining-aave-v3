# Liquidity Mining on Aave V3 Example Repository

This repository contains:

- an [example proposal](./src/contracts/AddEmissionAdminPayload.sol) payload which could be used to setup liquidity mining on a governance controlled aave v3 pool
- a [test](./tests/EmissionTestOpOptimism.t.sol) simulating the configuration of certain assets to receive liquidity mining
- a [test](./tests/EmissionConfigurationTestMATICXPolygon.t.sol) simulating the setting up of new configuration of certain assets after the liquidity mining program has been created

## Instructions to activate Liquidity Mining on Aave V3:

<img width="924" alt="Screenshot 2023-04-06 at 12 47 24 PM" src="https://user-images.githubusercontent.com/22850280/230302952-44da8732-3a2a-4ebb-96cb-90262b420c04.png">

1. Make sure the rewards funds that are needed to be distributed for Liquidity Mining are present in the Emission Admin address.

   _Note: The Emission Admin is an address which has access to manange and configure the reward emissions by calling the Emission Manager contract._

2. Do an ERC-20 approve of the total rewards to be distributed to the Transfer Strategy contract, this is contract by Aave which helps to pull the Liquidity Mining rewards from the Emission Admin address to distribute to the user. To know more about how Transfer Strategy contract works you can check [here](https://github.com/aave/aave-v3-periphery/blob/master/docs/rewards/rewards-transfer-strategies.md).

   _Note: The general type of Transfer Strategy contract used for Liquidity Mining is of type PullRewardsStrategy._

3. Finally we need to configure the Liquidity Mining emissions on the Emission Manager contract by calling the `configureAssets()` function which will take the array of the following struct to configure liquidity mining for mulitple assets for the same reward or multiple assets for mutiple rewards.

   ```
   EMISSION_MANAGER.configureAssets([{

     emissionPerSecond: The emission per second following rewards unit decimals.

     totalSupply: The total supply of the asset to incentivize. This should be kept as 0 as the Emissions Manager will fill this up.

     distributionEnd: The end of the distribution of rewards (in seconds).

     asset: The asset for which rewards should be given. Should be the address of the aave aToken (for deposit) or debtToken (for borrow).
            In case where the asset for reward is for debt token please put the address of stable debt token for rewards in stable borrow mode
            and address of variable debt token for rewards in variable borrow mode.

     reward: The reward token address to be used for Liquidity Mining for the asset.

     transferStrategy: The address of transfer strategy contract.

     rewardOracle: The Chainlink Aggregator compatible Price Oracle of the reward.

   }])
   ```

Below is an example with the pseudo code to activate Liquidity Mining for the variable borrow of `wMatic` with `MaticX` as the reward token for the total amount of `60,000` `MaticX` for the total duration of `6 months`. For a more detailed explanation checkout this [test](./tests/EmissionTestMATICXPolygon.t.sol).

1. Make sure EMISSION_ADMIN has sufficient balance of the MaticX token.

   ```
   IERC20(MATIC_X_ADDRESS).balanceOf(EMISSION_ADMIN) > 60000 *1e18
   ```

2. Do an ERC-20 approve from the MaticX token to the transfer strategy contract for the total amount.

   ```
   IERC20(MATIC_X_ADDRESS).approve(TRANSFER_STRATEGY_ADDRESS, 60000 *1e18);
   ```

3. Configure the Liquidity Mining emissions on the Emission Manager contract.

   ```
   EMISSION_MANAGER.configureAssets([{

     emissionPerSecond: 60000 * 1e18 / (180 days in seconds)

     totalSupply: 0

     distributionEnd: current timestamp + (180 days in seconds)

     asset: Aave Variable Debt Token of wMatic // 0x4a1c3aD6Ed28a636ee1751C69071f6be75DEb8B8

     reward: MaticX Token address // 0xfa68FB4628DFF1028CFEc22b4162FCcd0d45efb6

     transferStrategy: ITransferStrategyBase(STRATEGY_ADDRESS) // 0x53F57eAAD604307889D87b747Fc67ea9DE430B01

     rewardOracle: IEACAggregatorProxy(MaticX_ORACLE_ADDRESS) // 0x5d37E4b374E6907de8Fc7fb33EE3b0af403C7403

   }])
   ```

Awesome! so liquidity mining has been succefully configured now.

After the Liquidity Mining has been set, we can also configure later on to increase or decrease the rewards (emissions per second) and to change the end date for liquidity mining. More info on this below.

## How to modify emissions of the LM program?

The function `_getEmissionsPerAsset()` on [EmissionTestOpOptimism.t.sol](./tests/EmissionTestOpOptimism.t.sol) defines the exact emissions for the particular case of $OP as reward token and a total distribution of 5'000'000 $OP during exactly 90 days.
The emissions can be modified there, with the only requirement being that `sum(all-emissions) == TOTAL_DISTRIBUTION`

You can run the test via `forge test -vv` which will emit the selector encoded calldata for `configureAssets` on the emission admin which you can use to execute the configuration changes e.g. via Safe.

## How to configure emissions after the LM program has been created?

After the LM program has been created, the emissions per second and the distribution end could be changed later on by the emissions admin to reduce the LM rewards or change the end date for the distribution. This can be done by calling `setEmissionPerSecond()` and `setDistributionEnd()` on the Emission Manager contract. The test examples on [EmissionConfigurationTestMATICXPolygon.t.sol](./tests/EmissionConfigurationTestMATICXPolygon.t.sol) shows how to do so.

The function `_getNewEmissionPerSecond()` and `_getNewDistributionEnd()` defines the new emissions per second and new distribution end for the particular case, which could be modified there to change to modified emissions per second and distribution end.

Similarly you can also run the test via `forge test -vv` which will emit the selector encoded calldata for `setEmissionPerSecond` and `setDistributionEnd` which can be used to make the configuration changes.

## FAQ's:

- Do we need to have and approve the whole liquidity mining reward initially?

  It is generally advisable to have and approve funds for the duration of the next 3 months of the Liquidity Mining Program. However it is the choice of the Emission Admin to do it progressively as well, as the users accrue rewards over time.

- Can we configure mutiple rewards for the same asset?

  Yes, Liquidity Mining could be configured for multiple rewards for the same asset.

- Why do we need to approve funds to the Aave Transfer Strategy contract?

  This is needed so the Transfer Strategy contract can pull the rewards from the Emission Admin to distribute it to the user when the user claims them.

- Can we stop the liquidity mining program at any time?

  Yes, the liquidity mining program could be stopped at any moment by the Emission Admin.
  The duration of the Liquidity Mining program could be increased as well, totally the choice of Emission Admin.

- Can we change the amount of liquidty mining rewards?

  Yes, the liquidity mining rewards could be increased or decreased by the Emission Admin.

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
