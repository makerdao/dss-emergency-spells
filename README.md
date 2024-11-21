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

TBD.

## Implemented Actions

| Description        | Single ilk         | Multi ilk          | Related ilks       |
| :----------        | :--------:         | :-------:          | :-------:          |
| Wipe `line`        | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Set `Clip` breaker | :white_check_mark: | :white_check_mark: | :white_check_mark: |
| Disable `DDM`      | :white_check_mark: | :x:                | :x:                |
| Stop `OSM`         | :white_check_mark: | :white_check_mark: | :x:                |
| Halt `LitePSM`     | :white_check_mark: | :x:                | :x:                |
| Stop `Splitter`    | :x:                | :white_check_mark: | :x:                |

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

Some types of emergency spells may come in 3 flavors:

1. Single-ilk: applies the desired spell action to a single pre-defined ilk.
1. Multi-ilk: applies the desired spell action to all applicable ilks.
1. Hardcoded Multi-ilk: applies the desired spell action to a hardcoded list of retlated ilks (i.e.: `ETH-A`, `ETH-B` and `ETH-C`)

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
