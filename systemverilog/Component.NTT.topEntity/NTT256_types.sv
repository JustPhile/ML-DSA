package NTT256_types;
  typedef logic [22:0] array_of_24_logic_vector_23 [0:23];
  typedef struct packed {
    logic [22:0] Mont2_sel0;
    logic [21:0] Mont2_sel1;
    logic [23:0] Mont2_sel2;
    logic [25:0] Mont2_sel3;
    logic [23:0] Mont2_sel4;
  } Mont2;
  typedef struct packed {
    logic [22:0] MulPartial1_sel0;
    logic [25:0] MulPartial1_sel1;
    logic [25:0] MulPartial1_sel2;
    logic [25:0] MulPartial1_sel3;
    logic [25:0] MulPartial1_sel4;
    logic [25:0] MulPartial1_sel5;
    logic [25:0] MulPartial1_sel6;
    logic [25:0] MulPartial1_sel7;
    logic [24:0] MulPartial1_sel8;
  } MulPartial1;
  typedef logic [22:0] array_of_16_logic_vector_23 [0:15];
  typedef struct packed {
    logic [22:0] MulPartial2_sel0;
    logic [28:0] MulPartial2_sel1;
    logic [28:0] MulPartial2_sel2;
    logic [28:0] MulPartial2_sel3;
    logic [27:0] MulPartial2_sel4;
  } MulPartial2;
  typedef struct packed {
    logic [22:0] Mont3_sel0;
    logic [24:0] Mont3_sel1;
  } Mont3;
  typedef logic signed [63:0] array_of_4_signed_64 [0:3];
  typedef struct packed {
    logic [22:0] MulPartial3_sel0;
    logic [34:0] MulPartial3_sel1;
    logic [33:0] MulPartial3_sel2;
  } MulPartial3;
  typedef struct packed {
    logic [22:0] Tuple2_0_sel0;
    logic [22:0] Tuple2_0_sel1;
  } Tuple2_0;
  typedef Tuple2_0  array_of_4_Tuple2_0 [0:3];
  typedef struct packed {
    logic [3:0] Tuple2_1_sel0;
    logic [22:0] Tuple2_1_sel1;
  } Tuple2_1;
  typedef Tuple2_1  array_of_16_Tuple2_1 [0:15];
  typedef struct packed {
    logic [22:0] Tuple3_sel0;
    logic [22:0] Tuple3_sel1;
    logic [22:0] Tuple3_sel2;
  } Tuple3;
  typedef Tuple3  array_of_4_Tuple3 [0:3];
  typedef struct packed {
    logic [4:0] Tuple2_sel0;
    logic [22:0] Tuple2_sel1;
  } Tuple2;
  typedef logic [22:0] array_of_4_logic_vector_23 [0:3];
  typedef logic [0:3][22:0] array_of_4_array_of_4_logic_vector_23 [0:3];
  typedef logic [7:0] array_of_4_logic_vector_8 [0:3];
  typedef logic [28:0] array_of_16_logic_vector_29 [0:15];
  typedef logic [22:0] array_of_256_logic_vector_23 [0:255];
  typedef struct packed {
    logic [2:0] NTTState_sel0;
    logic NTTState_sel1;
    logic [2:0] NTTState_sel2;
    logic [4:0] NTTState_sel3;
    logic [5:0] NTTState_sel4;
    logic [3:0] NTTState_sel5;
    logic [3:0] NTTState_sel6;
    logic[0:255][22:0] NTTState_sel7;
    logic[0:255][22:0] NTTState_sel8;
  } NTTState;
  typedef struct packed {
    logic Tuple2_3_sel0;
    logic[0:255][22:0] Tuple2_3_sel1;
  } Tuple2_3;
  typedef logic [0:255][22:0] array_of_16_array_of_256_logic_vector_23 [0:15];
  typedef logic [0:255][22:0] array_of_17_array_of_256_logic_vector_23 [0:16];
  typedef struct packed {
    logic [22:0] Tuple2_4_sel0;
    logic [45:0] Tuple2_4_sel1;
  } Tuple2_4;
  typedef struct packed {
    logic [22:0] Mont1_sel0;
    logic [45:0] Mont1_sel1;
    logic [23:0] Mont1_sel2;
  } Mont1;
  typedef struct packed {
    logic [22:0] Mont3Low_sel0;
    logic [24:0] Mont3Low_sel1;
    logic [1:0] Mont3Low_sel2;
  } Mont3Low;
  typedef struct packed {
    logic Tuple2_2_sel0;
    logic [3:0] Tuple2_2_sel1;
  } Tuple2_2;
  typedef struct packed {
    logic [2:0] Tuple9_sel0;
    logic Tuple9_sel1;
    logic [2:0] Tuple9_sel2;
    logic [4:0] Tuple9_sel3;
    logic [5:0] Tuple9_sel4;
    logic [3:0] Tuple9_sel5;
    logic [3:0] Tuple9_sel6;
    logic[0:255][22:0] Tuple9_sel7;
    logic[0:255][22:0] Tuple9_sel8;
  } Tuple9;
  typedef logic [4:0] array_of_16_logic_vector_5 [0:15];
  typedef struct packed {
    logic CoeffControl_sel0;
    logic [2:0] CoeffControl_sel1;
    logic [4:0] CoeffControl_sel2;
    logic[0:15][4:0] CoeffControl_sel3;
    logic CoeffControl_sel4;
    logic CoeffControl_sel5;
    logic [4:0] CoeffControl_sel6;
    logic CoeffControl_sel7;
  } CoeffControl;
  typedef logic [3:0] array_of_16_logic_vector_4 [0:15];
  function automatic logic [0:23][22:0] array_of_24_logic_vector_23_to_lv(array_of_24_logic_vector_23 i);
    for (int n = 0; n < 24; n=n+1)
      array_of_24_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_24_logic_vector_23 array_of_24_logic_vector_23_from_lv(logic [0:23][22:0] i);
    for (int n = 0; n < 24; n=n+1)
      array_of_24_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_24_logic_vector_23 array_of_24_logic_vector_23_cons(logic [22:0] x,logic [22:0] xs [0:22]);
    array_of_24_logic_vector_23_cons[0] = x;
    array_of_24_logic_vector_23_cons[1:23] = xs;
  endfunction
  function automatic logic [0:15][22:0] array_of_16_logic_vector_23_to_lv(array_of_16_logic_vector_23 i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_16_logic_vector_23 array_of_16_logic_vector_23_from_lv(logic [0:15][22:0] i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_16_logic_vector_23 array_of_16_logic_vector_23_cons(logic [22:0] x,logic [22:0] xs [0:14]);
    array_of_16_logic_vector_23_cons[0] = x;
    array_of_16_logic_vector_23_cons[1:15] = xs;
  endfunction
  function automatic logic [0:3][63:0] array_of_4_signed_64_to_lv(array_of_4_signed_64 i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_signed_64_to_lv[n] = i[n];
  endfunction
  function automatic array_of_4_signed_64 array_of_4_signed_64_from_lv(logic [0:3][63:0] i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_signed_64_from_lv[n] = i[n];
  endfunction
  function automatic array_of_4_signed_64 array_of_4_signed_64_cons(logic signed [63:0] x,logic signed [63:0] xs [0:2]);
    array_of_4_signed_64_cons[0] = x;
    array_of_4_signed_64_cons[1:3] = xs;
  endfunction
  function automatic logic [0:3][45:0] array_of_4_Tuple2_0_to_lv(array_of_4_Tuple2_0 i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_Tuple2_0_to_lv[n] = i[n];
  endfunction
  function automatic array_of_4_Tuple2_0 array_of_4_Tuple2_0_from_lv(logic [0:3][45:0] i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_Tuple2_0_from_lv[n] = i[n];
  endfunction
  function automatic array_of_4_Tuple2_0 array_of_4_Tuple2_0_cons(Tuple2_0 x,Tuple2_0  xs [0:2]);
    array_of_4_Tuple2_0_cons[0] = x;
    array_of_4_Tuple2_0_cons[1:3] = xs;
  endfunction
  function automatic logic [0:15][26:0] array_of_16_Tuple2_1_to_lv(array_of_16_Tuple2_1 i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_Tuple2_1_to_lv[n] = i[n];
  endfunction
  function automatic array_of_16_Tuple2_1 array_of_16_Tuple2_1_from_lv(logic [0:15][26:0] i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_Tuple2_1_from_lv[n] = i[n];
  endfunction
  function automatic array_of_16_Tuple2_1 array_of_16_Tuple2_1_cons(Tuple2_1 x,Tuple2_1  xs [0:14]);
    array_of_16_Tuple2_1_cons[0] = x;
    array_of_16_Tuple2_1_cons[1:15] = xs;
  endfunction
  function automatic logic [0:3][68:0] array_of_4_Tuple3_to_lv(array_of_4_Tuple3 i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_Tuple3_to_lv[n] = i[n];
  endfunction
  function automatic array_of_4_Tuple3 array_of_4_Tuple3_from_lv(logic [0:3][68:0] i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_Tuple3_from_lv[n] = i[n];
  endfunction
  function automatic array_of_4_Tuple3 array_of_4_Tuple3_cons(Tuple3 x,Tuple3  xs [0:2]);
    array_of_4_Tuple3_cons[0] = x;
    array_of_4_Tuple3_cons[1:3] = xs;
  endfunction
  function automatic logic [0:3][22:0] array_of_4_logic_vector_23_to_lv(array_of_4_logic_vector_23 i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_4_logic_vector_23 array_of_4_logic_vector_23_from_lv(logic [0:3][22:0] i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_4_logic_vector_23 array_of_4_logic_vector_23_cons(logic [22:0] x,logic [22:0] xs [0:2]);
    array_of_4_logic_vector_23_cons[0] = x;
    array_of_4_logic_vector_23_cons[1:3] = xs;
  endfunction
  function automatic logic [0:3][91:0] array_of_4_array_of_4_logic_vector_23_to_lv(array_of_4_array_of_4_logic_vector_23 i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_array_of_4_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_4_array_of_4_logic_vector_23 array_of_4_array_of_4_logic_vector_23_from_lv(logic [0:3][91:0] i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_array_of_4_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_4_array_of_4_logic_vector_23 array_of_4_array_of_4_logic_vector_23_cons(array_of_4_logic_vector_23 x,logic [0:3][22:0] xs [0:2]);
    array_of_4_array_of_4_logic_vector_23_cons[0] = {array_of_4_logic_vector_23_to_lv(x)};
    array_of_4_array_of_4_logic_vector_23_cons[1:3] = xs;
  endfunction
  function automatic logic [0:3][7:0] array_of_4_logic_vector_8_to_lv(array_of_4_logic_vector_8 i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_logic_vector_8_to_lv[n] = i[n];
  endfunction
  function automatic array_of_4_logic_vector_8 array_of_4_logic_vector_8_from_lv(logic [0:3][7:0] i);
    for (int n = 0; n < 4; n=n+1)
      array_of_4_logic_vector_8_from_lv[n] = i[n];
  endfunction
  function automatic array_of_4_logic_vector_8 array_of_4_logic_vector_8_cons(logic [7:0] x,logic [7:0] xs [0:2]);
    array_of_4_logic_vector_8_cons[0] = x;
    array_of_4_logic_vector_8_cons[1:3] = xs;
  endfunction
  function automatic logic [0:15][28:0] array_of_16_logic_vector_29_to_lv(array_of_16_logic_vector_29 i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_logic_vector_29_to_lv[n] = i[n];
  endfunction
  function automatic array_of_16_logic_vector_29 array_of_16_logic_vector_29_from_lv(logic [0:15][28:0] i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_logic_vector_29_from_lv[n] = i[n];
  endfunction
  function automatic array_of_16_logic_vector_29 array_of_16_logic_vector_29_cons(logic [28:0] x,logic [28:0] xs [0:14]);
    array_of_16_logic_vector_29_cons[0] = x;
    array_of_16_logic_vector_29_cons[1:15] = xs;
  endfunction
  function automatic logic [0:255][22:0] array_of_256_logic_vector_23_to_lv(array_of_256_logic_vector_23 i);
    for (int n = 0; n < 256; n=n+1)
      array_of_256_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_256_logic_vector_23 array_of_256_logic_vector_23_from_lv(logic [0:255][22:0] i);
    for (int n = 0; n < 256; n=n+1)
      array_of_256_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_256_logic_vector_23 array_of_256_logic_vector_23_cons(logic [22:0] x,logic [22:0] xs [0:254]);
    array_of_256_logic_vector_23_cons[0] = x;
    array_of_256_logic_vector_23_cons[1:255] = xs;
  endfunction
  function automatic logic [0:15][5887:0] array_of_16_array_of_256_logic_vector_23_to_lv(array_of_16_array_of_256_logic_vector_23 i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_array_of_256_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_16_array_of_256_logic_vector_23 array_of_16_array_of_256_logic_vector_23_from_lv(logic [0:15][5887:0] i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_array_of_256_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_16_array_of_256_logic_vector_23 array_of_16_array_of_256_logic_vector_23_cons(array_of_256_logic_vector_23 x,logic [0:255][22:0] xs [0:14]);
    array_of_16_array_of_256_logic_vector_23_cons[0] = {array_of_256_logic_vector_23_to_lv(x)};
    array_of_16_array_of_256_logic_vector_23_cons[1:15] = xs;
  endfunction
  function automatic logic [0:16][5887:0] array_of_17_array_of_256_logic_vector_23_to_lv(array_of_17_array_of_256_logic_vector_23 i);
    for (int n = 0; n < 17; n=n+1)
      array_of_17_array_of_256_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_17_array_of_256_logic_vector_23 array_of_17_array_of_256_logic_vector_23_from_lv(logic [0:16][5887:0] i);
    for (int n = 0; n < 17; n=n+1)
      array_of_17_array_of_256_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_17_array_of_256_logic_vector_23 array_of_17_array_of_256_logic_vector_23_cons(array_of_256_logic_vector_23 x,logic [0:255][22:0] xs [0:15]);
    array_of_17_array_of_256_logic_vector_23_cons[0] = {array_of_256_logic_vector_23_to_lv(x)};
    array_of_17_array_of_256_logic_vector_23_cons[1:16] = xs;
  endfunction
  function automatic logic [0:15][4:0] array_of_16_logic_vector_5_to_lv(array_of_16_logic_vector_5 i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_logic_vector_5_to_lv[n] = i[n];
  endfunction
  function automatic array_of_16_logic_vector_5 array_of_16_logic_vector_5_from_lv(logic [0:15][4:0] i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_logic_vector_5_from_lv[n] = i[n];
  endfunction
  function automatic array_of_16_logic_vector_5 array_of_16_logic_vector_5_cons(logic [4:0] x,logic [4:0] xs [0:14]);
    array_of_16_logic_vector_5_cons[0] = x;
    array_of_16_logic_vector_5_cons[1:15] = xs;
  endfunction
  function automatic logic [0:15][3:0] array_of_16_logic_vector_4_to_lv(array_of_16_logic_vector_4 i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_logic_vector_4_to_lv[n] = i[n];
  endfunction
  function automatic array_of_16_logic_vector_4 array_of_16_logic_vector_4_from_lv(logic [0:15][3:0] i);
    for (int n = 0; n < 16; n=n+1)
      array_of_16_logic_vector_4_from_lv[n] = i[n];
  endfunction
  function automatic array_of_16_logic_vector_4 array_of_16_logic_vector_4_cons(logic [3:0] x,logic [3:0] xs [0:14]);
    array_of_16_logic_vector_4_cons[0] = x;
    array_of_16_logic_vector_4_cons[1:15] = xs;
  endfunction
endpackage : NTT256_types

