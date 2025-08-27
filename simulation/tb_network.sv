`timescale 1ns / 1ps

`define CLK_HALF_PERIOD    5
`define N                  256 
`define M                  8

module tb_network;

    localparam N = 256;
    localparam M = 8;
    localparam CLK_PERIOD = 10;

    logic CLK;
    logic RST;

    logic SCK = 0;
    logic MOSI = 0;
    wire  MISO;

    logic [M+1:0]  AERIN_ADDR;
    logic          AERIN_REQ;
    logic          AERIN_ACK;

    wire            SCHED_FULL;

    reg [31:0] BRAM_Neuron_reg[N-1:0];
    reg [24:0] BRAM_Lut_reg[2*N-1:0];
    reg [12:0] BRAM_Synapse_reg[4095:0];
    reg        AEROUT_ACK_reg;
    reg        OUTPUT_BITS_ONION_A_AO_reg;

    tinyODIN dut (
        .CLK(CLK),
        // .RST(RST),

        // .AERIN_ADDR(AERIN_ADDR),
        // .AERIN_ACK(AERIN_ACK),
        // .AERIN_REQ(AERIN_REQ),
        // .AEROUT_ADDR(AEROUT_ADDR),
        // .AEROUT_REQ(AEROUT_REQ),
        // .AEROUT_ACK(AEROUT_ACK),

        .SCHED_FULL(SCHED_FULL)
    );

    // assign dut.neuron_core_0.neurarray_0.BRAM_Neuron = BRAM_Neuron_reg;
    // assign dut.neuron_core_0.synarray_0.BRAM_Synapse = BRAM_Synapse_reg;
    // assign dut.synaptic_core_0.BRAM_Lut = BRAM_Lut_reg;

    // assign AEROUT_ACK = AEROUT_ACK_reg;
    // assign OUTPUT_BITS_ONION_A_AO = OUTPUT_BITS_ONION_A_AO_reg;

    initial begin
        CLK = 0;
        forever #(CLK_PERIOD / 2) CLK = ~CLK;
    end

    initial begin
        $display("--- tinyODIN Testbench Initializing ---");

        // $display("Memory files loading to BRAMs...");
        // $readmemb("/home/s6425496/tinyODIN_r01/src/neuron_memory_data.mem", BRAM_Neuron_reg);
        // $readmemb("/home/s6425496/tinyODIN_r01/src/bram_synapse_data.mem", BRAM_Synapse_reg);
        // $readmemb("/home/s6425496/tinyODIN_r01/src/bram_lut_data.mem", BRAM_Lut_reg);
        // $display("Memory files loaded.");

        // AERIN_REQ = 1'b0;
        // AERIN_ADDR = '0;
        // RST = 1;
        // repeat(5) @(posedge CLK);
        // RST = 0;
        // $display("[%0t ns] Reset released.", $time);
        // repeat(5) @(posedge CLK);
       
        // $display("SPI configuration with force.");
        // force dut.spi_slave_0.CTRL_READBACK_EVENT = 1'b0;
        // force dut.spi_slave_0.CTRL_PROG_EVENT = 1'b0;
        // force dut.spi_slave_0.CTRL_OP_CODE = 2'b0;
        // force dut.spi_slave_0.CTRL_SPI_ADDR = {(2*`M){1'b0}};

        // force dut.spi_slave_0.SPI_GATE_ACTIVITY = 1'b0;
        // force dut.spi_slave_0.SPI_OPEN_LOOP = 1'b0;
        // force dut.spi_slave_0.SPI_MAX_NEUR = {`M{1'b0}};
        // force dut.spi_slave_0.SPI_AER_SRC_CTRL_nNEUR = 1'b0;

        // $display("Neural event stage.");
       
        // // Send neural event
        // wait_ns(201);
        
        // // Send some AER input events
        // aer_send(10'd0, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send(10'd1, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send(10'd2, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send(10'd3, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send(10'd4, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send({2'b01, 8'hFF}, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send(10'd5, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send(10'd6, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send(10'd7, AERIN_ADDR, AERIN_ACK, AERIN_REQ);
        // wait_ns(100);
        // aer_send(10'd8, AERIN_ADDR, AERIN_ACK, AERIN_REQ);


        // repeat(20) @(posedge CLK);
        // $display("[%0t ns] --- Test Scenario Completed ---", $time);
        // $finish;
    end
   
    // Handshake Sequence for AER
    // initial begin
    //     wait_ns(200);
    //     forever begin
    //         @(posedge AEROUT_REQ);
    //         wait_ns(10);
    //         AEROUT_ACK_reg = 1'b1;
    //         @(negedge AEROUT_REQ);
    //         wait_ns(10);
    //         AEROUT_ACK_reg = 1'b0;
    //         end
    // end

    // // Handshake sequence for Olla
    // initial begin
    //     wait_ns(200);
    //     forever begin
            
    //     end
    // end

    // Monitoring
    always @(posedge CLK) begin
        if (SCHED_FULL) begin
            $warning("[%0t ns] WARN: Scheduler full!", $time);
        end
    end

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