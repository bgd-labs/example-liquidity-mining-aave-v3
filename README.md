# Liquidity Mining on Aave V3 Example Repository

This repository contains:

- an [example proposal](./src/contracts/AddEmissionAdminPayload.sol) payload which could be used to setup liquidity mining on a governance controlled aave v3 pool
- a [test](./tests/EmissionTestOpOptimism.t.sol) simulating the configuration of certain assets to receive liquidity mining
- a [test](./tests/EmissionConfigurationTestMATICXPolygon.t.sol) simulating the setting up of new configuration of certain assets after the liquidity mining program has been created

## Instructions to activate Liquidity Mining on Aave V3:

<img width="924" alt="Screenshot 2023-04-10 at 11 27 10 AM" src="https://user-images.githubusercontent.com/22850280/230836420-7b5c4bba-d851-4258-90c6-602d33eaf845.png">

1. Make sure the rewards funds that are needed to be distributed for Liquidity Mining are present in the Rewards Vault.

   _Note: The Rewards Vault is your address which contains the reward asset._

2. Do an ERC-20 approve of the total rewards to be distributed to the Transfer Strategy contract, this is contract by Aave which helps to pull the Liquidity Mining rewards from the Rewards Vault address to distribute to the user. To know more about how Transfer Strategy contract works you can check [here](https://github.com/aave/aave-v3-periphery/blob/master/docs/rewards/rewards-transfer-strategies.md).

   _Note: The Emission Admin is an address which has access to manage and configure the reward emissions by calling the Emission Manager contract and the general type of Transfer Strategy contract used for Liquidity Mining is of type PullRewardsStrategy._

3. Finally we need to configure the Liquidity Mining emissions on the Emission Manager contract from the Emission Admin by calling the `configureAssets()` function which will take the array of the following struct to configure liquidity mining for mulitple assets for the same reward or multiple assets for mutiple rewards.

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

     rewardOracle: The Chainlink Aggregator compatible Price Oracle of the reward (used on off-chain infra like UI for price conversion).

   }])
   ```

Below is an example with the pseudo code to activate Liquidity Mining for the variable borrow of `wMatic` with `MaticX` as the reward token for the total amount of `60,000` `MaticX` for the total duration of `6 months`. For a more detailed explanation checkout this [test](./tests/EmissionTestMATICXPolygon.t.sol).

1. Make sure the Rewards Vault has sufficient balance of the MaticX token.

   ```
   IERC20(MATIC_X_ADDRESS).balanceOf(REWARDS_VAULT) > 60000 *1e18
   ```

2. Do an ERC-20 approve from the MaticX token from the Rewards Vault to the transfer strategy contract for the total amount.

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

## How to modify emissions of the LM program?

The function `_getEmissionsPerAsset()` on [EmissionTestOpOptimism.t.sol](./tests/EmissionTestOpOptimism.t.sol) defines the exact emissions for the particular case of $OP as reward token and a total distribution of 5'000'000 $OP during exactly 90 days.
The emissions can be modified there, with the only requirement being that `sum(all-emissions) == TOTAL_DISTRIBUTION`

You can run the test via `forge test -vv` which will emit the selector encoded calldata for `configureAssets` on the emission admin which you can use to execute the configuration changes e.g. via Safe.

_Note: The test example above uses total distribution and duration distribution just for convenience to define emissions per second, in reality as we only pass emissions per second to `configureAssets()` we could define it in any way we wish._

## How to configure emissions after the LM program has been created?

After the LM program has been created, the emissions per second and the distribution end could be changed later on by the emissions admin to reduce the LM rewards or change the end date for the distribution. This can be done by calling `setEmissionPerSecond()` and `setDistributionEnd()` on the Emission Manager contract. The test examples on [EmissionConfigurationTestMATICXPolygon.t.sol](./tests/EmissionConfigurationTestMATICXPolygon.t.sol) shows how to do so.

The function `_getNewEmissionPerSecond()` and `_getNewDistributionEnd()` defines the new emissions per second and new distribution end for the particular case, which could be modified there to change to modified emissions per second and distribution end.

Similarly you can also run the test via `forge test -vv` which will emit the selector encoded calldata for `setEmissionPerSecond` and `setDistributionEnd` which can be used to make the configuration changes.

## FAQ's:

- Do we need to have and approve the whole liquidity mining reward initially?

  It is generally advisable to have and approve funds for the duration of the next 3 months of the Liquidity Mining Program. However it is the choice of the Emission Admin to do it progressively as well, as the users accrue rewards over time.

- Can we configure mutiple rewards for the same asset?

  Yes, Liquidity Mining could be configured for multiple rewards for the same asset.

- Why do we need to approve funds from the Rewards Vault to the Aave Transfer Strategy contract?

  This is needed so the Transfer Strategy contract can pull the rewards from the Rewards Vault to distribute it to the user when the user claims them.

- Can I reuse an already deployed transfer strategy?
  Yes, a transfer strategy could be reused if it has already been deployed for the given network (given that you want the rewards vault, rewards admin and the incentives controller to be the same).
- If a transfer strategy does not exist, how do I create one?

      The transfer strategy is an immutable contract which determines the logic of the rewards transfer. To create a new pull reward transfer strategy (most     common transfer strategy for liquidity mining) you could use the

  [PullRewardsTransferStrategy.sol](https://github.com/aave/aave-v3-periphery/blob/master/contracts/rewards/transfer-strategies/PullRewardsTransferStrategy.sol) contract with the following constructor params:

      - `incentivesController`: address of the incentives controller
      - `rewardsAdmin`: address of the incentives controller for access control
      - `rewardsVault`: address of the rewards vault containing the funds for the Liquidity Mining program.

      Example to deploy a transfer strategy can be found [here](./scripts/RewardsConfigHelpers.s.sol).

      _Note: All transfer strategy should inherit from the base contract [TransferStrategyBase.sol](https://github.com/aave/aave-v3-periphery/blob/master/contracts/rewards/transfer-strategies/TransferStrategyBase.sol) and you could also define your own custom transfer                   strategy even with NFT’s as rewards, given that you inherit from the base contract._

- Can we stop the liquidity mining program at any time?

  Yes, the liquidity mining program could be stopped at any moment by the Emission Admin.
  The duration of the Liquidity Mining program could be increased as well, totally the choice of Emission Admin.
  To stop the liquidity mining, we can either set the emissions per second to 0 or set the distribution end to the block we wish to stop liquiditiy mining at.

- Can we change the amount of liquidty mining rewards?

  Yes, the liquidity mining rewards could be increased or decreased by the Emission Admin. To do so, please refer
  [here](https://github.com/bgd-labs/example-liquidity-mining-aave-v3/tree/feat/configure-emissions#how-to-configure-emissions-after-the-lm-program-has-been-created)

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
