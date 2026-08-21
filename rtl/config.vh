`ifndef CONFIG_VH
`define CONFIG_VH

// =====================================================================
//  All ID-dependent constants live here. Nothing else needs editing.
//  Values below are derived from ID digits 0674.

// =====================================================================

// --- Problem 1: last three digits -> digital root -> 4-bit binary ----
`define SEQ_A     4'b1000    // 674 -> 6+7+4=17 -> 1+7=8 -> 1000
`define SEQ_B     4'b0001    // reverse of SEQ_A

// --- Problem 2: LSB of the BCD code of each of the last four digits --
`define PASSWORD  4'b0010    // 0674 -> BCD LSBs 0,0,1,0

// --- Only relevant when synthesising the top modules ----------------
`define CLK_HZ    100_000_000   // only used by the top modules, for deployment
`define TICK_HZ   2             // visible LED update rate

`endif
