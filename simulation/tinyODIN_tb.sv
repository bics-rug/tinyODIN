`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/17/2025 11:13:04 AM
// Design Name: 
// Module Name: tinyODIN_tb
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


`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Groningen
// Engineer: Fernando M. Quintana
// 
// Create Date: 09/12/2025 11:36:36 AM
// Design Name: 
// Module Name: controller_tb
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
`define CLK_HALF_PERIOD             5

`define N 256 
`define M 8



module tinyODIN_tb(
);
    logic               CLK;
    logic               RST;
    
    logic [     9:0]    AERIN_ADDR;
    logic               AERIN_REQ;
    logic               AERIN_ACK;
    
    // Control interface for readback -------------------------
    logic               CTRL_READBACK_EVENT;
    logic               CTRL_PROG_EVENT;
    logic [2*`M-1:0]    CTRL_SPI_ADDR;
    logic      [1:0]    CTRL_OP_CODE;
    
    // Inputs from SPI configuration registers ----------------
    logic               SPI_GATE_ACTIVITY;
    logic               SPI_GATE_ACTIVITY_sync;
    logic   [`M-1:0]    SPI_MAX_NEUR;
    
    // Inputs from scheduler ----------------------------------
    logic               SCHED_EMPTY;
    logic               SCHED_FULL;
    logic     [12:0]    SCHED_DATA_OUT;
    
    // Input from AER output ----------------------------------
    logic               AEROUT_CTRL_BUSY;
    
    // Outputs to synaptic core -------------------------------
    logic               CTRL_SYNARRAY_WE;
    logic               CTRL_SYNARRAY_CS;
    logic   [  `M:0]    CTRL_SYNARRAY_ADDR;
    
    // Outputs to neurons -------------------------------------
    logic               CTRL_NEUR_EVENT; 
    logic               CTRL_NEUR_TREF;
    logic      [3:0]    CTRL_NEUR_VIRTS;
    logic               CTRL_NEURMEM_WE;
    logic   [`M-1:0]    CTRL_NEURMEM_ADDR;
    
    // Outputs to scheduler -----------------------------------
    logic               CTRL_SCHED_POP_N;
    logic     [`M:0]    CTRL_SCHED_ADDR;
    logic               CTRL_SCHED_EVENT_IN;
    logic    [  3:0]    CTRL_SCHED_VIRTS;
    
    // Output to AER output -----------------------------------
    logic               CTRL_AEROUT_POP_NEUR;

    // Neuron core input
    logic  [  25:0]     SYNARRAY_RDATA;

    // Neuron core outputs
    logic    [  3:0]    NEUR_STATE;
    logic               NEUR_EVENT_OUT;
    logic               NEUR_CTRL_BUSY;
    logic    [  7:0]    ADDR_D;
    logic    [  3:0]    SYN_WEIGHT;

    reg [31:0] BRAM_Neuron_reg[255:0];
    reg [11:0] BRAM_Synapse_reg[4095:0];

    assign neurons_0.neurarray_0.BRAM_Neuron = BRAM_Neuron_reg;
    assign neurons_0.synarray_0.BRAM_Synapse = BRAM_Synapse_reg;

    logic RSTN;
    
    assign RSTN = ~RST;

    /***************************
      INIT 
	***************************/ 
    
    initial begin
        AERIN_ADDR  = 10'b0;
        AERIN_REQ   =  1'b0;
        // AEROUT_ACK  =  1'b0;
        
        CTRL_READBACK_EVENT = 1'b0;
        CTRL_PROG_EVENT = 1'b0;
        CTRL_SPI_ADDR = {(2*`M){1'b0}};
        CTRL_OP_CODE = 2'b0;

        SPI_GATE_ACTIVITY       = 1'b0;
        SPI_GATE_ACTIVITY_sync  = 1'b0;
        SPI_MAX_NEUR           = {`M{1'b0}};

        AEROUT_CTRL_BUSY    = 1'b0;
        SYNARRAY_RDATA      = {17'd100, 8'd5};

    end

    /***************************
      CLK
	***************************/ 
	
	initial begin
		CLK = 1'b1; 
		forever begin
			wait_ns(`CLK_HALF_PERIOD);
            CLK = ~CLK; 
	    end
	end 

    /***************************
      RST
	***************************/
	
	initial begin 
        wait_ns(0.1);
        RST = 1'b0;
        wait_ns(100);
        RST = 1'b1;
        wait_ns(100);
        RST = 1'b0;
	end

//    initial begin 
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
//        wait_ns(1000);
//        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);

//        wait_ns(100);
//        $finish;
//	end

    /***************************
      STIMULI GENERATION
	***************************/
    initial begin
        // Load memories from .mem files
        $display("Memory files loading to BRAMs");
        $readmemb("/home/p306945/Projects/FPGA/tinyODIN/src/neuron_memory_data.mem", BRAM_Neuron_reg);
        $readmemb("/home/p306945/Projects/FPGA/tinyODIN/src/bram_synapse_data.mem", BRAM_Synapse_reg);
        //$readmemb("/home/s6425496/tinyODIN_r01/src/bram_lut_data.mem", BRAM_LUT_reg);
        $display("Memory loaded.");

        wait_ns(201);
        
        // Send some AER input events
        aer_send(10'd1, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd2, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd3, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd4, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd5, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd6, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd7, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd8, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd9, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd10, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd11, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd12, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        wait_ns(100);
        aer_send(10'd13, AERIN_ADDR, AERIN_ACK, AERIN_REQ);

        // aer_send(10'd15, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // aer_send(10'd20, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // aer_send(10'd25, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        
        wait_ns(1000);
        $finish;
    end

    controller ut (
        .CLK                (CLK),
        .RST                (RST),
        .AERIN_ADDR         (AERIN_ADDR),
        .AERIN_REQ          (AERIN_REQ),
        .AERIN_ACK          (AERIN_ACK),
        .CTRL_READBACK_EVENT(CTRL_READBACK_EVENT),
        .CTRL_PROG_EVENT    (CTRL_PROG_EVENT),
        .CTRL_SPI_ADDR      (CTRL_SPI_ADDR),
        .CTRL_OP_CODE       (CTRL_OP_CODE),
        .SPI_GATE_ACTIVITY  (SPI_GATE_ACTIVITY),
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),
        .SPI_MAX_NEUR       (SPI_MAX_NEUR),
        .SCHED_EMPTY        (SCHED_EMPTY),
        .SCHED_FULL         (SCHED_FULL),
        .SCHED_DATA_OUT     (SCHED_DATA_OUT),
        .NEUR_CTRL_BUSY     (NEUR_CTRL_BUSY),
        .AEROUT_CTRL_BUSY   (AEROUT_CTRL_BUSY),
        .CTRL_SYNARRAY_WE   (CTRL_SYNARRAY_WE),
        .CTRL_SYNARRAY_CS   (CTRL_SYNARRAY_CS),
        .CTRL_SYNARRAY_ADDR (CTRL_SYNARRAY_ADDR),
        .CTRL_NEUR_EVENT    (CTRL_NEUR_EVENT),
        .CTRL_NEUR_TREF     (CTRL_NEUR_TREF),
        .CTRL_NEUR_VIRTS    (CTRL_NEUR_VIRTS),
        .CTRL_NEURMEM_WE    (CTRL_NEURMEM_WE),
        .CTRL_NEURMEM_ADDR  (CTRL_NEURMEM_ADDR),
        .CTRL_SCHED_POP_N   (CTRL_SCHED_POP_N),
        .CTRL_SCHED_ADDR    (CTRL_SCHED_ADDR),
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),
        .CTRL_SCHED_VIRTS   (CTRL_SCHED_VIRTS),
        .CTRL_AEROUT_POP_NEUR(CTRL_AEROUT_POP_NEUR)
    );
    
    scheduler scheduler_0 ( 
    
        // Global inputs ------------------------------------------
        .CLK                (CLK),
        .RSTN               (RSTN),
        
        // Inputs from controller ---------------------------------
        .CTRL_SCHED_POP_N(CTRL_SCHED_POP_N),
        .CTRL_SCHED_VIRTS(CTRL_SCHED_VIRTS),
        .CTRL_SCHED_ADDR(CTRL_SCHED_ADDR),
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),
        
        // Inputs from neurons ------------------------------------
        .CTRL_NEURMEM_ADDR(ADDR_D),
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        
        // Inputs from SPI configuration registers ----------------
        .SPI_OPEN_LOOP(1'b1),
        
        // Outputs ------------------------------------------------
        .SCHED_EMPTY(SCHED_EMPTY),
        .SCHED_FULL(SCHED_FULL),
        .SCHED_DATA_OUT(SCHED_DATA_OUT)
    );

    neuron_core neurons_0 (
        
        // Global inputs ------------------------------------------
        .CLK                (CLK),
        .RST                (RST),
        
        // Inputs from SPI configuration registers ----------------
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),
        
        // Synaptic inputs ----------------------------------------
        // Now carries  <base_addr, count> info from BRAM_LUT
        .SYNARRAY_RDATA(SYNARRAY_RDATA),
        
        // Inputs from controller ---------------------------------
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),
        .CTRL_NEUR_TREF(CTRL_NEUR_TREF),
        .CTRL_NEUR_VIRTS(CTRL_NEUR_VIRTS),
        .CTRL_NEURMEM_CS(1'b0),
        .CTRL_NEURMEM_WE(1'b0),
        .CTRL_NEURMEM_ADDR(CTRL_NEURMEM_ADDR),
        .CTRL_PROG_DATA(8'b0),
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),

        // Outputs ------------------------------------------------
        .NEUR_STATE(NEUR_STATE),
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        .NEUR_CTRL_BUSY(NEUR_CTRL_BUSY),
        .ADDR_D(ADDR_D),  
        .SYN_WEIGHT(SYN_WEIGHT)
    );

    /***********************************************************************
						    TASK IMPLEMENTATIONS
    ************************************************************************/ 

    /***************************
	 SIMPLE TIME-HANDLING TASKS
	***************************/

    task wait_ns;
        input   tics_ns;
        integer tics_ns;
        #tics_ns;
    endtask

    /***************************
	 AER send event
	***************************/
    
    task automatic aer_send (
        input  logic [`M+1:0] addr_in,
        ref    logic [`M+1:0] addr_out,
        ref    logic          ack,
        ref    logic          req
    );
        while (ack) wait_ns(1);
        addr_out = addr_in;
        wait_ns(5);
        req = 1'b1;
        while (!ack) wait_ns(1);
        wait_ns(5);
        req = 1'b0;
	endtask
endmodule
