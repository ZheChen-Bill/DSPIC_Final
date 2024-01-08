`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2023 03:39:35 AM
// Design Name: 
// Module Name: fir_tb
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

module fir_tb#(
    parameter WL = 14,
    parameter MAC_WL = 20,
    parameter tap_num = 37,
    parameter Data_num = 1024
)();
    reg               clk;
    reg               rst_n;
    reg  signed [WL-1:0] data_in;
    wire signed [MAC_WL-1:0] data_out;
    wire r_ready;
    wire w_walid;
    fir fir(.clk(clk),.rst_n(rst_n),.data_in(data_in),.data_out(data_out),.r_ready(r_ready),.w_valid(w_valid));
    integer Din, input_data, golden, golden_data, m;
    reg signed [(WL-1):0]     Din_list[0:(Data_num-1)];
    reg signed [(MAC_WL-1):0] golden_list[0:(Data_num-1)];
    initial begin
        Din = $fopen("./inputsignal_quantize.txt","r");
        golden = $fopen("./outputsignal(fixed)before_dequantize.txt","r");
        for(m=0;m<Data_num;m=m+1) begin
            input_data = $fscanf(Din,"%d", Din_list[m]);
            golden_data = $fscanf(golden,"%d", golden_list[m]);
        end
    end

    initial begin
        $dumpfile("fir.vcd");
        $dumpvars();
    end

    initial begin
        clk = 0;
        forever begin
            #5 clk = (~clk);
        end
    end

    initial begin
        rst_n = 0;
        @(posedge clk); @(posedge clk);
        rst_n = 1;
    end

    integer i;
    initial begin
        data_in <= 0;
        while(!rst_n) @(posedge clk);
        $display("------------Start Simulation-----------");
        @(posedge clk);
        for(i=0;i<Data_num;i=i+1) begin
            inputsignal(Din_list[i],i);
        end
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
    end

    integer j;
    initial begin
        data_in <= 0;
        while(!rst_n) @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        @(posedge clk);
        while (!w_valid) @(posedge clk);
        @(posedge clk);
        for(j=0;j<Data_num;j=j+1) begin
            outputsignal(golden_list[j],j);
        end
        @(posedge clk);
        @(posedge clk);
        $finish;
    end

    task inputsignal;
        input  signed       [WL-1:0] in; // input data
        input               [31:0] pcnt; // pattern count
        begin
            while (!r_ready) @(posedge clk);
            data_in <= in;
            @(posedge clk);
            //$display("[Pattern %d] input data : %d ",pcnt,in);
        end
    endtask

    task outputsignal;
        input  signed [MAC_WL-1:0] in; // golden data
        input               [31:0] pcnt; // pattern count
        begin
            while (!w_valid) @(posedge clk);
            @(posedge clk);
            if (data_out !== in) begin
                $display("[ERROR] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in , data_out);
                //$finish;
            end
            else begin
                $display("[Correct] [Pattern %d] Golden answer: %d, Your answer: %d", pcnt, in , data_out);
            end
        end
    endtask
endmodule
