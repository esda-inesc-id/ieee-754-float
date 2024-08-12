
//
//     IEEE-754<DATA_W, EXP_W>
//
// |<----------DATA_W----------->|
// |_____ _________ _____________|
// |__S__|___EXP___|______F______|
// |     |         |             |
// |<-1->|<-EXP_W->|<----F_W---->|
//

`define BIAS   {1'b0, {(EXP_W-1){1'b1}}}
`define F_W    (DATA_W - EXP_W - 1'b1)
`define MAN_W  (F_W + 1'b1)

`define EXP_MAX {{(EXP_W-1){1'b1}}, 1'b0}
`define EXP_MIN {{(EXP_W-1){1'b0}}, 1'b1}
`define EXP_INF {EXP_W{1'b1}}
`define EXP_NAN {EXP_W{1'b1}}
`define EXP_SUB {EXP_W{1'b0}}

// Canonical NAN
`define NAN {1'b0, `EXP_NAN, 1'b1, {(DATA_W-EXP_W-2){1'b0}}}

// Infinite
`define INF(SIGN) {SIGN, `EXP_INF, {(DATA_W-EXP_W-1){1'b0}}}
