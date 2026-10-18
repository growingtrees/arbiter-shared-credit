# RTL Properties

The product is the properties. You use your own AI coding tool, such as Cursor or Codex, and your own RTL. Import the properties and ask your tool to compare them with that RTL. The useful result is a counterexample.

Verilog is the recommended RTL input. An in-house language can hide quirks that an AI tool will misread. Exporting that source to `.v` files gives the tool the design in a form it can follow. A simulator is not part of the review.

A property states what the design must do. Start from a general property for that kind of block. Keep it, change the wording for your design, or set it aside.

This repository demonstrates the properties with one small design. It does not include an AI tool. The design is a round-robin arbiter whose local grants are correct, while one request is never granted. The diagram below was drawn while preparing the example. Generating that picture is not part of using the properties.

![Shared class credit trace](diagram/shared-credit.svg)

## Flow

1. Take the properties for that kind of block. One example: a request that stays asserted is eventually granted while the credit it needs continues to be supplied.
2. Change a property where your design is allowed to behave differently.
3. Import the properties into your own AI coding tool.
4. Point that tool at your RTL. Use Verilog `.v` files when the original source is an in-house language.
5. Ask your tool to compare the properties with the RTL.
6. If a property fails, your tool returns a counterexample.

No AI tool, simulator, or verification environment is included.

## Try it in your tool

Open the `rtl` folder in your own AI coding tool. Paste this property and ask the tool to compare it with `rr_arb.v` and `rr_arb_shared_credit.v`:

```text
Property: a request that stays asserted is eventually granted while its credit continues to be supplied.

req0 and req1 share class 0. req2 has class 1. A class is refilled on every cycle it is empty. req0, req1, and req2 stay asserted.

Compare this property with the RTL. If it fails, give a counterexample.
```

The failure is specific. Class 0 credit keeps returning, `req1` stays asserted, and the grants are `req2`, then `req0`, and that pair continues. `req1` receives no grant.

## This example

`req0` and `req1` share one credit pool. `req2` has a credit pool of its own. Both pools are refilled on every cycle they are empty. The arbiter grants `req2`, then `req0`, and that pair repeats. `req1` stays asserted, and it is eligible on every class-0 cycle, but it never receives a grant.

The properties that hold:

- No grant without an eligible request.
- No grant when that requester's credit is empty.
- At most one grant.
- Round-robin among the requesters that are eligible on that cycle.
- A requester with no credit does not prevent a grant to an eligible requester.

The property that fails:

- A request that stays asserted is eventually granted while its credit continues to be supplied.

`req1` stays asserted and class-0 credit keeps returning. The two-cycle loop never grants `req1`.

## Design

`rtl/rr_arb.v` is a four-requester round-robin arbiter. A request is eligible when `req` and `req_en` are both high. The grant is combinational and one-hot. The round-robin pointer advances when a grant is issued. After the highest index wins, the pointer wraps and the next grant is the lowest eligible requester.

`rtl/rr_arb_shared_credit.v` instantiates that arbiter. `req_en` comes from the credit registers:

| Requester | Eligible when |
|---|---|
| `req0` | class 0 credit is greater than 0 |
| `req1` | class 0 credit is greater than 0 |
| `req2` | class 1 credit is greater than 0 |
| `req3` | class 2 credit is greater than 0 |

A grant spends one credit from that class. `credit0`, `credit1`, and `credit2` each return one credit. A return and a spend on the same edge leave that class unchanged. Reset clears the pointer and all three credit registers.

## Counterexample

`rtl/tb_rr_arb_shared_credit.v` holds `req0`, `req1`, and `req2` high. It loads one class-1 credit, then returns a credit to class 0 or class 1 on every cycle that class is empty.

The compiled result over 30 cycles is `req0 = 15`, `req1 = 0`, `req2 = 15`. The cycle values are in `trace/rr-arbiter-shared-credit-trace.txt`. In the `gnt` column, bit 0 is `req0`, so `0100` grants `req2` and `0001` grants `req0`.

Cycle 1 grants `req2` and moves the pointer above it. Cycle 2 has class-0 credit, so `req0` and `req1` are both eligible. The pointer is above them, the scan wraps, and `req0` is granted. Class 0 is empty again. The same two cycles repeat.

## How this diagram was produced

The review flow above does not use a simulator. The picture in this repository was drawn from a trace generated while preparing the example. To regenerate that trace with Icarus Verilog, from the repository root:

```
iverilog -g2012 -o sim.out rtl/rr_arb.v rtl/rr_arb_shared_credit.v rtl/tb_rr_arb_shared_credit.v
vvp sim.out
```

The testbench writes a new `rr-arbiter-shared-credit-trace.txt` in the current directory and prints `PASS` when the counts are 15, 0, and 15.
