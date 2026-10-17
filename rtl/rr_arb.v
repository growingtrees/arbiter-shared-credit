// Round-robin arbiter from ARB-RR-EX-001.
// req is level-sensitive. A later win while req stays high is a new grant.
// gnt is combinational and one-hot. The mask advances only when gnt_valid is high.

module rr_arb #(
  parameter N = 4
) (
  input              clk,
  input              reset_,       // active-low
  input  [N-1:0]     req,
  input  [N-1:0]     req_en,       // per-requester enable / ready
  output [N-1:0]     gnt,          // one-hot, combinational
  output             gnt_valid
);

  reg  [N-1:0] mask_q;             // 1 = has priority this round

  wire [N-1:0] req_q = req & req_en;
  wire [N-1:0] req_m = req_q & mask_q;
  wire [N-1:0] gnt_m = req_m & ~(req_m - {{(N-1){1'b0}}, 1'b1});
  wire [N-1:0] gnt_u = req_q & ~(req_q - {{(N-1){1'b0}}, 1'b1});

  assign gnt       = |req_m ? gnt_m : gnt_u;
  assign gnt_valid = |req_q;

  // Priority goes to requesters strictly above the winner. After the top index
  // wins, the mask clears and the unmasked path wraps to index 0.
  wire [N-1:0] mask_nxt = ~((gnt << 1) - {{(N-1){1'b0}}, 1'b1});

  always @(posedge clk or negedge reset_) begin
    if (!reset_)
      mask_q <= {N{1'b1}};
    else if (gnt_valid)
      mask_q <= mask_nxt;
  end

endmodule
