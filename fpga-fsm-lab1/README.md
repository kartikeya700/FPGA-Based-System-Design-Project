# Sequence Detector & Mealy Digital Lock — Verilog RTL

Two finite-state-machine designs in Verilog-2001, verified with self-checking
testbenches that compare each design against an independent golden model on
every clock cycle.

Written for **FPGA System Design (EEE 314)**, BITS Pilani. Simulation-verified;
FPGA deployment is the next step (see [Deploying to hardware](#deploying-to-hardware)).

| | |
|---|---|
| Language | Verilog-2001 |
| Simulator | Icarus Verilog (any standard simulator works) |
| Verification | Self-checking testbenches, golden-model comparison, 6000+ random bits |
| Status | Both testbenches pass, 0 mismatches |

---

## Quick start

```bash
make            # runs both self-checking testbenches
```

```
PASS  4045 cycles checked, 0 mismatches
PASS  2042 cycles checked, 0 mismatches
```

Or individually:

```bash
iverilog -g2005 -o sim tb/tb_seq_detector.v rtl/seq_detector.v && vvp sim
iverilog -g2005 -o sim tb/tb_lock_fsm.v     rtl/lock_fsm.v     && vvp sim
```

Each run also writes a `.vcd` you can open in GTKWave.

---

## Configuration

Both designs take their target patterns from `rtl/config.vh`:

```verilog
`define SEQ_A     4'b1000    // Problem 1: pattern to detect
`define SEQ_B     4'b0001    // Problem 1: its reverse
`define PASSWORD  4'b0010    // Problem 2: 4-bit serial password
```

The RTL is fully parameterised — changing these three values changes what the
designs detect without touching any state logic. The same three constants are
mirrored at the top of each testbench; keep them in step.

The assignment derives them from a student ID: the digital root of the last
three digits gives `SEQ_A` (`SEQ_B` is its reverse, or its complement if
reversing gives the same value back), and the LSB of the BCD code of each of
the last four digits gives `PASSWORD`.

---

## Repository layout

```
rtl/
  config.vh            target patterns and clock constants
  clk_divider.v        tick enable + heartbeat
  seq_generator.v      on-chip test pattern source
  seq_detector.v       dual non-overlapping detector FSM
  top_seq_detector.v   detector + generator + divider, wired to LEDs
  piso.v               Parallel-In Serial-Out test password generator
  lock_fsm.v           Mealy lock FSM with lockout counter
  top_digital_lock.v   lock + PISO + divider, wired to LEDs
tb/
  tb_seq_detector.v    self-checking, golden model, 4000 random bits
  tb_lock_fsm.v        self-checking, golden model, 2000 random bits
docs/
  state_tables.md      full state transition tables for both designs
```

---

## Design 1 — dual non-overlapping sequence detector

Detects two 4-bit patterns — a target and its reverse — anywhere in a serial
bit stream, and reports a match on the cycle the fourth bit arrives.

**Non-overlap semantics.** Matching slides continuously: every new bit is
tested against the three bits before it, so a match is found wherever it
occurs, not only on aligned boundaries. When a match is declared the machine
restarts from empty — the matched bits are consumed and the *next* bit becomes
the first bit of a fresh attempt. Two reported matches can therefore never
share a bit.

**State encoding.** The state *is* the run of bits seen since the last
restart, capped at three. Fifteen states in two phases:

```
fill phase — entered only after reset or a hit

                    S  (empty)
                0 /        \ 1
               S0            S1
             /    \        /    \
          S00     S01    S10    S11

steady phase — the eight 3-bit history states

          S000 S001 S010 S011 S100 S101 S110 S111
```

In the steady phase the history just shifts: `S_abc --d--> S_bcd`, a de Bruijn
graph over three bits. The one exception is a hit, which sends the machine back
to `S`.

The tree and the shift are entirely independent of the target patterns — only
the output comparison uses them. That is why a different pattern pair needs no
restructuring: exactly two cells in the transition table move.

**Output is Mealy**, depending on the current history *and* the incoming bit,
so it asserts on the same tick the sequence completes rather than a cycle
later.

Full table in [`docs/state_tables.md`](docs/state_tables.md).

---

## Design 2 — Mealy digital lock

Detects a 4-bit serial password, unlocks on the final correct bit, and locks
out after three consecutive failures.

```
S0 --P3--> S1 --P2--> S2 --P1--> S3 --P0/unlock=1--> back to S0
 ^          |          |          |
 +----------+----------+----------+   any wrong bit, attempts++
                                        attempts == 3  ->  LOCKOUT
```

**Any wrong bit resets to `S0` immediately.** This is stricter than a textbook
detector, which would backtrack to the longest still-valid prefix. It is what
the specification calls for, and it makes an attempt fail the moment a bit is
wrong rather than after four bits have been consumed.

**There is no separate `UNLOCKED` state.** A Mealy machine asserts its output
on the transition itself; adding a state would burn a clock and desynchronise
the 4-bit framing. This was caught by the golden model during development.

`LOCKOUT` is left only via reset. A successful unlock clears the attempt
counter.

A `piso` module supplies test passwords: parallel-load, then shift out MSB
first, one bit per tick.

---

## Verification

Both testbenches are **self-checking with a golden model**. The design under
test is compared against an independent reference implementation on every
clock cycle; a mismatch prints an error and increments a counter, and the run
ends with a single PASS/FAIL line. No waveform inspection is needed to know
whether a design is correct.

The golden models are written at a deliberately different level of
abstraction. The detector's reference is a shift register, a saturating
counter and a comparison — no state enumeration at all, so an error in the
FSM's tree, its shift transitions or its output decode cannot hide in both
implementations. The lock's reference is a progress counter and an attempt
counter written straight from the specification.

The rule that makes this worth doing: **the golden model must come from the
specification, never from the RTL.** Copy the FSM's case statement into the
testbench and both copies contain the same bug, so the comparison always
passes and tells you nothing.

**Sampling discipline.** Stimulus is driven on the falling edge; Mealy outputs
are sampled at the rising edge, where the state registers still hold their
pre-edge values — the instant a Mealy output is defined for. Getting this
backwards produces an off-by-one that looks exactly like a broken FSM.

**Stimulus.** Directed vectors first — both target patterns, near misses,
back-to-back hits, matches deliberately placed at unaligned positions, the
full three-strike lockout path, and reset recovery — followed by a random
soak of several thousand bits.

---

## Deploying to hardware

The two `top_*.v` modules are ready for synthesis. They wire each FSM to a
clock divider and an on-chip stimulus source, and expose the result on LED
outputs. To run this on a board you will need to add a constraints file
mapping `clk`, `btn_rst`, the switches and `led[]` to physical pins for your
specific part, and set `CLK_HZ` in `rtl/config.vh` to your board's clock
frequency. No constraints file is included, since pin assignments are
board-specific.

**On the clock divider:** it emits a one-cycle enable pulse (`tick`) in the
original clock domain rather than generating a slow clock. Every register runs
on the input clock and advances only when `tick` is high. This avoids a second
clock domain, needs no additional timing constraints, and keeps static timing
analysis meaningful. The `slow_clk` output toggles purely to drive a
heartbeat LED and is never used as a clock — routing a divided clock through
general fabric is the classic mistake in designs like this.

Ports on `top_seq_detector`: `led[0]` serial input bit, `led[1]` detector
output, `led[2]` heartbeat, `sw_en` run/pause, `btn_rst` reset.

Ports on `top_digital_lock`: `led[0]` serial bit from the PISO, `led[1]`
unlock, `led[2]` lockout, `led[3]` heartbeat, `sw_en` enable, `sw_wrong`
feed a deliberately wrong password, `btn_rst` reset and the only exit from
`LOCKOUT`.

---

## Status

Coursework for EEE 314. The problem statements are from the course handout;
the state encodings, the tick-enable clock strategy and the golden-model
verification approach are my own.
