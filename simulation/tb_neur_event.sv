`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/08/2025 03:58:11 PM
// Design Name: 
// Module Name: tb_neur_event
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

`define CLK_HALF_PERIOD             2
`define SCK_HALF_PERIOD            25

`define N 256 
`define M 8

`define PROGRAM_ALL_SYNAPSES      1
`define VERIFY_ALL_SYNAPSES       1
`define PROGRAM_NEURON_MEMORY     1
`define VERIFY_NEURON_MEMORY      1
`define DO_FULL_CHECK             1
`define     DO_OPEN_LOOP          1
`define     DO_CLOSED_LOOP        1
 
`define SPI_OPEN_LOOP          1'b1
`define SPI_AER_SRC_CTRL_nNEUR 1'b0
`define SPI_MAX_NEUR         8'd200

module tb_neur_event();

    logic CLK;
    logic RST;
    logic SCK, MOSI, MISO;
    logic [`M:0][1:0] OUTPUT_BITS_ONION;
    logic OUTPUT_BITS_ONION_A_AO;
    wire  SCHED_FULL;

    localparam M = 8;
    localparam CLK_PERIOD = 10ns;
    localparam SCK_PERIOD = 50ns;

    logic [`M+1:0] tb_AERIN_ADDR;
    logic          tb_AERIN_REQ;
    logic          tb_AERIN_ACK;

    logic [M-1:0] expected_chain[3];
    logic [M-1:0] received_addr;

    tinyODIN #(.M(M)) dut (
        .CLK(CLK),
        .RST(RST),
        .SCK(SCK),
        .MOSI(MOSI),
        .MISO(MISO),
        .OUTPUT_BITS_ONION(OUTPUT_BITS_ONION),
        .OUTPUT_BITS_ONION_A_AO(OUTPUT_BITS_ONION_A_AO),
        .SCHED_FULL(SCHED_FULL)
    );

    reg [24:0] BRAM_LUT_reg [511:0];
    reg [11:0] BRAM_Synapse_reg [4095:0];
    reg [31:0] BRAM_Neuron_reg [255:0];

    assign dut.neuron_core_0.neurarray_0.BRAM_Neuron = BRAM_Neuron_reg;
    assign dut.neuron_core_0.synarray_0.BRAM_Synapse = BRAM_Synapse_reg;
    assign dut.synaptic_core_0.BRAM_Lut = BRAM_LUT_reg;

    assign dut.controller_0.AERIN_REQ  = tb_AERIN_REQ;
    assign dut.controller_0.AERIN_ADDR = tb_AERIN_ADDR;
    assign tb_AERIN_ACK = dut.controller_0.AERIN_ACK;

    initial begin
        CLK = 1'b0;
        forever #(CLK_PERIOD/2) CLK = ~CLK;
    end

    // Main Test Scenario

    initial begin
        $display("--- tinyODIN BRAM Testbench Starting ---");

        // Load memories from .mem files
        $display("Memory files loading to BRAMs");
        $readmemb("/home/s6425496/tinyODIN_r01/src/neuron_memory_data.mem", BRAM_Neuron_reg);
        $readmemb("/home/s6425496/tinyODIN_r01/src/bram_synapse_data.mem", BRAM_Synapse_reg);
        $readmemb("/home/s6425496/tinyODIN_r01/src/bram_lut_data.mem", BRAM_LUT_reg);
        $display("Memory loaded.");

        // Start and Reset
        RST = 1'b1;
        OUTPUT_BITS_ONION_A_AO = 1'b0;
        #(2 * CLK_PERIOD);
        RST = 1'b0;
        #(10 * CLK_PERIOD);

        // SPI Bypass
        $display("--- Phase 1: Setting the configuration registers... ---");
        force dut.spi_slave_0.SPI_GATE_ACTIVITY = 1'b0;
        force dut.spi_slave_0.SPI_OPEN_LOOP = 1'b0;
        force dut.spi_slave_0.SPI_MAX_NEUR = 8'd255;
        force dut.spi_slave_0.SPI_AER_SRC_CTRL_nNEUR = 1'b0;
        $display("Configuration completed. Neural event started.");

        // Send single "neur_event"
        $display("\n--- Phase 2: Sending single neural event to neuron 5. ---");
        aer_send({2'b00, 8'd5});

        // Verify the Output
        $display("\n--- Phase 3: Output array verifying ---");
        expected_chain = '{176, 179, 135};

        for (int i=0; i < 3; i++) begin
            pdr_receive_and_check(received_addr);
            assert (received_addr == expected_chain[i]) 
                else   $fatal(1, "Test Failed: Expected peak neuron %0d, Received peak neuron %0d.", expected_chain[i], received_addr);
            $display("Success: Expected peak received: Neuron %0d.", received_addr);
        end

        $display("\n----------------------------------------------------------");
        $display("--- Test Completed: Neuron chain worked as expected. ---");
        $display("----------------------------------------------------------");
        $stop;

    end


    /***********************************************************************
						    TASK IMPLEMENTATIONS
    ************************************************************************/ 

    task automatic pdr_receive_and_check(output logic [M-1:0] received_addr);
        @(posedge CLK);
        wait (|OUTPUT_BITS_ONION);
        for (int i = 0; i < M; i++) received_addr[i] = OUTPUT_BITS_ONION[i][1];
        $display("[%0t ns] INFO: Testbench PDR Receiver: Neuron %0d spike received.", $time, received_addr);
        OUTPUT_BITS_ONION_A_AO = 1'b1;
        #10ns;
        wait (~|OUTPUT_BITS_ONION);
        OUTPUT_BITS_ONION_A_AO = 1'b0;
    endtask

    
    /***************************
	 AER send event
	***************************/
    
    task automatic aer_send (input  logic [`M+1:0] addr);
        $display("[%0t ns] INFO: AER event sending: Adres %0d", $time, addr[`M-1:0]);
        tb_AERIN_REQ = 1'b1;
        tb_AERIN_ADDR = addr;
        wait(tb_AERIN_ACK);
        tb_AERIN_REQ = 1'b0;
        wait(!tb_AERIN_ACK);
        $display("[%0t ns] INFO: AER event sent.", $time);
	endtask

endmodule
