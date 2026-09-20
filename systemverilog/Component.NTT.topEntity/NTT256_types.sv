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
  typedef struct packed {
    logic [22:0] MulPartial3_sel0;
    logic [34:0] MulPartial3_sel1;
    logic [33:0] MulPartial3_sel2;
  } MulPartial3;
  typedef struct packed {
    logic [22:0] Tuple2_sel0;
    logic [22:0] Tuple2_sel1;
  } Tuple2;
  typedef Tuple2  array_of_2_Tuple2 [0:1];
  typedef logic [0:0] array_of_2_logic_vector_1 [0:1];
  typedef logic signed [63:0] array_of_256_signed_64 [0:255];
  typedef struct packed {
    logic [22:0] Tuple3_sel0;
    logic [22:0] Tuple3_sel1;
    logic [22:0] Tuple3_sel2;
  } Tuple3;
  typedef Tuple3  array_of_2_Tuple3 [0:1];
  typedef struct packed {
    logic ReadRequest_sel0;
    logic [7:0] ReadRequest_sel1;
    logic [7:0] ReadRequest_sel2;
    logic [7:0] ReadRequest_sel3;
    logic ReadRequest_sel4;
  } ReadRequest;
  typedef ReadRequest  array_of_2_ReadRequest [0:1];
  typedef struct packed {
    logic ButterflyPacket_sel0;
    logic [7:0] ButterflyPacket_sel1;
    logic [7:0] ButterflyPacket_sel2;
    logic [22:0] ButterflyPacket_sel3;
    logic [22:0] ButterflyPacket_sel4;
    logic [22:0] ButterflyPacket_sel5;
    logic ButterflyPacket_sel6;
  } ButterflyPacket;
  typedef ButterflyPacket  array_of_2_ButterflyPacket [0:1];
  typedef struct packed {
    logic Tuple4_sel0;
    logic [7:0] Tuple4_sel1;
    logic [7:0] Tuple4_sel2;
    logic Tuple4_sel3;
  } Tuple4;
  typedef Tuple4  array_of_2_Tuple4 [0:1];
  typedef struct packed {
    logic ButterflyResponse_sel0;
    logic [7:0] ButterflyResponse_sel1;
    logic [7:0] ButterflyResponse_sel2;
    logic [22:0] ButterflyResponse_sel3;
    logic [22:0] ButterflyResponse_sel4;
    logic ButterflyResponse_sel5;
  } ButterflyResponse;
  typedef struct packed {
    logic [8:0] Tuple2_1_sel0;
    logic [8:0] Tuple2_1_sel1;
  } Tuple2_1;
  typedef logic [22:0] array_of_256_logic_vector_23 [0:255];
  typedef struct packed {
    logic Tuple2_0_sel0;
    logic[0:255][22:0] Tuple2_0_sel1;
  } Tuple2_0;
  typedef struct packed {
    logic [1:0] NTTState_sel0;
    logic NTTState_sel1;
    logic [2:0] NTTState_sel2;
    logic [7:0] NTTState_sel3;
    logic NTTState_sel4;
    logic[0:255][22:0] NTTState_sel5;
    logic[0:255][22:0] NTTState_sel6;
  } NTTState;
  typedef struct packed {
    logic [22:0] Tuple2_2_sel0;
    logic [45:0] Tuple2_2_sel1;
  } Tuple2_2;
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
  typedef ButterflyResponse  array_of_2_ButterflyResponse [0:1];
  function automatic logic [0:1][45:0] array_of_2_Tuple2_to_lv(array_of_2_Tuple2 i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_Tuple2_to_lv[n] = i[n];
  endfunction
  function automatic array_of_2_Tuple2 array_of_2_Tuple2_from_lv(logic [0:1][45:0] i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_Tuple2_from_lv[n] = i[n];
  endfunction
  function automatic array_of_2_Tuple2 array_of_2_Tuple2_cons(Tuple2 x,Tuple2  xs [0:0]);
    array_of_2_Tuple2_cons[0] = x;
    array_of_2_Tuple2_cons[1:1] = xs;
  endfunction
  function automatic logic [0:1][0:0] array_of_2_logic_vector_1_to_lv(array_of_2_logic_vector_1 i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_logic_vector_1_to_lv[n] = i[n];
  endfunction
  function automatic array_of_2_logic_vector_1 array_of_2_logic_vector_1_from_lv(logic [0:1][0:0] i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_logic_vector_1_from_lv[n] = i[n];
  endfunction
  function automatic array_of_2_logic_vector_1 array_of_2_logic_vector_1_cons(logic [0:0] x,logic [0:0] xs [0:0]);
    array_of_2_logic_vector_1_cons[0] = x;
    array_of_2_logic_vector_1_cons[1:1] = xs;
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
  function automatic logic [0:1][25:0] array_of_2_ReadRequest_to_lv(array_of_2_ReadRequest i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_ReadRequest_to_lv[n] = i[n];
  endfunction
  function automatic array_of_2_ReadRequest array_of_2_ReadRequest_from_lv(logic [0:1][25:0] i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_ReadRequest_from_lv[n] = i[n];
  endfunction
  function automatic array_of_2_ReadRequest array_of_2_ReadRequest_cons(ReadRequest x,ReadRequest  xs [0:0]);
    array_of_2_ReadRequest_cons[0] = x;
    array_of_2_ReadRequest_cons[1:1] = xs;
  endfunction
  function automatic logic [0:1][86:0] array_of_2_ButterflyPacket_to_lv(array_of_2_ButterflyPacket i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_ButterflyPacket_to_lv[n] = i[n];
  endfunction
  function automatic array_of_2_ButterflyPacket array_of_2_ButterflyPacket_from_lv(logic [0:1][86:0] i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_ButterflyPacket_from_lv[n] = i[n];
  endfunction
  function automatic array_of_2_ButterflyPacket array_of_2_ButterflyPacket_cons(ButterflyPacket x,ButterflyPacket  xs [0:0]);
    array_of_2_ButterflyPacket_cons[0] = x;
    array_of_2_ButterflyPacket_cons[1:1] = xs;
  endfunction
  function automatic logic [0:1][17:0] array_of_2_Tuple4_to_lv(array_of_2_Tuple4 i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_Tuple4_to_lv[n] = i[n];
  endfunction
  function automatic array_of_2_Tuple4 array_of_2_Tuple4_from_lv(logic [0:1][17:0] i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_Tuple4_from_lv[n] = i[n];
  endfunction
  function automatic array_of_2_Tuple4 array_of_2_Tuple4_cons(Tuple4 x,Tuple4  xs [0:0]);
    array_of_2_Tuple4_cons[0] = x;
    array_of_2_Tuple4_cons[1:1] = xs;
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
  function automatic logic [0:1][63:0] array_of_2_ButterflyResponse_to_lv(array_of_2_ButterflyResponse i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_ButterflyResponse_to_lv[n] = i[n];
  endfunction
  function automatic array_of_2_ButterflyResponse array_of_2_ButterflyResponse_from_lv(logic [0:1][63:0] i);
    for (int n = 0; n < 2; n=n+1)
      array_of_2_ButterflyResponse_from_lv[n] = i[n];
  endfunction
  function automatic array_of_2_ButterflyResponse array_of_2_ButterflyResponse_cons(ButterflyResponse x,ButterflyResponse  xs [0:0]);
    array_of_2_ButterflyResponse_cons[0] = x;
    array_of_2_ButterflyResponse_cons[1:1] = xs;
  endfunction
endpackage : NTT256_types

