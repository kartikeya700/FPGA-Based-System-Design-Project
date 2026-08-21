# State transition tables

Values from `rtl/config.vh`: `SEQ_A = 1000`, `SEQ_B = 0001`,
`PASSWORD = 0010`.

## Problem 1 — sequence detector (Mealy, 15 states)

The state is the run of bits seen since the last restart, capped at three.

### Fill phase — entered only after reset or a hit

| Present state | Bits held | din=0 | din=1 | Z |
|---|---|---|---|---|
| S   | –  | S0   | S1   | 0 |
| S0  | 0  | S00  | S01  | 0 |
| S1  | 1  | S10  | S11  | 0 |
| S00 | 00 | S000 | S001 | 0 |
| S01 | 01 | S010 | S011 | 0 |
| S10 | 10 | S100 | S101 | 0 |
| S11 | 11 | S110 | S111 | 0 |

`Z` is always 0 here: fewer than four bits have arrived, so no match can be
declared yet.

### Steady phase — history shifts, `S_abc --d--> S_bcd`, except on a hit

| Present state | Window on din=0 | Next (din=0) | Z | Window on din=1 | Next (din=1) | Z |
|---|---|---|---|---|---|---|
| S000 | 0000 | S000 | 0 | 0001 | **S** | **1** |
| S001 | 0010 | S010 | 0 | 0011 | S011 | 0 |
| S010 | 0100 | S100 | 0 | 0101 | S101 | 0 |
| S011 | 0110 | S110 | 0 | 0111 | S111 | 0 |
| S100 | 1000 | **S** | **1** | 1001 | S001 | 0 |
| S101 | 1010 | S010 | 0 | 1011 | S011 | 0 |
| S110 | 1100 | S100 | 0 | 1101 | S101 | 0 |
| S111 | 1110 | S110 | 0 | 1111 | S111 | 0 |

Exactly two rows carry `Z = 1`: the transition completing `SEQ_A` and the one
completing `SEQ_B`. Both return to `S`, so the matched bits are consumed and
the next bit starts a fresh attempt — this is the non-overlap rule. For a
different ID only those two cells move; the graph is unchanged.

## Problem 2 — digital lock (Mealy, 5 states)

`P = P3 P2 P1 P0 = 0 0 1 0`, consumed MSB first. `U` = unlock.

| Present state | Condition | Next state | U | Attempt counter |
|---|---|---|---|---|
| S0      | din == P3 = 0 | S1      | 0 | unchanged |
| S0      | din != P3 (din=1) | S0      | 0 | +1 |
| S1      | din == P2 = 0 | S2      | 0 | unchanged |
| S1      | din != P2 (din=1) | S0      | 0 | +1 |
| S2      | din == P1 = 1 | S3      | 0 | unchanged |
| S2      | din != P1 (din=0) | S0      | 0 | +1 |
| S3      | din == P0 = 0 | S0      | 1 | cleared to 0 |
| S3      | din != P0 (din=1) | S0      | 0 | +1 |
| LOCKOUT | any       | LOCKOUT | 0 | frozen |

When the counter would increment past 2, the next state is `LOCKOUT` instead
of `S0`. `LOCKOUT` is left only by asserting the asynchronous reset.
