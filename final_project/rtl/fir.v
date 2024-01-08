`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2023 02:08:58 AM
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
    parameter tap_num = 37
)
(
    input  wire       clk,
    input  wire       rst_n,
    input  wire signed     [WL-1:0] data_in,
    output wire signed [MAC_WL-1:0] data_out
);
    // assign taps (tap number = 37) and its value
    //--------------------------------------------
    wire signed [WL-1:0] tap [tap_num-1:0];
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
    assign tap[19] =  14'd5819;
    assign tap[20] =  14'd1120;
    assign tap[21] = -14'd1588;
    assign tap[22] = -14'd982;
    assign tap[23] =  14'd592;
    assign tap[24] =  14'd781;
    assign tap[25] = -14'd134;
    assign tap[26] = -14'd557;
    assign tap[27] = -14'd89;
    assign tap[28] =  14'd344;
    assign tap[29] =  14'd169;
    assign tap[30] = -14'd176;
    assign tap[31] = -14'd166;
    assign tap[32] =  14'd60;
    assign tap[33] =  14'd120;
    assign tap[34] =  14'd0;
    assign tap[35] = -14'd68;
    assign tap[36] = -14'd19;
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
                inputbuffer[0] <= data_in;
            for(i=tap_num-1;i>0;i=i-1) begin
                inputbuffer[i] <= inputbuffer[i-1];
            end
        end
    end

    //---------------------------------------------
    
    //declare the mul buffer (store each element of multiplication(taps[0]*input[0] ---> taps[1]*input[0],taps[0]*input[1]..., and so on))
    //---------------------------------------------
    wire signed [(WL+WL)-1:0] mul_tmp [0:tap_num-1];
    wire signed [MAC_WL-1:0] mul [0:tap_num-1];
    //---------------------------------------------
    
    //the behavier of multiplication
    //---------------------------------------------
    genvar j;
    generate
        for(j=0;j<tap_num;j=j+1) begin
            assign mul_tmp[j] = inputbuffer[j] * tap[j];
        end
    endgenerate
    genvar jj;
    generate
        for(jj=0;jj<tap_num;jj=jj+1) begin
            assign mul[jj] = mul_tmp[jj][(WL+WL-1)-:20];
        end
    endgenerate
    //---------------------------------------------
    
    //declare the add buffer (add each element of multiplication result)
    //---------------------------------------------
    reg signed [MAC_WL-1:0] add;
    //---------------------------------------------
    
    //the behavior of adder
    //---------------------------------------------    
    always@* begin
        add = mul[0] + mul[1] + mul[2] + mul[3] + mul[4] + mul[5] + mul[6] + mul[7] + 
              mul[8] + mul[9] + mul[10] + mul[11] + mul[12] + mul[13] + mul[14] + mul[15] +
              mul[16] + mul[17] + mul[18] + mul[19] + mul[20] + mul[21] + mul[22] + mul[23] +
              mul[24] + mul[25] + mul[26] + mul[27] + mul[28] + mul[29] + mul[30] + mul[31] + 
              mul[32] + mul[33] + mul[34] + mul[35] + mul[36];
    end
    //---------------------------------------------
    
    assign data_out = add;


endmodule
