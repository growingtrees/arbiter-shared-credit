// Top-level credit wrapper for ARB-RR-EX-001.
// req_en is not a primary input. It is created from the credit registers.
// req_en uses the credit value before the clock edge. A grant decrements the
// winner's class on that edge. A credit input can increment on the same edge.
// If both happen, the class does not change.

module rr_arb_shared_credit #(
  parameter CREDIT_W = 8
) (
  input                  clk,
  input                  reset_,    // active-low
  input  [3:0]           req,
  input                  credit0,   // return one class-0 credit
  input                  credit1,   // return one class-1 credit
  input                  credit2,   // return one class-2 credit
  output [3:0]           gnt,
  output                 gnt_valid
);

  reg [CREDIT_W-1:0] credit_class0;
  reg [CREDIT_W-1:0] credit_class1;
  reg [CREDIT_W-1:0] credit_class2;

  // req0 and req1 share class 0. req2 uses class 1. req3 uses class 2.
  wire [3:0] req_en;
  assign req_en[0] = |credit_class0;
  assign req_en[1] = |credit_class0;
  assign req_en[2] = |credit_class1;
  assign req_en[3] = |credit_class2;

  rr_arb #(
    .N(4)
  ) u_rr_arb (
    .clk      (clk),
    .reset_   (reset_),
    .req      (req),
    .req_en   (req_en),
    .gnt      (gnt),
    .gnt_valid(gnt_valid)
  );

  wire dec0 = gnt[0] | gnt[1];
  wire dec1 = gnt[2];
  wire dec2 = gnt[3];

  function [CREDIT_W-1:0] credit_next;
    input [CREDIT_W-1:0] cur;
    input                inc;
    input                dec;
    begin
      if (inc && !dec && cur != {CREDIT_W{1'b1}})
        credit_next = cur + {{(CREDIT_W-1){1'b0}}, 1'b1};
      else if (!inc && dec && cur != {CREDIT_W{1'b0}})
        credit_next = cur - {{(CREDIT_W-1){1'b0}}, 1'b1};
      else
        credit_next = cur;
    end
  endfunction

  always @(posedge clk or negedge reset_) begin
    if (!reset_) begin
      credit_class0 <= {CREDIT_W{1'b0}};
      credit_class1 <= {CREDIT_W{1'b0}};
      credit_class2 <= {CREDIT_W{1'b0}};
    end else begin
      credit_class0 <= credit_next(credit_class0, credit0, dec0);
      credit_class1 <= credit_next(credit_class1, credit1, dec1);
      credit_class2 <= credit_next(credit_class2, credit2, dec2);
    end
  end

endmodule
