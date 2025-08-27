`timescale 1ns / 1ps
`define CLK_PERIOD 10

module neuron_core_tb;

    // Parameters
    localparam N = 256;
    localparam M = 8;
    localparam MAX_LIF_NEURONS = 256;
    
    localparam S_IDLE  = 4'd0;
    localparam S_COUNT = 4'd1;


    // Testbench Signals
    logic                 CLK;
    logic                 RST;
    logic                 SPI_GATE_ACTIVITY_sync;
    logic [24:0]          SYNARRAY_RDATA;
    logic                 CTRL_NEUR_EVENT;
    logic                 CTRL_NEUR_TREF;
    logic [3:0]           CTRL_NEUR_VIRTS;
    logic                 CTRL_NEURMEM_CS;
    logic                 CTRL_NEURMEM_WE;
    logic [M-1:0]         CTRL_NEURMEM_ADDR;
    logic [2*M-1:0]       CTRL_PROG_DATA;
    logic [2*M-1:0]       CTRL_SPI_ADDR;
    
    logic                 AEROUT_CTRL_BUSY;
    
    logic [M-1:0]       AEROUT_ADDR;
    logic               AEROUT_REQ;
    logic               AEROUT_ACK;
    logic [7:0] aer_neur_spk;
    
    reg [3:0]  state, state_next;
    reg [    7:0] aer_counter;
    
    // Monitored Outputs
    wire [31:0]           NEUR_STATE;
    wire                  NEUR_EVENT_OUT;
    wire                  NEUR_CTRL_BUSY;
    wire [7:0]            ADDR_D;
    wire [3:0]            SYN_WEIGHT;

    // Instantiate the DUT (Device Under Test)
    neuron_core #(
        .N(N),
        .M(M),
        .MAX_LIF_NEURONS(MAX_LIF_NEURONS)
    ) dut (
        .CLK(CLK),
        .RST(RST),
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),
        .SYNARRAY_RDATA(SYNARRAY_RDATA),
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),
        .CTRL_NEUR_TREF(CTRL_NEUR_TREF),
        .CTRL_NEUR_VIRTS(CTRL_NEUR_VIRTS),
        .CTRL_NEURMEM_CS(CTRL_NEURMEM_CS),
        .CTRL_NEURMEM_WE(CTRL_NEURMEM_WE),
        .CTRL_NEURMEM_ADDR(CTRL_NEURMEM_ADDR),
        .CTRL_PROG_DATA(CTRL_PROG_DATA),
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),
        .NEUR_STATE(NEUR_STATE),
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        .NEUR_CTRL_BUSY(NEUR_CTRL_BUSY),
        .ADDR_D(ADDR_D),
        .SYN_WEIGHT(SYN_WEIGHT)
    );
    
    aer_out #(
        .N(N),
        .M(M)
    ) aer_out_0 (

        // Global input ----------------------------------- 
        .CLK(CLK),
        .RST(RST),
        
        // Inputs from SPI configuration latches ----------
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),
        .SPI_AER_SRC_CTRL_nNEUR(1'b0),
        
        // Neuron data inputs -----------------------------
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        .ADDR_D(ADDR_D),
        .SYN_WEIGHT(SYN_WEIGHT),
        
        // Input from scheduler ---------------------------
        .SCHED_DATA_OUT(13'b0),
        
        // Input from controller --------------------------
        .CTRL_AEROUT_POP_NEUR(1'b0),
        
        // Output to controller ---------------------------
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),
        
        // Output 8-bit AER link --------------------------
        .AEROUT_ADDR(AEROUT_ADDR),
        .AEROUT_REQ(AEROUT_REQ),
        .AEROUT_ACK(AEROUT_ACK)
    );
   
    reg [31:0] BRAM_Neuron_reg[255:0];
    reg [11:0] BRAM_Synapse_reg[4095:0];

    assign dut.neurarray_0.BRAM_Neuron = BRAM_Neuron_reg;
    assign dut.synarray_0.BRAM_Synapse = BRAM_Synapse_reg;
    
//    always @(posedge CLK, posedge RST)
//	begin
//		if   (RST)  state <= S_IDLE;
//        else state <= state_next;
//	end
	
//	assign AEROUT_CTRL_BUSY = (state == S_COUNT);
    
//    always @(*)
//    begin
//        case (state)
//            S_IDLE: if (NEUR_EVENT_OUT) state_next = S_COUNT;
//                    else                state_next = S_IDLE;
//            S_COUNT: if (aer_counter < 8'd10)   state_next = S_COUNT;
//                     else                       state_next = S_IDLE;
//            default: state_next = S_IDLE; 
//        endcase
//    end
    
//    always @(posedge CLK, posedge RST)
//		if      (RST)                   aer_counter <= 8'd0;
//        else if (state == S_IDLE)       aer_counter <= 8'd0;
//		else if (state == S_COUNT)      aer_counter <= aer_counter + 8'd1;
//        else                            aer_counter <= aer_counter;


    // Clock Generation
    initial begin
        CLK = 0;
        forever #(`CLK_PERIOD/2) CLK = ~CLK;
    end

    // Stimulus Task
    task apply_stimulus;
        input logic neur_event;
        input logic neur_tref;
        input [24:0] syn_data;
       
        @(posedge CLK);
        CTRL_NEUR_EVENT <= neur_event;
        CTRL_NEUR_TREF <= neur_tref;
        SYNARRAY_RDATA <= syn_data;
       
        // Wait for the busy signal to go high
        wait(dut.NEUR_CTRL_BUSY);
        $display("[%0t ns] INFO: Neuron core is busy.", $time);

        // De-assert signals after one cycle
        @(posedge CLK);
        CTRL_NEUR_EVENT <= 0;
        CTRL_NEUR_TREF <= 0;
       
        // Wait for the operation to complete
        wait(!dut.NEUR_CTRL_BUSY);
        $display("[%0t ns] INFO: Neuron core finished processing.", $time);
       
    endtask
                
    // Main Test Scenario
    initial begin
        $display("--- Testbench Starting ---");
       
        // Initialize signals
        RST = 1;
        SPI_GATE_ACTIVITY_sync = 0;
        SYNARRAY_RDATA = 0;
        CTRL_NEUR_EVENT = 0;
        CTRL_NEUR_TREF = 0;
        CTRL_NEUR_VIRTS = 0;
        CTRL_NEURMEM_CS = 0;
        CTRL_NEURMEM_WE = 0;
        CTRL_NEURMEM_ADDR = 0;
        CTRL_PROG_DATA = 0;
        CTRL_SPI_ADDR = 0;

        // Load memories from .mem files
        $display("Memory files loading to BRAMs");
        $readmemb("/home/p306945/Projects/FPGA/tinyODIN/src/neuron_memory_data.mem", BRAM_Neuron_reg);
        $readmemb("/home/p306945/Projects/FPGA/tinyODIN/src/bram_synapse_data.mem", BRAM_Synapse_reg);
        //$readmemb("/home/s6425496/tinyODIN_r01/src/bram_lut_data.mem", BRAM_LUT_reg);
        $display("Memory loaded.");
        
        fork
            auto_ack(.req(AEROUT_REQ), .ack(AEROUT_ACK), .addr(AEROUT_ADDR), .neur(aer_neur_spk));
        join_none
       
        // Apply reset
        #(`CLK_PERIOD * 2);
        RST = 0;
        #(`CLK_PERIOD * 2);
        $display("[%0t ns] INFO: Reset released.", $time);
       
        // --- Test Case 1: Synaptic Event ---
        $display("\n--- Test Case 1: Sending a synaptic event ---");
        // SYNARRAY_RDATA: {base_addr_reg (17 bits), read_length_reg (8 bits)}
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b0, 1'b1, 25'b0);
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 10);
        apply_stimulus(1'b1, 1'b0, {17'd100, 8'd5});
        #(`CLK_PERIOD * 20);
        apply_stimulus(1'b1, 1'b0, {17'd200, 8'd2}); // Synaptic event
        apply_stimulus(1'b1, 1'b0, {17'd300, 8'd3}); // Another synaptic event right after

//        // --- Test Case 2: Time Reference (Leakage) Event ---
//        $display("\n--- Test Case 2: Sending a TREF event to all neurons ---");
//        // SYNARRAY_RDATA is not used for TREF
//        apply_stimulus(1'b0, 1'b1, 25'b0);
//        #(`CLK_PERIOD * (MAX_LIF_NEURONS * 2 + 20)); // Wait for all neurons to be processed

//        // --- Test Case 3: Back-to-back events ---
//        $display("\n--- Test Case 3: Sending back-to-back events ---");
//        apply_stimulus(1'b1, 1'b0, {17'd200, 8'd2}); // Synaptic event
//        apply_stimulus(1'b1, 1'b0, {17'd300, 8'd3}); // Another synaptic event right after

//        #(`CLK_PERIOD * 20);

        $display("\n--- Testbench Finished ---");
        $finish;
    end

    // Monitor for spike events
    always @(posedge NEUR_EVENT_OUT) begin
        $display("[%0t ns] ***** SPIKE DETECTED from Neuron %d *****", $time, ADDR_D);
    end
    
    /***************************
	 SIMPLE TIME-HANDLING TASKS
	***************************/

    task wait_ns;
        input   tics_ns;
        integer tics_ns;
        #tics_ns;
    endtask
    
    /***************************
	 AER automatic acknowledge
	***************************/

    task automatic auto_ack (
        ref    logic       req,
        ref    logic       ack,
        ref    logic [7:0] addr,
        ref    logic [7:0] neur
    );
    
        forever begin
            while (~req) wait_ns(1);
            wait_ns(100);
            neur = addr;
            ack = 1'b1;
            while (req) wait_ns(1);
            wait_ns(100);
            ack = 1'b0;
        end

	endtask

endmodule