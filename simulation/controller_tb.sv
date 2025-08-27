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



module controller_tb(
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

    // Inputs from neuron core --------------------------------
    logic               NEUR_CTRL_BUSY;
    
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
    
    logic RSTN;
    
    assign RSTN = ~RST;
    
    localparam IDLE             = 4'd0; 
    localparam FETCH           = 4'd1;
    localparam READ_NEUR           = 4'd2;
    localparam WRITE_NEUR            = 4'd3;
    
    reg  [  3:0] neur_state, nextneur_state;
    
    /***************************
      SIMULATE NEURON CORE 
	***************************/ 
	// State register
	always @(posedge CLK, posedge RST)
	begin
		if   (RST) neur_state <= IDLE;
		else       neur_state <= nextneur_state;
	end
	
    always @(*) begin
        // Default assignments.
		case(neur_state)
			IDLE :   if (CTRL_NEUR_EVENT)    nextneur_state = FETCH;
			         else                    nextneur_state = IDLE;
			FETCH :                          nextneur_state = READ_NEUR;
			READ_NEUR :                      nextneur_state = WRITE_NEUR;
			WRITE_NEUR :                     nextneur_state = IDLE;
			default:                         nextneur_state = IDLE;
	    endcase
	end
		
	assign NEUR_CTRL_BUSY = neur_state != IDLE;
    
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
        // SPI_GATE_ACTIVITY_sync  = 1'b0;
        SPI_MAX_NEUR           = {`M{1'b0}};

//        SCHED_EMPTY         = 1'b1;
//        SCHED_FULL          = 1'b0;
//        SCHED_DATA_OUT      = 13'b0;

        NEUR_CTRL_BUSY      = 1'b0;
        AEROUT_CTRL_BUSY    = 1'b0;

        // Outputs
        // CTRL_SYNARRAY_WE    = 1'b0;
        // CTRL_SYNARRAY_CS    = 1'b0;
        // CTRL_SYNARRAY_ADDR  = {(`M+1){1'b0}};

        // CTRL_NEUR_EVENT     = 1'b0;
        // CTRL_NEUR_TREF      = 1'b0;
        // CTRL_NEUR_VIRTS     = 4'b0;
        // CTRL_NEURMEM_WE     = 1'b0;
        // CTRL_NEURMEM_ADDR   = {`M{1'b0}};

        // CTRL_SCHED_POP_N    = 1'b0;
        // CTRL_SCHED_ADDR     = {(`M+1){1'b0}};
        // CTRL_SCHED_EVENT_IN = 1'b0;
        // CTRL_SCHED_VIRTS    = 4'b0;

        // CTRL_AEROUT_POP_NEUR = 1'b0;
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

    /***************************
      STIMULI GENERATION
	***************************/
    initial begin
        wait_ns(201);
        
        // Send some AER input events
        aer_send(10'd5, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        aer_send(10'd10, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
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
        .CTRL_NEURMEM_ADDR(CTRL_NEURMEM_ADDR),
        .NEUR_EVENT_OUT(1'b0),
        
        // Inputs from SPI configuration registers ----------------
        .SPI_OPEN_LOOP(1'b1),
        
        // Outputs ------------------------------------------------
        .SCHED_EMPTY(SCHED_EMPTY),
        .SCHED_FULL(SCHED_FULL),
        .SCHED_DATA_OUT(SCHED_DATA_OUT)
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
