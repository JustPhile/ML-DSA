package NTT256_types;
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
  typedef logic [22:0] array_of_48_logic_vector_23 [0:47];
  typedef struct packed {
    logic [22:0] Mont3_sel0;
    logic [24:0] Mont3_sel1;
  } Mont3;
  typedef struct packed {
    logic [22:0] MulPartial2_sel0;
    logic [28:0] MulPartial2_sel1;
    logic [28:0] MulPartial2_sel2;
    logic [28:0] MulPartial2_sel3;
    logic [27:0] MulPartial2_sel4;
  } MulPartial2;
  typedef logic [29:0] array_of_8_logic_vector_30 [0:7];
  typedef struct packed {
    logic [22:0] MulPartial3_sel0;
    logic [34:0] MulPartial3_sel1;
    logic [33:0] MulPartial3_sel2;
  } MulPartial3;
  typedef struct packed {
    logic [22:0] Tuple2_0_sel0;
    logic [22:0] Tuple2_0_sel1;
  } Tuple2_0;
  typedef Tuple2_0  array_of_2_Tuple2_0 [0:1];
  typedef logic signed [63:0] array_of_256_signed_64 [0:255];
  typedef struct packed {
    logic [5:0] Tuple2_sel0;
    logic [22:0] Tuple2_sel1;
  } Tuple2;
  typedef logic [5:0] array_of_8_logic_vector_6 [0:7];
  typedef struct packed {
    logic CoeffControl_sel0;
    logic [2:0] CoeffControl_sel1;
    logic [5:0] CoeffControl_sel2;
    logic[0:7][5:0] CoeffControl_sel3;
    logic CoeffControl_sel4;
    logic CoeffControl_sel5;
    logic [5:0] CoeffControl_sel6;
    logic CoeffControl_sel7;
  } CoeffControl;
  typedef logic [22:0] array_of_8_logic_vector_23 [0:7];
  typedef struct packed {
    logic [22:0] Tuple3_sel0;
    logic [22:0] Tuple3_sel1;
    logic [22:0] Tuple3_sel2;
  } Tuple3;
  typedef struct packed {
    logic Tuple2_1_sel0;
    logic [4:0] Tuple2_1_sel1;
  } Tuple2_1;
  typedef Tuple3  array_of_2_Tuple3 [0:1];
  typedef logic [22:0] array_of_256_logic_vector_23 [0:255];
  typedef struct packed {
    logic Tuple2_2_sel0;
    logic[0:255][22:0] Tuple2_2_sel1;
  } Tuple2_2;
  typedef struct packed {
    logic [2:0] Tuple9_sel0;
    logic Tuple9_sel1;
    logic [2:0] Tuple9_sel2;
    logic [5:0] Tuple9_sel3;
    logic [5:0] Tuple9_sel4;
    logic [4:0] Tuple9_sel5;
    logic [4:0] Tuple9_sel6;
    logic[0:255][22:0] Tuple9_sel7;
    logic[0:255][22:0] Tuple9_sel8;
  } Tuple9;
  typedef struct packed {
    logic [2:0] NTTState_sel0;
    logic NTTState_sel1;
    logic [2:0] NTTState_sel2;
    logic [5:0] NTTState_sel3;
    logic [5:0] NTTState_sel4;
    logic [4:0] NTTState_sel5;
    logic [4:0] NTTState_sel6;
    logic[0:255][22:0] NTTState_sel7;
    logic[0:255][22:0] NTTState_sel8;
  } NTTState;
  typedef struct packed {
    logic [22:0] Tuple2_3_sel0;
    logic [45:0] Tuple2_3_sel1;
  } Tuple2_3;
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
  function automatic logic [0:47][22:0] array_of_48_logic_vector_23_to_lv(array_of_48_logic_vector_23 i);
    for (int n = 0; n < 48; n=n+1)
      array_of_48_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_48_logic_vector_23 array_of_48_logic_vector_23_from_lv(logic [0:47][22:0] i);
    for (int n = 0; n < 48; n=n+1)
      array_of_48_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_48_logic_vector_23 array_of_48_logic_vector_23_cons(logic [22:0] x,logic [22:0] xs [0:46]);
    array_of_48_logic_vector_23_cons[0] = x;
    array_of_48_logic_vector_23_cons[1:47] = xs;
  endfunction
  function automatic logic [0:7][29:0] array_of_8_logic_vector_30_to_lv(array_of_8_logic_vector_30 i);
    for (int n = 0; n < 8; n=n+1)
      array_of_8_logic_vector_30_to_lv[n] = i[n];
  endfunction
  function automatic array_of_8_logic_vector_30 array_of_8_logic_vector_30_from_lv(logic [0:7][29:0] i);
    for (int n = 0; n < 8; n=n+1)
      array_of_8_logic_vector_30_from_lv[n] = i[n];
  endfunction
  function automatic array_of_8_logic_vector_30 array_of_8_logic_vector_30_cons(logic [29:0] x,logic [29:0] xs [0:6]);
    array_of_8_logic_vector_30_cons[0] = x;
    array_of_8_logic_vector_30_cons[1:7] = xs;
  endfunction
  function automatic logic [0:1][45:0] array_of_2_Tuple2_0_to_lv(array_of_2_Tuple2_0 i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_Tuple2_0_to_lv[n] = i[n];
  endfunction
  function automatic array_of_2_Tuple2_0 array_of_2_Tuple2_0_from_lv(logic [0:1][45:0] i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_Tuple2_0_from_lv[n] = i[n];
  endfunction
  function automatic array_of_2_Tuple2_0 array_of_2_Tuple2_0_cons(Tuple2_0 x,Tuple2_0  xs [0:0]);
    array_of_2_Tuple2_0_cons[0] = x;
    array_of_2_Tuple2_0_cons[1:1] = xs;
  endfunction
  function automatic logic [0:255][63:0] array_of_256_signed_64_to_lv(array_of_256_signed_64 i);
    for (int n = 0; n < 256; n=n+1)
      array_of_256_signed_64_to_lv[n] = i[n];
  endfunction
  function automatic array_of_256_signed_64 array_of_256_signed_64_from_lv(logic [0:255][63:0] i);
    for (int n = 0; n < 256; n=n+1)
      array_of_256_signed_64_from_lv[n] = i[n];
  endfunction
  function automatic array_of_256_signed_64 array_of_256_signed_64_cons(logic signed [63:0] x,logic signed [63:0] xs [0:254]);
    array_of_256_signed_64_cons[0] = x;
    array_of_256_signed_64_cons[1:255] = xs;
  endfunction
  function automatic logic [0:7][5:0] array_of_8_logic_vector_6_to_lv(array_of_8_logic_vector_6 i);
    for (int n = 0; n < 8; n=n+1)
      array_of_8_logic_vector_6_to_lv[n] = i[n];
  endfunction
  function automatic array_of_8_logic_vector_6 array_of_8_logic_vector_6_from_lv(logic [0:7][5:0] i);
    for (int n = 0; n < 8; n=n+1)
      array_of_8_logic_vector_6_from_lv[n] = i[n];
  endfunction
  function automatic array_of_8_logic_vector_6 array_of_8_logic_vector_6_cons(logic [5:0] x,logic [5:0] xs [0:6]);
    array_of_8_logic_vector_6_cons[0] = x;
    array_of_8_logic_vector_6_cons[1:7] = xs;
  endfunction
  function automatic logic [0:7][22:0] array_of_8_logic_vector_23_to_lv(array_of_8_logic_vector_23 i);
    for (int n = 0; n < 8; n=n+1)
      array_of_8_logic_vector_23_to_lv[n] = i[n];
  endfunction
  function automatic array_of_8_logic_vector_23 array_of_8_logic_vector_23_from_lv(logic [0:7][22:0] i);
    for (int n = 0; n < 8; n=n+1)
      array_of_8_logic_vector_23_from_lv[n] = i[n];
  endfunction
  function automatic array_of_8_logic_vector_23 array_of_8_logic_vector_23_cons(logic [22:0] x,logic [22:0] xs [0:6]);
    array_of_8_logic_vector_23_cons[0] = x;
    array_of_8_logic_vector_23_cons[1:7] = xs;
  endfunction
  function automatic logic [0:1][68:0] array_of_2_Tuple3_to_lv(array_of_2_Tuple3 i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_Tuple3_to_lv[n] = i[n];
  endfunction
  function automatic array_of_2_Tuple3 array_of_2_Tuple3_from_lv(logic [0:1][68:0] i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_Tuple3_from_lv[n] = i[n];
  endfunction
  function automatic array_of_2_Tuple3 array_of_2_Tuple3_cons(Tuple3 x,Tuple3  xs [0:0]);
    array_of_2_Tuple3_cons[0] = x;
    array_of_2_Tuple3_cons[1:1] = xs;
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
endpackage : NTT256_types

