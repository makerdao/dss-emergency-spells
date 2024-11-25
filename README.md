# Maker Protocol Emergency Spells

Pre-deployed spells to allow MakerDAO Governance to react faster in case of emergencies.

## Motivation

In Maker's linguo, a spell is a bespoke smart contract to execute authorized actions in Maker Protocol on behalf on
Maker Governance.

Since most contracts in Maker Protocol follow a [simple, battle-tested authorization scheme][auth], with an "all or
nothing" approach, it means that every spell has _root_ access to every single of its components.

[auth]: https://github.com/makerdao/pe-checklists/blob/master/core/standards.md#permissions

In order to mitigate the risks associated with that design decision, the spell process is quite "heavy", where
multiple trusted parties are involved, and with comprehensive [checklists][spell-checklists] that must be strictly
followed.

[spell-checklists]: https://github.com/makerdao/pe-checklists/tree/master/spell

With all the complexity and coordination effort, it is not a surprise that it takes a long time for a spell to be
successfully crafted, reviewed and handed over to Maker Governance. As per the [current process][spell-schedule], with
the involvement of at least 3 engineers from the different EAs in the Spell Team, not to mention the Governance
Facilitators and other key stakeholders, it takes at least 8 working days to deliver a regular spell.

[spell-schedule]: https://github.com/makerdao/pe-checklists/blob/master/spell/spell-crafter-mainnet-workflow.md#spell-coordination-schedule

For emergency spells, historically the agreed SLA had been 24h. That was somehow possible when there was a single
tight-knit team working on spells, however can be specially challenging with a more decentralized workforce, which is
scattered around the world. Even if it was still possible to meet that SLA, in some situations 24h might be too much
time.

This repository contains a couple of different spells performing emergency actions that can be pre-deployed to allow
MakerDAO Governance to quickly respond to incidents, without the need for dedicated engineers to chime in and craft a
bespoke spell in record time.

## Deployments

### On-chain Emergency Spell Factories

| Name                       | Address                                      |
| ----                       | -------                                      |
| `SingleClipBreakerFactory` | `0x24d040a1a15211aa82665c329345312fb19a4188` |
| `SingleDdmDisableFactory`  | `0xaa4bd9509d79998F4F93C3DD4e8C85e15cF880CB` |
| `SingleLineWipeFactory`    | `0x5Ae82C6762bdc1B17C5D459E0c4470619C5EBDBf` |
| `SingleLitePsmHaltFactory` | `0x4F9A00B3981df420Aa8302D889d0F175Df93036d` |
| `SingleOsmStopFactory`     | `0x8C49d9909A6c3B83E4Fb79bF6Ac99Ed75F121b2e` |

### `SingleClipBreakerSpell`

| Ilk         | Address                                      |
|-------------|----------------------------------------------|
| ETH\-A      | `0x784724299901a9E9B658a109A292CACc91979C9f` |
| ETH\-B      | `0xD6D270685fD67cf2D33885d07F8b671c9c96e8f7` |
| ETH\-C      | `0x1C86f7a6B65eeF7Cb79F1ED9FB67897eC71948Cf` |
| LSE\-MKR\-A | `0xB08aE12dcffA8e51B69F2962C3E0744fF142feCB` |
| WBTC\-A     | `0x26bcBb960c0b4488B39f6BEE6CD0D771dBccFa52` |
| WBTC\-B     | `0x5603e15CCE76cD3357c4cC4ee789D3919aB91528` |
| WBTC\-C     | `0x43169E5fB77585d994bF3F23193C3D8Ff6B015D7` |
| WSTETH\-A   | `0xf817ef1992a80A00A44A219CDEf9f6CaB8f1c2Dd` |
| WSTETH\-B   | `0x008Aed912C7Ba277B3A2758BB6aa29bb276738C3` |

### `SingleDdmDisableSpell`

| Ilk                           | Address                                      |
|-------------------------------|----------------------------------------------|
| DIRECT\-SPARK\-DAI            | `0xA5336B79129d34B9c110Def17cb6a5843aB7140C` |
| DIRECT\-SPARK\-MORPHO\-DAI    | `0xDAb9Cb1f33B30d70051a953290caC87ae6991BAf` |
| DIRECT\-SPK\-AAVE\-LIDO\-USDS | `0xf6431659c996a4945b43BfF28D7c078C64695436` |

### `SingleLineWipeSpell`

| Ilk                 | Address                                      |
|---------------------|----------------------------------------------|
| ALLOCATOR\-SPARK\-A | `0xf02Cb9c64B6D86e6849417dC11930E6Dc2d83BE0` |
| ETH\-A              | `0x702Ae5d6e324bc1a95b7397760F0e57065c06Bdc` |
| ETH\-B              | `0xa6345660bbE9D192735Bb67b1092084D86219B38` |
| ETH\-C              | `0x728a888d9b8084c340d3cA9ADce08487C6bA86e6` |
| LSE\-MKR\-A         | `0xde03eC060831FcE1bDe38d9cd6D934773c05F782` |
| RWA001\-A           | `0xc25cD011406EEd461230D3c80aE03e6d1579a26C` |
| RWA002\-A           | `0x4992b99485c6Ef2A496a31Da23d540d19a04EB6c` |
| RWA009\-A           | `0x0B11b134c79B7a37aF7bCb339a450d714C172411` |
| RWA012\-A           | `0xC0a2030ADabD331B7d84e089AeF83129c95cBd2c` |
| RWA013\-A           | `0x73C9Dcc7b52F69624F48b1706700dA2C0ff7E262` |
| RWA015\-A           | `0xE9dC19639E73Cc018D0c430558029520e7BA3617` |
| WBTC\-A             | `0xdf40E76EB3EaF12B51C47558ec9f491E257026a9` |
| WBTC\-B             | `0x141361102B828227F18436dF9858cE73d31398c4` |
| WBTC\-C             | `0xEBEF0f068850949c5Def8A412a438eC1D39fb991` |
| WSTETH\-A           | `0x8fC27905FAC08D737B719382ff02CaF59D5dbA1B` |
| WSTETH\-B           | `0xE57899652a5eC3564747A9324Cca8E16aC008BfD` |

### `SingleLitePsmHaltSpell`

| Ilk                | Flow | Address                                      |
|--------------------|------|----------------------------------------------|
| LITE\-PSM\-USDC\-A | BOTH | `0x37236771DAB68263e98534671b56534B7EC069b9` |
| LITE\-PSM\-USDC\-A | BUY  | `0x507399CBE10BF6Fd2C7895391cc9fc0Cb89eE7ca` |
| LITE\-PSM\-USDC\-A | SELL | `0x54190A5e59720994AC57a76c878bF01bEe68C41D` |

### `SingleOsmStopSpell`

| Ilk         | Address                                      |
|-------------|----------------------------------------------|
| ETH\-A      | `0x3D6211C5073f815e43d8EfEa937662F70222561F` |
| ETH\-B      | `0xEDEb71209336DFdb178C75E12a4a4B9099200f40` |
| ETH\-C      | `0x170aC7c0ab1d65F18204A6704C315090d6fF5D1B` |
| LSE\-MKR\-A | `0xca0A1f3Cc2fcF46D9536FDD7371552E46c25A638` |
| WBTC\-A     | `0x185ad7b1624B6393B063574DF225DD1c0eBB1C17` |
| WBTC\-B     | `0xfc94793A1479706a9a834BE1CC3F45135CC41480` |
| WBTC\-C     | `0x3Fe5e6A7A1E66192E1DdCE28c978a779df6a08c5` |
| WSTETH\-A   | `0x53E201A9d0846E599D30C3d1a6E37bC7A8c109Ba` |
| WSTETH\-B   | `0x693acbbAB58055b43c515ca3362E4535584eeD6c` |

### `SplitterStopSpell`

```
0x04576C3B9Bd1623627b5bcaaD3Ac75fA70e298df
```

### `MultiClipBreakerSpell`

```
0x828824dBC62Fba126C76E0Abe79AE28E5393C2cb
```

### `MultiLineWipeSpell`

```
0x4B5f856B59448304585C2AA009802A16946DDb0f
```

### `MultiOsmStopSpell`

```
0x3021dEdB0bC677F43A23Fcd1dE91A07e5195BaE8
```

## Implemented Actions

| Description        | Single ilk         | Multi ilk          |
| :----------        | :--------:         | :-------:          |
| Wipe `line`        | :white_check_mark: | :white_check_mark: |
| Set `Clip` breaker | :white_check_mark: | :white_check_mark: |
| Disable `DDM`      | :white_check_mark: | :x:                |
| Stop `OSM`         | :white_check_mark: | :white_check_mark: |
| Halt `PSM`         | :white_check_mark: | :x:                |
| Stop `Splitter`    | :x:                | :white_check_mark: |

### Wipe `line`

No further debt can be generated from an ilk whose `line` is wiped.

If `MCD_IAM_AUTO_LINE` is configured for the ilk, it will be removed.

It also prevents the debt ceiling (`line`) for the affected ilk from being changed without Governance interference.

### Set `Clip` breaker

Halts collateral auctions happening in the `MCD_CLIP_{ILK}` contract belonging to the specified ilks. Sets the breaker level to 3
to prevent both `kick()`, `redo()` and `take()`.

### Disable `DDM`

Disables a Direct Deposit Module (`DIRECT_{ID}_PLAN`), preventing further debt from being generated from it.

### Stop `OSM`

Stops the specified Oracle Security Module (`PIP_{GEM}`) instances, preventing updates in their price feeds.

### Halt `PSM`

Halts swaps on the `PSM`, with optional direction (only `GEM` buys, only `GEM` sells, both).

### Stop `Splitter`

Disables the smart burn engine.

## Design

### Overview

Emergency spells are meant to be as ABI-compatible with regular spells as possible, to allow Governance to reuse any
existing tools, which will not increase the cognitive burden in an emergency situation.

Previous bespoke emergency spells ([see example][example-emergency-spell]) would perform an open-heart surgery in the
standard [`DssExec`][dss-exec] contract and include the emergency actions calls in the `schedule` function. This allows
any contract using the `Mom` architecture ([see example][example-mom]) to bypass the GSM delay.

The same restrictions to regulars spells still apply (i.e.: storage variables are not allowed).

The emergency spells in this repository build on that idea with a few modifications:

1. No [`DssExecLib`][dss-exec-lib] dependency: emergency actions are quite simple by nature, which makes the use of
   `DssExecLib` superfluous.
1. No expiration time: contrary to regular spells, which are meant to be cast only once, emergency spells can be reused
   if needed, so the expiration time is set so far away in the future that in practice the spell does not expire.
1. No separate [`DssAction`][dss-action]-like contract: regular spells delegate the execution of specific actions to a
   `DssAction` contract that is deployed by the spell in its constructor. The exact reason for that design choice is
   unknown to the authors, however we can speculate that the way the spell `tag` is derived<sup>[\[1\]](#fn-1)</sup>
   requires a separate contract.
1. Casting is a no-op: while bespoke emergency spells would often conflate emergency actions with non-emergency ones,
   pre-deployed emergency spells perform only emergency actions, turning `cast()` into a no-op, which exists only for
   interface-compatibility purposes.
1. No `MCD_PAUSE` interaction: as its name might suggest, the main goal of `MCD_PAUSE` is to introduce a _pause_ (GSM
   delay) between the approval of a spell and its execution. Emergency spells by definition bypass the GSM delay, so
   there is no strong reason to `plan` them in `MCD_PAUSE` as regular spells.

[example-emergency-spell]: https://github.com/makerdao/spells-mainnet/blob/8b0e1c354a0add49f595eea01ca3a822e782ab0d/archive/2022-06-15-DssSpell/DssSpell.sol
[dss-exec]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExec.sol
[dss-exec-lib]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExecLib.sol
[dss-action]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssAction.sol
[example-mom]: https://etherscan.io/address/0x9c257e5Aaf73d964aEBc2140CA38078988fB0C10

<sub id="fn-1"><sup>\[1\]</sup> `tag` is meant to be immutable and [extract the `codehash` of the `action`
contract][spell-tag]. Notice that it would not be possible to get the `codehash` of the same contract in its
constructor.</sub>

[spell-tag]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExec.sol#L75

Some types of emergency spells may come in 2 flavors:

1. Single ilk: applies the desired spell action for a single pre-defined ilk.
1. Multi ilk: applies the desired spell action for all applicable ilks.

Furthermore, this repo provides on-chain factories for single ilk emergency spells to make it easier to deploy for new
ilks.

### About the `done()` function

Conforming spells have a [`done`][spell-done] public storage variable which is `false` when the spell is deployed and
set to `true` when the spell is cast. This ensures a spell cannot be cast twice.

An emergency spell is not meant to be cast, but it can be scheduled multiple times. So instead of having `done` as a
storage variable, it becomes a getter function that will return:
- `false`: if the emergency spell can be scheduled in the current state, given it is lifted to the hat.
- `true`: if the desired effects of the spell can be verified or if there is anything that would prevent the spell from
  being scheduled (i.e.: bad system config)

Generally speaking, `done` should almost always return `false` for any emergency spell. If it returns `true` it means it
has just been scheduled or there is most likely something wrong with the modules touched by it. The exception is the
case where the system naturally achieves the same final state as the spell being scheduled, in which it would be also
returned `true`.

In other words, if `done() == true`, it means that the actions performed by the spell are not applicable.

[spell-done]: https://github.com/makerdao/dss-exec-lib/blob/69b658f35d8618272cd139dfc18c5713caf6b96b/src/DssExec.sol#L43
