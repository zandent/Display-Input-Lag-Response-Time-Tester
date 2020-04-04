module testingloopfsm(
    input clk,
    input resetn,
    input mode,
    input loop_en,
    output plot_done,
    output logic plot_en,
    output logic [31:0] park_addr,
    output logic [31:0] park_reg,
    output logic [4:0] curr_state,
    output logic [4:0] next_state
);
assign plot_done = ~loop_en;
localparam
    INIT = 5'b0,
    LAG_PLOT_ONE =  5'b1,
    //LAG_PLOT_TWO = 5'd2,
    LAG_PLOT_ONE_TEMP = 5'd3;
    //LAG_PLOT_TWO_TEMP = 5'd4;
// logic [4:0] curr_state;
// logic [4:0] next_state;
always @(posedge clk, negedge resetn)
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

	always @(*)
	begin
		case(curr_state)
		INIT: begin
            plot_en = 1'b0;
            park_addr = 32'h44A00000 + 32'h00000028;
            park_reg = 0;
            if(loop_en) begin
                next_state = LAG_PLOT_ONE_TEMP;
            end
            else begin
                next_state = INIT;
            end
        end
        LAG_PLOT_ONE_TEMP: begin
            plot_en = 1'b1;
            park_addr = 32'h44A00000 + 32'h00000028;
            park_reg = 0;
            if(loop_en) begin
                next_state = LAG_PLOT_ONE;
            end
            else begin
                next_state = INIT;
            end
        end
        LAG_PLOT_ONE: begin
            plot_en = 1'b0;
            park_addr = 32'h44A00000 + 32'h00000028;
            park_reg = 0;
            if(loop_en) begin 
                // if(plot_done) begin
                //     next_state = LAG_PLOT_TWO_TEMP;
                // end
                // else 
                begin
                    next_state = LAG_PLOT_ONE;
                end
            end
            else begin
                next_state = INIT;
            end
        end
        // LAG_PLOT_TWO_TEMP: begin
        //     plot_en = 1'b1;
        //     park_addr = 32'h44A00000 + 32'h00000028;
        //     park_reg = 32'h00000001;
        //     if(loop_en) begin 
        //         next_state = LAG_PLOT_TWO;
        //     end
        //     else begin
        //         next_state = INIT;
        //     end
        // end
        // LAG_PLOT_TWO: begin
        //     plot_en = 1'b0;
        //     park_addr = 32'h44A00000 + 32'h00000028;
        //     park_reg = 32'h00000001;
        //     if(loop_en) begin 
        //         if(plot_done) begin
        //             next_state = LAG_PLOT_ONE_TEMP;
        //         end
        //         else begin
        //             next_state = LAG_PLOT_TWO;
        //         end
        //     end
        //     else begin
        //         next_state = INIT;
        //     end
        // end

		default:
		begin
			next_state = INIT;
            plot_en = 1'b0;
            park_addr = 32'h44A00000 + 32'h00000028;
            park_reg = 32'h00000000;
		end
		endcase
	end

endmodule
