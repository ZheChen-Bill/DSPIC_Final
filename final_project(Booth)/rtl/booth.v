`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/07/2024 03:32:01 PM
// Design Name: 
// Module Name: booth
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module booth
#(  parameter din0_WIDTH = 16,
    parameter din1_WIDTH = 16,
    parameter dout_WIDTH = 32
)
(
    input  wire                      axis_clk, // CLK AXI STREAM
    input  wire                      axis_rst_n, // reset_n AXI STREAM
    input  wire [din0_WIDTH - 1 : 0] din0,
    input  wire [din1_WIDTH - 1 : 0] din1,
    output wire [dout_WIDTH - 1 : 0] dout,

    input  wire                      start,
    output wire                      done
);

    localparam
    IDLE   = 2'b00,
    CAL    = 2'b01,
    SHIFT  = 2'b10,
    FINISH = 2'b11;

    reg [din0_WIDTH - 1 : 0] Din0_reg;
    reg [din0_WIDTH - 1 : 0] sDin0_reg;
    reg [dout_WIDTH - 1 : 0] dout_reg;
    reg [dout_WIDTH : 0] product;

    reg  [1: 0]              state;
    reg  [1: 0]              next_state;

    reg                      done_reg;
    reg  [5: 0]              times;

    always@ (posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            state <= IDLE;
        end
        else begin
            state <= next_state;
        end
    end

    always@ (posedge axis_clk or negedge axis_rst_n) begin
        if (~axis_rst_n) begin
            Din0_reg  <= 0;
            sDin0_reg <= 0;
            dout_reg  <= 0;
            product   <= 0;
            done_reg  <= 0;
            times     <= 0;
        end
        else begin
            case (state)
                IDLE: begin
                    Din0_reg  <= din0;
                    sDin0_reg <= ((~din0) + 1'b1);
                    product   <= {16'b0,din1,1'b0};
                    done_reg  <= 1'b0;
                    times     <= 6'b0;
                end
                CAL: begin
                    times    <= times +6'b1;
                    if( product[1:0] == 2'b01) begin
                        product  <= {(product[32:17] + Din0_reg), product[16:0]};
                    end
                    else if (product[1:0] == 2'b10) begin
                        product  <= {(product[32:17] + sDin0_reg), product[16:0]};
                    end
                    else begin
                        product  <= product;
                    end
                end
                SHIFT: begin
                    product <= {product[32],product[32:1]};
                end
                FINISH: begin
                    done_reg <= 1'b1;
                    dout_reg <= product[32:1];
                end
                default: begin
                    Din0_reg  <= 16'b0;
                    sDin0_reg <= 16'b0;
                    dout_reg  <= 32'b0;
                    product   <= 33'b0;
                    done_reg  <= 1'b0;
                    times     <= 6'b0;
                end
            endcase
        end
    end
    always@* begin
        case (state)
            IDLE: begin
                next_state = (start) ? CAL : IDLE;
            end
            CAL: begin
                next_state = SHIFT;
            end
            SHIFT: begin
                if (times == 6'd16) begin
                    next_state = FINISH;
                end
                else begin
                    next_state = CAL;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: begin
                next_state = IDLE;
            end
        endcase
    end

    assign done = done_reg;
    assign dout = dout_reg;
    
    function integer log2;
        input integer x;
        integer n, m;
        begin
            n = 1;
            m = 2;
            while (m < x) begin
                n = n + 1;
                m = m * 2;
            end
            log2 = n;
        end
    endfunction
endmodule
