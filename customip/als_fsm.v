`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/08/2020 01:24:14 PM
// Design Name: 
// Module Name: als_fsm
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


module als_fsm(
        input clk,
        input resetn,
        input run_en,
        output reg cs_n,
        input sdo,
        output sclk,
        output reg [7:0] led
    );
//reg [7:0]led_tmp;
//reg resetn_init;
// initial begin
//     resetn_init = 1'b0;
// end
//wire clk;
//clk_wiz_0 wiz
// (
//  // Clock out ports
//  .clk_out1(clk),
//  // Status and control signals
//  .reset(~resetn),
// // Clock in ports
//  .clk_in1(clk_sys)
// );
localparam IDLE        = 5'd0;
localparam ENTER_MODE    = 5'd1;
localparam T_QUIET = 5'd2;
localparam DATA_RECV = 5'd3;

reg [15:0] sft_reg;
reg [5:0] counter;
reg [5:0] counter_quiet;
reg [4:0] state;

//  always @(posedge clk)
//begin
//  if (~resetn)
//  begin
//      led <= 0;
//  end
//  else begin
//    if(sw_one) begin
//        led <= led_tmp;
//    end
//  end
//end  



assign sclk = clk;
  always @(posedge clk)
  begin
    if (~resetn)
    begin
        cs_n <= 1'b1;
    end
      else
      begin
          if(state == ENTER_MODE) begin
            if(counter < 6'd13) begin
                cs_n <= 1'b0;
            end 
            else begin
                cs_n <= 1'b1;
            end
          end
          else if(state == DATA_RECV) begin
            if(counter < 6'd16) begin
                cs_n <= 1'b0;
            end 
            else begin
                cs_n <= 1'b1;
            end
          end
          else begin
            cs_n <= 1'b1;
          end
    end
  end 
  
    always @(posedge clk)
  begin
    if (~resetn)
    begin
        sft_reg <= 0;
    end
      else
      begin
        if(state == DATA_RECV) begin
            sft_reg <= {sft_reg[14:0], sdo};
          end
          else begin
            sft_reg <= 0;
          end
    end
  end 
  
  always @(posedge clk)
  begin
    if (~resetn)
    begin
        counter <= 0;
    end
    else
    begin
          if(state == ENTER_MODE) begin
            if(counter == 6'd13) begin
                counter <= 0;
            end 
            else begin
                counter <= counter + 1'b1;
            end
          end
          else if(state == DATA_RECV) begin
            if(counter == 6'd16) begin
                counter <= 0;
            end 
            else begin
                counter <= counter + 1'b1;
            end
          end
          else begin
            counter <= 0;
          end
    end 
  end

  always @(posedge clk)
  begin
    if (~resetn)
    begin
        counter_quiet <= 0;
    end
    else
    begin
          if(state == T_QUIET) begin
            if(counter_quiet == 6'd5) begin
                counter_quiet <= 0;
            end 
            else begin
                counter_quiet <= counter_quiet + 1'b1;
            end
          end
          else begin
            counter_quiet <= 0;
          end
    end
  end

reg led_en;
  always @(posedge clk)
  begin
    if (~resetn)
    begin
        state <= IDLE;
        led_en <= 0;
    end
      else
      begin
          led_en <= 0;
        if(run_en) begin
          case(state)
            IDLE: begin
                state <= ENTER_MODE;
            end      
            ENTER_MODE: begin
                if(counter == 6'd13) begin
                    state <= T_QUIET;
                end
            end 
            T_QUIET : begin
                
                if(counter_quiet == 6'd5) begin
                    state <= DATA_RECV;
                end
            end  
            DATA_RECV : begin
                if(counter == 6'd16) begin
                    led_en <= 1;
                end
                if(counter == 6'd16) begin
                    state <= T_QUIET;
                end
            end 
            default: begin
                state <= IDLE;
                led_en <= 0;
            end 
          endcase
        end
        else begin
            state <= IDLE;           
        end
       end // if (w_Master_RX_DV)
    end // always @ (posedge i_Clk)
  
  always @(posedge clk)
  begin
    if (~resetn)
    begin
        led <= 0;
    end
      else
      begin
       if(led_en) begin
       led <=  sft_reg[12:5];
       end
      end 
  end 
//ila_0 dg(
//.clk(clk),
//.probe0({state,sft_reg,sdo,cs_n,sclk,counter_quiet,counter,resetn})
//);
endmodule
