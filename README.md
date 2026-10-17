# Arbiter shared credit

A free example of a round-robin arbiter whose local fairness does not survive a shared credit class.

`req0` and `req1` share one credit pool. `req2` has a credit pool of its own. Both pools are refilled on every cycle they are empty. The arbiter grants `req2`, then `req0`, and repeats. `req1` stays asserted and is eligible on every class-0 cycle, but it never wins.

This is one compiled counterexample. It is not a formal proof and it is not a complete verification pack.

![Shared class credit trace](diagram/shared-credit.svg)

## Design

`rtl/rr_arb.v` is a four-requester round-robin arbiter. A request is eligible when `req` and `req_en` are both high. The grant is combinational and one-hot. The priority mask advances only when a grant is issued. After the highest index wins, the mask wraps and the next grant is the lowest eligible requester.

`rtl/rr_arb_shared_credit.v` instantiates that arbiter. `req_en` is not a primary input:

| Requester | Eligible when |
|---|---|
| `req0` | class 0 credit is greater than 0 |
| `req1` | class 0 credit is greater than 0 |
| `req2` | class 1 credit is greater than 0 |
| `req3` | class 2 credit is greater than 0 |

A grant spends one credit from the winner's class after the grant is issued. `credit0`, `credit1`, and `credit2` each return one credit. A return and a spend on the same edge leave that class unchanged. Reset clears the mask and all three credit registers.

## Properties

These hold for this connection:

- No grant is issued without an asserted request.
- No grant is issued when that requester's credit class is empty.
- At most one grant is issued.
- The arbiter chooses fairly among the requesters that are eligible on that cycle.
- A requester with no credit does not block the others.

This does not hold:

- `req0` and `req1` fairly share class 0 while its credit keeps returning.

Eligibility at this top level is `req` and class credit greater than 0. A request that stays high is not, by itself, eligible.

## Counterexample

`rtl/tb_rr_arb_shared_credit.v` holds `req0`, `req1`, and `req2` high. It loads one class-1 credit, then returns a credit to class 0 or class 1 on every cycle that class is empty.

The compiled result over 30 cycles is `req0 = 15`, `req1 = 0`, `req2 = 15`. The cycle-by-cycle values are in `trace/rr-arbiter-shared-credit-trace.txt`. In the `gnt` column, bit 0 is `req0`, so `0100` grants `req2` and `0001` grants `req0`.

Cycle 1 grants `req2` and moves the mask above it. Cycle 2 has class-0 credit, so `req0` and `req1` are both eligible. The mask is above them, the scan wraps, and `req0` wins. Class 0 returns to empty. The pair then repeats, so the fairness bound never applies to `req1`.

## Run

Using Icarus Verilog from the repository root:

```
iverilog -g2012 -o sim.out rtl/rr_arb.v rtl/rr_arb_shared_credit.v rtl/tb_rr_arb_shared_credit.v
vvp sim.out
```

The testbench writes a new `rr-arbiter-shared-credit-trace.txt` in the current directory and prints `PASS` when the counts are 15, 0, and 15.
