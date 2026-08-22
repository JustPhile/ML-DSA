package NTT256_types;
  typedef struct packed {
    logic [22:0] Tuple2_0_sel0;
    logic [22:0] Tuple2_0_sel1;
  } Tuple2_0;
  typedef logic signed [63:0] array_of_256_signed_64 [0:255];
  typedef struct packed {
    logic ReadRequest_sel0;
    logic [7:0] ReadRequest_sel1;
    logic [7:0] ReadRequest_sel2;
    logic [7:0] ReadRequest_sel3;
    logic ReadRequest_sel4;
  } ReadRequest;
  typedef struct packed {
    logic ButterflyPacket_sel0;
    logic [7:0] ButterflyPacket_sel1;
    logic [7:0] ButterflyPacket_sel2;
    logic [22:0] ButterflyPacket_sel3;
    logic [22:0] ButterflyPacket_sel4;
    logic [22:0] ButterflyPacket_sel5;
    logic ButterflyPacket_sel6;
  } ButterflyPacket;
  typedef struct packed {
    logic Tuple4_sel0;
    logic [7:0] Tuple4_sel1;
    logic [7:0] Tuple4_sel2;
    logic Tuple4_sel3;
  } Tuple4;
  typedef struct packed {
    logic [8:0] Tuple2_sel0;
    logic [8:0] Tuple2_sel1;
  } Tuple2;
  typedef logic [22:0] array_of_256_logic_vector_23 [0:255];
  typedef struct packed {
    logic Tuple2_2_sel0;
    logic[0:255][22:0] Tuple2_2_sel1;
  } Tuple2_2;
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
    logic [22:0] Tuple2_1_sel0;
    logic [45:0] Tuple2_1_sel1;
  } Tuple2_1;
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

