
`timescale 1 ns / 1 ps

	module customip_v1_0 #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 4,

		// Parameters of Axi Master Bus Interface M00_AXI
		parameter  C_M00_AXI_START_DATA_VALUE	= 32'hAA000000,
		parameter  C_M00_AXI_TARGET_SLAVE_BASE_ADDR	= 32'h40000000,
		parameter integer C_M00_AXI_ADDR_WIDTH	= 32,
		parameter integer C_M00_AXI_DATA_WIDTH	= 32,
		parameter integer C_M00_AXI_TRANSACTIONS_NUM	= 4
	)
	(
		// Users to add ports here
        output  cs_n,
        input sdo,
        output sclk,
        output [7:0] led,
		input als_clk,
		input tuser,
		
		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready,

		// Ports of Axi Master Bus Interface M00_AXI
		input wire  m00_axi_init_axi_txn,
		output wire  m00_axi_error,
		output wire  m00_axi_txn_done,
		input wire  m00_axi_aclk,
		input wire  m00_axi_aresetn,
		output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_awaddr,
		output wire [2 : 0] m00_axi_awprot,
		output wire  m00_axi_awvalid,
		input wire  m00_axi_awready,
		output wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_wdata,
		output wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] m00_axi_wstrb,
		output wire  m00_axi_wvalid,
		input wire  m00_axi_wready,
		input wire [1 : 0] m00_axi_bresp,
		input wire  m00_axi_bvalid,
		output wire  m00_axi_bready,
		output wire [C_M00_AXI_ADDR_WIDTH-1 : 0] m00_axi_araddr,
		output wire [2 : 0] m00_axi_arprot,
		output wire  m00_axi_arvalid,
		input wire  m00_axi_arready,
		input wire [C_M00_AXI_DATA_WIDTH-1 : 0] m00_axi_rdata,
		input wire [1 : 0] m00_axi_rresp,
		input wire  m00_axi_rvalid,
		output wire  m00_axi_rready
	);
	wire mode;
    wire loop_en;

	//should be from vdma
    wire plot_done;

    wire plot_en;
    wire [31:0] park_addr;
    wire [31:0] park_reg;
    
    reg [31:0] counter;
    reg start_count;
    reg stop_count;
	reg [31:0] time_result;
	wire [31:0] pixel_result;
	reg [31:0] pixel_counter;
	wire pixel_frame_index;
	reg frame_index; //0 is white and 1 is black
	wire i_index;
    wire [31:0] colordef;
    reg i_als_clk;
    always@(posedge als_clk) begin
        i_als_clk <= ~i_als_clk;
    end

	assign i_index = (mode)? pixel_frame_index : frame_index;
	prtest pr(
		.clk(s00_axi_aclk),
		.resetn(s00_axi_aresetn),
		.led(led),
		.colordef(colordef),
		.loop_en(loop_en),
		.pixel_result(pixel_result),
		.pixel_frame_index(pixel_frame_index)
	);
    // always@(posedge s00_axi_aclk) begin
    //     if(~s00_axi_aresetn) begin
	// 		rise_fall <= 0;
    //     end
    //     else begin
	// 		if(loop_en) begin
	// 			if(pixel_done) begin
	// 				if(led > colordef[23:16]) begin
	// 					rise_fall <= 0;
	// 				end
	// 				else if(led < colordef[31:24]) begin
	// 					rise_fall <= 1;
	// 				end
	// 			end
	// 		end
    //     end
    // end
    // always@(posedge s00_axi_aclk) begin
    //     if(~s00_axi_aresetn) begin
	// 		pixel_frame_index <= 0;
    //     end
    //     else begin
	// 		if(loop_en) begin
	// 			if(rise_fall) begin
	// 				pixel_frame_index <= 0;
	// 			end
	// 			else begin
	// 				pixel_frame_index <= 1;
	// 			end
	// 		end
    //     end
    // end
    // always@(posedge s00_axi_aclk) begin
    //     if(~s00_axi_aresetn) begin
	// 		pixel_done <= 1;
    //     end
    //     else begin
	// 		if(loop_en) begin
	// 			if(rise_fall) begin
	// 				if( (led >= colordef[31:24]) && pixel_done) begin
	// 					pixel_done <= 0;
	// 				end
	// 				else if((~pixel_done)&&(led > colordef[23:16]) ) begin
	// 					pixel_done <= 1;
	// 				end
	// 			end
	// 			else begin
	// 				if( (led <= colordef[23:16]) && pixel_done) begin
	// 					pixel_done <= 0;
	// 				end
	// 				else if((~pixel_done)&&(led < colordef[31:24]) ) begin
	// 					pixel_done <= 1;
	// 				end
	// 			end
	// 		end
    //     end
    // end
    // always@(posedge s00_axi_aclk) begin
    //     if(~s00_axi_aresetn) begin
	// 		pixel_counter <= 0;
    //     end
    //     else begin
	// 		if(loop_en) begin
	// 			if(~pixel_done) begin
	// 				pixel_counter <= pixel_counter + 1'b1;
	// 			end
	// 			else begin
	// 				pixel_counter <= 0;
	// 			end
	// 		end
    //     end
    // end
	// reg pixel_done_prev;
    // always@(posedge s00_axi_aclk) begin
    //     if(~s00_axi_aresetn) begin
	// 		pixel_done_prev <= 1;
    //     end
    //     else begin
	// 		pixel_done_prev <= pixel_done;
	// 		if(loop_en) begin
	// 			if(pixel_done && (~pixel_done_prev) ) begin
	// 				pixel_result <= pixel_counter;
	// 			end
	// 		end
    //     end
    // end
reg write_mem_done;
reg write_mem_en;
reg [31:0] write_mem_addr;
reg [31:0] mem_data;
reg [15:0] write_counter; 

always@(posedge s00_axi_aclk) begin
    if(~s00_axi_aresetn) begin
        mem_data <= 0;
        write_mem_en <= 0;
        write_counter <= 0;
        write_mem_addr < =0;
    end
    else begin
        if(state == INIT) begin
            if(data_valid) begin
                mem_data <= {mem_data[23:0],led};
                if(write_mem_done) begin
                    write_mem_en <= 1'b1;
                    write_mem_addr <= write_mem_addr + 1'b1;
                end
            end
            if(write_counter == 16'd2500) begin
                data_store_done <= 1;
                write_counter <= 0;
            end
            else begin
                if(write_mem_en && ~data_valid)
                    write_counter <= write_counter + 1'b1;
            end
        end
    end
end

reg [31:0] read_shift_mem_data;
reg [31:0] double_de_write_mem_addr;
reg [31:0] double_de_mem_data;
reg double_de_write_mem_en;
reg [15:0] write_counter; 
reg [7:0] double_de_max;
reg [7:0] double_de_min;
reg [7:0] white_thres;
reg [7:0] black_thres;
always@(posedge s00_axi_aclk) begin
    if(~s00_axi_aresetn) begin
        double_de_write_mem_addr <= 0;
        double_de_mem_data <= 0;
        double_de_write_mem_en <= 0;
        write_counter <= 0;
        double_de_max <= 0;
        double_de_min <= 8'hFF;
    end
    else begin
        if(state == CALIBRE) begin
            if(write_counter == 16'd2499) begin
                calibre_done <= 1;
            end
            else begin
                if(write_mem_done) begin
                    double_de_mem_data <= read_shift_mem_data[7:0] - read_shift_mem_data[15:8] - read_shift_mem_data[15:8] + read_shift_mem_data[23:16];
                    write_counter <= write_counter + 1'b1;
                    if(double_de_max < double_de_mem_data) begin
                        double_de_max <= double_de_mem_data;
                        white_thres <= read_shift_mem_data[15:8];
                    end

                    if(double_de_min > double_de_mem_data) begin
                        double_de_min <= double_de_mem_data;
                        black_thres <= read_shift_mem_data[15:8];
                    end
                end
            end
        end
    end
end
    always@(posedge s00_axi_aclk) begin
        if(~s00_axi_aresetn) begin
            counter <= 0;
			time_result <= 0;
        end
        else begin
			if(stop_count) begin
				time_result <= counter;
				counter <= 0;
			end
			else if(start_count) begin
				counter <= counter + 1'b1;
			end
        end
    end

    always@(posedge s00_axi_aclk) begin
        if(~s00_axi_aresetn) begin
            counter <= 0;
			time_result <= 0;
        end
        else begin
			if(stop_count) begin
				time_result <= counter;
				counter <= 0;
			end
			else if(start_count) begin
				counter <= counter + 1'b1;
			end
        end
    end

    always@(posedge s00_axi_aclk) begin
        if(~s00_axi_aresetn) begin
			start_count <= 1'b0;
			stop_count <= 1'b0;
			frame_index <= 1'b0;
        end
        else begin
			if(tuser) begin
				start_count <= 1'b1;
			end
			if((frame_index && (led < colordef[15:8])) || ((!frame_index) && (led>colordef[7:0]))) begin
				start_count <= 1'b0;
				stop_count <= 1'b1;
				frame_index <= ~frame_index;
			end
			else begin
				stop_count <= 1'b0;
			end
        end
    end	


	wire [4:0] curr_state;
	wire [4:0] next_state;
	testingloopfsm top_fsm(
		.clk(s00_axi_aclk),
		.resetn(s00_axi_aresetn),
		.mode(mode),
		.loop_en(loop_en),
		.plot_done(plot_done),
		.plot_en(plot_en),
		.park_addr(park_addr),
		.park_reg(park_reg),
		.next_state(next_state),
		.curr_state(curr_state)
	);

	als_fsm af(
        .clk(i_als_clk),
        .resetn(s00_axi_aresetn),
        .run_en(loop_en),
        .cs_n(cs_n),
        .sdo(sdo),
        .sclk(sclk),
        .led(led)
    );

	//assign m00_axi_wdata = park_reg;
	assign m00_axi_awaddr = park_addr;
    ila_0 dut(
    .clk(s00_axi_aclk),
    .probe0({frame_index,stop_count,start_count,led[7:0],pr.pixel_done, pr.pixel_done_prev, pr.rise_fall, pr.pixel_counter[4:0], pr.pixel_result[4:0],pr.pixel_frame_index,mode}),
    .probe1({m00_axi_wready,m00_axi_wvalid,next_state,curr_state,m00_axi_wdata[1:0],mode,loop_en,plot_done,plot_en,tuser })
    );
// Instantiation of Axi Bus Interface S00_AXI
	customip_v1_0_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) customip_v1_0_S00_AXI_inst (
		.mode(mode),
    	.loop_en(loop_en),
		.result(pixel_result),
		.time_result(time_result),
		.colordef(colordef),
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);

// Instantiation of Axi Bus Interface M00_AXI
	customip_v1_0_M00_AXI # ( 
		.C_M_START_DATA_VALUE(C_M00_AXI_START_DATA_VALUE),
		.C_M_TARGET_SLAVE_BASE_ADDR(C_M00_AXI_TARGET_SLAVE_BASE_ADDR),
		.C_M_AXI_ADDR_WIDTH(C_M00_AXI_ADDR_WIDTH),
		.C_M_AXI_DATA_WIDTH(C_M00_AXI_DATA_WIDTH),
		.C_M_TRANSACTIONS_NUM(C_M00_AXI_TRANSACTIONS_NUM)
	) customip_v1_0_M00_AXI_inst (
		.INIT_AXI_TXN(plot_en),
		.M_AXI_WDATA(m00_axi_wdata),
		.PARK_DATA_BASE(park_reg),
		.plot_done(plot_done),
		.tuser(tuser),
		.frame_index(i_index),

		.ERROR(m00_axi_error),
		.TXN_DONE(m00_axi_txn_done),
		.M_AXI_ACLK(m00_axi_aclk),
		.M_AXI_ARESETN(m00_axi_aresetn),
		
		.M_AXI_AWPROT(m00_axi_awprot),
		.M_AXI_AWVALID(m00_axi_awvalid),
		.M_AXI_AWREADY(m00_axi_awready),
		
		.M_AXI_WSTRB(m00_axi_wstrb),
		.M_AXI_WVALID(m00_axi_wvalid),
		.M_AXI_WREADY(m00_axi_wready),
		.M_AXI_BRESP(m00_axi_bresp),
		.M_AXI_BVALID(m00_axi_bvalid),
		.M_AXI_BREADY(m00_axi_bready),
		.M_AXI_ARADDR(m00_axi_araddr),
		.M_AXI_ARPROT(m00_axi_arprot),
		.M_AXI_ARVALID(m00_axi_arvalid),
		.M_AXI_ARREADY(m00_axi_arready),
		.M_AXI_RDATA(m00_axi_rdata),
		.M_AXI_RRESP(m00_axi_rresp),
		.M_AXI_RVALID(m00_axi_rvalid),
		.M_AXI_RREADY(m00_axi_rready)
	);

	// Add user logic here

	// User logic ends

	endmodule
