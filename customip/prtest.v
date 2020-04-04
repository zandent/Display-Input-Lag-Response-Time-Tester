`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 03/22/2020 05:56:54 PM
// Design Name: 
// Module Name: prtest
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


module prtest(
input clk,
input resetn,
input [7:0] led,
input [31:0] colordef,
input loop_en,
output reg [31:0] pixel_result,
output reg pixel_frame_index
);

reg [31:0] pixel_counter;
reg [31:0] counter_delay;
reg ready_counter;
reg we_en;
reg delay_en;
reg rise_fall;//1: rise, 0:fall
reg pixel_done_prev;
reg pixel_done;
reg [4:0] curr_state;
reg [4:0] next_state;
localparam
    INIT = 5'd0,
    TMPONE =  5'd1,
    TMPTWO = 5'd2,
    TMPTHREE = 5'd3,
    TMPFOUR =  5'd4,
    TMPFIVE = 5'd5,
    TMPSIX = 5'd6;

always @(posedge clk)
begin
    if(~resetn) // go to state zero if rese
        begin
        curr_state <= INIT;
        end
    else // otherwise update the states
        begin
        curr_state <= next_state;
        end
end

// always @(posedge clk)
// begin
//     if(~resetn) // go to state zero if rese
//         begin
//         rise_fall <= 0;
//         end
//     else // otherwise update the states
//         begin
//             if(curr_state == TMPONE) begin
//                 if(led > colordef[23:16]) begin
//                     rise_fall <= 0;
//                 end
//                 else if(led < colordef[31:24]) begin
//                     rise_fall <= 1;
//                 end            
//             end
//         end
// end

	always @(*)
	begin
        next_state = curr_state;
        rise_fall = 0;
        pixel_frame_index = 0;
        ready_counter = 0;
        we_en = 0;
        delay_en = 0;
		case(curr_state)
		INIT: begin
			if(loop_en) begin
                if(led > colordef[23:16]) begin
                    next_state = TMPONE;
                end
                else if(led < colordef[31:24]) begin
                    next_state = TMPFOUR;
                end
			end
        end
        TMPONE: begin
            rise_fall = 0;
            pixel_frame_index = 0;
            next_state = TMPTWO;
        end
        TMPTWO: begin
            rise_fall = 0;
            pixel_frame_index = 1;
            ready_counter = 1;
            if((~pixel_done_prev) && pixel_done) begin
                we_en = 1;
                next_state = TMPTHREE;
            end
        end
        TMPTHREE: begin
            rise_fall = 0;
            ready_counter = 0;
            delay_en = 1;
            pixel_frame_index = 1;
            if(counter_delay == 32'd50000000) begin
                next_state = TMPFOUR;
            end
        end

        TMPFOUR: begin
            rise_fall = 1;
            pixel_frame_index = 1;
            next_state = TMPFIVE;
        end
        TMPFIVE: begin
            rise_fall = 1;
            pixel_frame_index = 0;
            ready_counter = 1;
            if((~pixel_done_prev) && pixel_done) begin
                we_en = 1;
                next_state = TMPSIX;
            end
        end
        TMPSIX: begin
            rise_fall = 1;
            ready_counter = 0;
            delay_en = 1;
            pixel_frame_index = 0;
            if(counter_delay == 32'd50000000) begin
                next_state = TMPONE;
            end
        end
		default:
		begin
            next_state = curr_state;
            rise_fall = 0;
            pixel_frame_index = 0;
            ready_counter = 0;
            we_en = 0;
            delay_en = 0;
		end
		endcase
	end

always @(posedge clk)
begin
    if(~resetn) // go to state zero if rese
        begin
        pixel_result <= 0;
        end
    else // otherwise update the states
        begin
            if(we_en) begin
                pixel_result <= pixel_counter;
            end
        end
end

always @(posedge clk)
begin
    if(~resetn) // go to state zero if rese
        begin
        counter_delay <= 0;
        end
    else // otherwise update the states
        begin
            if(delay_en) begin
                counter_delay <= counter_delay + 1'b1;
            end
            else begin
                counter_delay <= 0;
            end
        end
end

always @(posedge clk)
begin
    if(~resetn) // go to state zero if rese
        begin
            pixel_counter <= 0;
            pixel_done <= 1;
            pixel_done_prev <= 1;
        end
    else // otherwise update the states
        begin
            pixel_done_prev <= pixel_done;
            if(ready_counter) begin
				if(rise_fall) begin
					if( (led >= colordef[31:24]) && pixel_done) begin
						pixel_done <= 0;
					end
					else if((~pixel_done)&&(led > colordef[23:16]) ) begin
						pixel_done <= 1;
					end
				end
				else begin
					if( (led <= colordef[23:16]) && pixel_done) begin
						pixel_done <= 0;
					end
					else if((~pixel_done)&&(led < colordef[31:24]) ) begin
						pixel_done <= 1;
					end
				end  
                if(~pixel_done)begin
                    pixel_counter <= pixel_counter + 1'b1;
                end           
            end
            else begin
                pixel_counter <= 0;
                pixel_done <= 1;
                pixel_done_prev <= 1;
            end
        end
end

endmodule
