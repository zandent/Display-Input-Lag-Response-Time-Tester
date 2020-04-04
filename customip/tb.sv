`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 02/07/2020 11:10:43 PM
// Design Name: 
// Module Name: tb_s1
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


module tb_s1();
reg clk, reset;
reg [4:0] n; // number of bits to mask
reg [31:0] value_in; // input value
wire [31:0] value_out; // output value
reg mode;
reg loop_en;
wire plot_done;

wire plot_en;
wire [31:0] park_addr;
wire [31:0] park_reg;
reg [7:0] led;
wire [31:0] colordef;
reg pixel_frame_index;
prtest DUT(
.clk(clk),
.resetn(reset),
.led(led),
.colordef(colordef),
.loop_en(loop_en),
.pixel_result(),
.pixel_frame_index(pixel_frame_index)
);
assign colordef = 32'h03340000;
// generate clock
always // no sensitivity list, so it always executes
begin
    clk = 1; #5; clk = 0; #5; // 10ns period
end

always@(posedge clk) begin
    if(~reset) begin
        led <= 8'h10;
    end
    else begin
        if(loop_en) begin
            if(pixel_frame_index) begin
                if(led > 8'd0) begin
                    led <= led -1'b1;
                end
            end
            else begin
                if(led < 8'hff) begin
                    led <= led +1'b1;
                end
            end
        end
    end
end
initial // Will execute at the beginning once
begin
    loop_en <= 1'b0;
    reset = 0; #27; reset = 1; // Apply reset wait
    loop_en <= 1'b1;
    // @(posedge clk);
    // @(posedge clk);
    // wait(n==31);
    // @(posedge clk);
    #50;

    #500;

    #30000;
    $finish;
end

// reg [3:0] counter;
// reg start_count;
// always@(posedge clk) begin
//     if(~reset) begin
//         counter <= 4'd0;
//         start_count <= 1'b0;
//     end
//     else begin
//         if(plot_en) begin
//             start_count <= 1'b1;
//         end
//         else if(counter == 4'b1111) begin
//             start_count <= 1'b0;
//         end
//         if(start_count) begin
//             counter <= counter + 1'b1;  
//         end
//         else begin
//            counter <= 4'd0;  
//         end
//     end
// end
// //assign plot_done = (counter==4'b1110);
// testingloopfsm dut(
//     .clk(clk),
//     .resetn(resetn),
//     .mode(mode),
//     .loop_en(loop_en),
//     .plot_done(plot_done),
//     .plot_en(plot_en),
//     .park_addr(park_addr),
//     .park_reg(park_reg)
// );
// // //for display func
// // always@(negedge clk) begin
// //     if(reset) begin
// //         //do nothing
// //     end
// //     else begin
// //         $display("DISPLAY: mask is %d, value in is %h and value out is %h", n, value_in, value_out);
// //     end
// // end

// // //for monitor func
// // initial begin
// //     $monitor("MONITOR: mask is %d, value in is %h and value out is %h", n, value_in, value_out);
// // end

// initial // Will execute at the beginning once
// begin
//     mode <= 1'b1;
//     loop_en <= 1'b0;
//     reset = 0; #27; reset = 1; // Apply reset wait
//     // @(posedge clk);
//     // @(posedge clk);
//     // wait(n==31);
//     // @(posedge clk);
//     #50;
//     mode <= 1'b0;
//     loop_en <= 1'b1;
//     #500;
//     loop_en <= 1'b0;
//     #100;
//     $finish;
// end

endmodule
