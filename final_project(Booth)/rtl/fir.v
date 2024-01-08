`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/07/2024 03:31:10 PM
// Design Name: 
// Module Name: fir
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


module fir
#(
    parameter WL = 14,
    parameter MAC_WL = 20,
    parameter tap_num = 37,
    parameter fold_length = 19
)
(
    input  wire       clk,
    input  wire       rst_n,
    input  wire signed     [WL-1:0] data_in,
    output wire signed [MAC_WL-1:0] data_out,
    output wire       r_ready,
    output wire       w_valid
);

    localparam
    IDLE  = 2'b00,
    INIT  = 2'b01,
    COUNT = 2'b10,
    OUT   = 2'b11;

    // assign taps (folded length = 19) and its value
    // --------------------------------------------
    wire signed [WL-1:0] tap [fold_length-1:0];
    assign tap[0]  = -14'd19;
    assign tap[1]  = -14'd68;
    assign tap[2]  =  14'd0;
    assign tap[3]  =  14'd120;
    assign tap[4]  =  14'd60;
    assign tap[5]  = -14'd166;
    assign tap[6]  = -14'd176;
    assign tap[7]  =  14'd169;
    assign tap[8]  =  14'd344;
    assign tap[9]  = -14'd89;
    assign tap[10] = -14'd557;
    assign tap[11] = -14'd134;
    assign tap[12] =  14'd781;
    assign tap[13] =  14'd592;
    assign tap[14] = -14'd982;
    assign tap[15] = -14'd1588;
    assign tap[16] =  14'd1120;
    assign tap[17] =  14'd5819;
    assign tap[18] =  14'd8191;
    //---------------------------------------------

    // declare FSM machine 
    //---------------------------------------------
    reg [1:0] state;
    reg [1:0] next_state;
    //---------------------------------------------

    // FSM behavior
    //---------------------------------------------
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    //---------------------------------------------

    //declare the input buffer (shift register for input data)
    //---------------------------------------------
    reg signed [WL-1:0]   inputbuffer[0:tap_num-1];
    //---------------------------------------------

    //initialize the input buffer and the behavior of shift
    //---------------------------------------------
    integer i;
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            for(i=0;i<tap_num;i=i+1) begin
                inputbuffer[i] <= 14'd0;
            end
        end else begin
            case(state)
                IDLE: begin
                    inputbuffer[0] <= data_in;
                    for(i=tap_num-1;i>0;i=i-1) begin
                        inputbuffer[i] <= inputbuffer[i-1];
                    end
                    //                    for(i=0;i<tap_num;i=i+1) begin
                    //                        inputbuffer[i] <= 14'd0;
                    //                    end
                end
                INIT: begin
                    inputbuffer[0] <= data_in;
                    for(i=tap_num-1;i>0;i=i-1) begin
                        inputbuffer[i] <= inputbuffer[i-1];
                    end
                end
                COUNT: begin
                    for(i=tap_num-1;i>0;i=i-1) begin
                        inputbuffer[i] <= inputbuffer[i];
                    end
                end
                OUT: begin
                    for(i=tap_num-1;i>0;i=i-1) begin
                        inputbuffer[i] <= inputbuffer[i];
                    end
                end
            endcase
        end
    end
    //---------------------------------------------

    //declare the temp buffer (to sum up the x[0] and x[36]...) Note: the bit should be 13 rather than input buffer to avoid overflow
    //---------------------------------------------
    reg signed [WL:0] temp_buffer [(fold_length-1):0];
    //---------------------------------------------

    //initialize the temp_buffer and the behavior of adder
    //---------------------------------------------
    integer ii;
    always@* begin
        for(ii=0;ii<(fold_length-1);ii=ii+1) begin
            temp_buffer[ii] = inputbuffer[ii] + inputbuffer[36-ii];
        end
        temp_buffer[18] = inputbuffer[18];
    end
    //---------------------------------------------

    //declare the mul buffer and control signal (store each element of multiplication(taps[0]*input[0] ---> taps[1]*input[0],taps[0]*input[1]..., and so on))
    //---------------------------------------------
    wire [31:0] mul_temp [0:fold_length-1];
    wire [MAC_WL-1:0] mul [0:fold_length-1];
    wire mul_start;
    wire mul_done;
    //---------------------------------------------

    //the behavier of multiplication
    //---------------------------------------------
    genvar j;
    generate
        for(j=0;j< fold_length; j=j+1) begin
            booth booth_U(.axis_clk(clk),.axis_rst_n(rst_n),.din0({tap[j][13],tap[j][13],tap[j][13:0]}),.din1({temp_buffer[j][14],temp_buffer[j][14:0]}),.dout(mul_temp[j]),.start(mul_start),.done(mul_done));
            assign mul[j] = mul_temp[j][(WL+WL-1)-:20];
        end
    endgenerate
    //---------------------------------------------

    //declare the add buffer (temp result of add result)
    //---------------------------------------------
    reg signed [MAC_WL-1:0] add;
    //---------------------------------------------

    //the behavior of adder
    //---------------------------------------------    
    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            add <= 20'b0;
        end else begin
            case(state)
                IDLE: begin
                    add <= 20'b0;
                end
                INIT: begin
                    add <= 20'b0;
                end
                COUNT: begin
                    if(mul_done) begin
                        add <= mul[0] + mul[1] + mul[2] + mul[3] + mul[4] + mul[5] + mul[6] + mul[7] +
                        mul[8] + mul[9] + mul[10] + mul[11] + mul[12] + mul[13] + mul[14] + mul[15] +
                        mul[16] + mul[17] + mul[18];
                    end else begin
                        add <= add;
                    end
                end
                OUT: begin
                    add <= add;
                end
            endcase
        end
    end
    //---------------------------------------------

    assign data_out = add;

    //Multiplier controll signal
    //---------------------------------------------
    reg  mul_start_reg;
    reg  w_valid_reg;
    reg  r_ready_reg;
    //---------------------------------------------
    //FSM behavior
    //---------------------------------------------
    always@* begin
        case(state)
            IDLE: begin
                next_state = INIT;
                w_valid_reg = 0;
                r_ready_reg = 1;
            end
            INIT: begin
                next_state = COUNT;
                w_valid_reg = 0;
                r_ready_reg = 1;
            end
            COUNT: begin
                w_valid_reg = 0;
                r_ready_reg = 0;
                if(mul_done) begin
                    next_state = OUT;
                end else begin
                    next_state = COUNT;
                end
            end
            OUT: begin
                next_state = INIT;
                w_valid_reg = 1;
                r_ready_reg = 0;
            end
        endcase
    end

    always@(posedge clk or negedge rst_n) begin
        if(~rst_n) begin
            mul_start_reg <= 1'b0;
        end else begin
            case(state)
                IDLE: begin
                    mul_start_reg <= 1'b0;
                end
                INIT: begin
                    mul_start_reg <= 1'b1;
                end
                COUNT: begin
                    mul_start_reg <= 1'b0;
                end
                OUT: begin
                    mul_start_reg <= 1'b0;
                end
            endcase
        end
    end
    assign mul_start = mul_start_reg;
    assign r_ready = r_ready_reg;
    assign w_valid = w_valid_reg;

    wire signed [13:0] test1;
    wire signed [15:0] test2;
    assign test1 = -14'd2266;
    assign test2 = -16'd2266;
    //---------------------------------------------
endmodule

