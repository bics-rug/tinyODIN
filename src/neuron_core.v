// Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland),
//         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the "License"); you may not use this file except in compliance
// with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
//------------------------------------------------------------------------------
//
// "neuron_core.v" - File containing the time-multiplexed neuron array based on 12-bit leaky integrate-and-fire (LIF) neurons
//                   (as opposed to ODIN, which both 8-bit LIF and custom phenomenological Izhikevich neuron models)
// 
// Project: tinyODIN - A low-cost digital spiking neuromorphic processor adapted from ODIN.
//
// Author:  C. Frenkel, Delft University of Technology
//
// Cite/paper: C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm² 12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning
//             Digital Spiking Neuromorphic Processor in 28-nm CMOS," IEEE Transactions on Biomedical Circuits and Systems,
//             vol. 13, no. 1, pp. 145-158, 2019.
//
//------------------------------------------------------------------------------

//////////////////////////////////////////////////////////////////////////////////
// Company: University of Groningen
// Engineer: H. Basri Bilge
//
// Create Date: 28/08/2025 04:37:30 PM
// Module Name: neuron_core
// Target Devices: Kr260 - Olla
//
// Revision: r0.2
// Revision 0.01 - File Created
// Revision 0.02 - Added TREF event handling and new states
// Additional Comments: Adapted from neucon_core.v C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm² 
//                      12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning
//                      Digital Spiking Neuromorphic Processor in 28-nm CMOS," IEEE Transactions on Biomedical Circuits and Systems,
//                      vol. 13, no. 1, pp. 145-158, 2019.
//
//////////////////////////////////////////////////////////////////////////////////


module neuron_core #(
    parameter N = 256,
    parameter M = 8,
    parameter MAX_LIF_NEURONS = 4
)(

    // Global inputs ------------------------------------------
    input  wire                 CLK,
    input  wire                 RST,

    // Inputs from SPI configuration registers ----------------
    input  wire                 SPI_GATE_ACTIVITY_sync,

    // Synaptic inputs ----------------------------------------
    // Now carries  <base_addr, count> info from BRAM_LUT
    input  wire [         24:0] SYNARRAY_RDATA,

    // Inputs from controller ---------------------------------
    input  wire                 CTRL_NEUR_EVENT,
    input  wire                 CTRL_NEUR_TREF,
    input  wire [          3:0] CTRL_NEUR_VIRTS,
    input  wire [      2*M-1:0] CTRL_PROG_DATA,
    input  wire [      2*M-1:0] CTRL_SPI_ADDR,
    input  wire 	            OUTPUT_BITS_ONION_A_AO,
    
    // AER out input
    input  wire                 AEROUT_CTRL_BUSY,

    // Outputs ------------------------------------------------
    output wire [         31:0] NEUR_STATE,
    output wire                 NEUR_EVENT_OUT,
    output wire [          M:0] OUTPUT_BITS_ONION_p,
    output wire [          M:0] OUTPUT_BITS_ONION_n,
    output wire                 NEUR_CTRL_BUSY,
    output wire [          7:0] ADDR_D,
    output wire [          3:0] SYN_WEIGHT  // TODO: Change to OLLA
);
    //---------------------------------------------------------
    // FSM states, Wires and Regs
    //---------------------------------------------------------
    //localparam OP_MODE        = 1'b1; // 1: Olla-mode --- 0: AER-mode

    localparam S_IDLE         = 4'd0;
    localparam S_FETCH_SYN    = 4'd1;
    localparam S_WAIT_EVENT   = 4'd2;
    localparam S_WRITE_EVENT  = 4'd3;
    localparam S_WRITE_WAIT   = 4'd4;
    localparam S_READ_TREF    = 4'd5;
    localparam S_WRITE_TREF   = 4'd6;
    localparam S_WRITE_OLLA   = 4'd7;

    reg [3:0]  state, state_next;

    localparam S_OLLA_IDLE    = 2'd0;
    localparam S_OLLA_VALID   = 2'd1;
    localparam S_OLLA_NEUTRAL = 2'd2;

    reg [1:0]  olla_state, next_olla_state;

    // Counters
    reg   [    7:0] post_syn_counter;
    reg   [    7:0] tref_counter;
    wire            post_syn_counter_inc;

    // Neuron address and weight
    reg   [    7:0] neur_mem_addr_int;
    reg   [    3:0] syn_weight_reg;

    reg            CTRL_NEURMEM_CS_REG;
    reg            CTRL_NEURMEM_WE_REG;

    // Synaptic event for the neuron
    reg            syn_event;
    reg            time_ref;

    // Latched info from SYNARRAY_RDATA
    wire   [   16:0] base_addr;
    wire   [    7:0] read_length;

    // BRAM Interfaces
    wire  [   16:0] synapse_bram_addr;
    wire  [   12:0] synapse_bram_rdata;
    wire  [   11:0] syn_wdata; // SPI write data information (not used)

    // LIF Neuron Interface
    wire [    3:0] syn_weight;
    wire           LIF_neuron_event_out;
    wire [   11:0] LIF_neuron_next_NEUR_STATE;
    wire [   31:0] neuron_data;

    wire           mem_cs_mux;
    wire           mem_we_mux;
    wire           syn_cs_mux;

    wire           OLLA_NEUR_BUSY;
    wire           OUT_NEUR_BUSY;

    reg  [   8:0]  olla_data_latch;
    wire    [8:0]  olla_data_wire;

    reg            OP_MODE;
    wire           OP_MODE_wire;

    //---------------------------------------------------------
    //  Combinational Logic
    //---------------------------------------------------------

    // FSM is busy whenever it is not in the IDLE state.
    assign NEUR_CTRL_BUSY = (state != S_IDLE);

    // Processing inputs from the synaptic array and the controller
    assign syn_weight   = |CTRL_NEUR_VIRTS ? CTRL_NEUR_VIRTS : syn_weight_reg;

    // Neuron output spike events
    assign NEUR_EVENT_OUT = (NEUR_STATE[31] | OP_MODE == 1'b1) ? 1'b0 : ((CTRL_NEURMEM_CS_REG && CTRL_NEURMEM_WE_REG) ? LIF_neuron_event_out : 1'b0);

    // Memory Control Logic
    assign mem_cs_mux = CTRL_NEURMEM_CS_REG;
    assign mem_we_mux = CTRL_NEURMEM_WE_REG;
    assign syn_cs_mux = (state == S_FETCH_SYN);

    // BRAM_Synapse Memory Output assignments.
    assign ADDR_D       = neur_mem_addr_int;
    assign SYN_WEIGHT   = syn_weight; // Output synapse weight 
    
    // BRAM_Synapse input
    assign base_addr    = SYNARRAY_RDATA[24:8];  // Address information for BRAM_Synapse
    assign read_length  = SYNARRAY_RDATA[7:0];   // Counter information for BRAM_Synapse
    assign synapse_bram_addr = base_addr + post_syn_counter; // Address for the Synapse Bram is calculated based on the latched base address and counter.

    // Data to be written into the neuron memory
    assign neuron_data = {NEUR_STATE[31:12], LIF_neuron_next_NEUR_STATE};

    // Olla busy signal
    assign OLLA_NEUR_BUSY = (olla_state != S_OLLA_IDLE);

    // Busy signal for FSM operations
    assign OUT_NEUR_BUSY = (OP_MODE) ? OLLA_NEUR_BUSY : AEROUT_CTRL_BUSY;

    assign olla_data_wire = olla_data_latch;
    assign OP_MODE_wire = OP_MODE;

    //***********************************
    //
    // (SPI Write function) *Coming soon*
    //
    //***********************************

    // State register Main
	always @(posedge CLK, posedge RST)
	begin
		if   (RST)  state <= S_IDLE;
        else state <= state_next;
	end

    // State register Olla
	always @(posedge CLK, posedge RST)
	begin
		if   (RST)  olla_state <= S_OLLA_IDLE;
        else olla_state <= next_olla_state;
	end

    assign post_syn_counter_inc = (state == S_WRITE_WAIT) && !OUT_NEUR_BUSY;
    assign tref_counter_inc = (state == S_WRITE_TREF) && !OUT_NEUR_BUSY;
    
    always @(posedge CLK, posedge RST)
		if      (RST)                   post_syn_counter <= 8'd0;
        else if (state == S_IDLE)       post_syn_counter <= 8'd0;
		else if (post_syn_counter_inc)  post_syn_counter <= post_syn_counter + 8'd1;
        else                            post_syn_counter <= post_syn_counter;

    always @(posedge CLK, posedge RST)
		if      (RST)                   tref_counter <= 8'd0;
        else if (state == S_IDLE)       tref_counter <= 8'd0;
		else if (tref_counter_inc)      tref_counter <= tref_counter + 8'd1;
        else                            tref_counter <= tref_counter;

    reg            DEBUG_SGNL = 1'b0;

    always @(posedge CLK) begin
        DEBUG_SGNL <= ~DEBUG_SGNL;
	end

    ila_2 your_instance_name (
	.clk(CLK), // input wire clk


	.probe0(DEBUG_SGNL), // input wire [0:0]  probe0  
	.probe1(SYNARRAY_RDATA), // input wire [24:0]  probe1 
	.probe2(state), // input wire [3:0]  probe2 
	.probe3(olla_state), // input wire [1:0]  probe3 
	.probe4(post_syn_counter), // input wire [7:0]  probe4 
	.probe5(ADDR_D), // input wire [7:0]  probe5 
	.probe6(OUT_NEUR_BUSY), // input wire [0:0]  probe6 
	.probe7(OUTPUT_BITS_ONION_p), // input wire [8:0]  probe7 
	.probe8(OUTPUT_BITS_ONION_n), // input wire [8:0]  probe8
    .probe9(OUTPUT_BITS_ONION_A_AO),
    .probe10(olla_data_wire),
    .probe11(synapse_bram_rdata),
    .probe12(post_syn_counter_inc),
    .probe13(OP_MODE_wire),
    .probe14(OLLA_NEUR_BUSY),
    .probe15(AEROUT_CTRL_BUSY)
);
    // Combinational FSM Logic: Determines next state and controls outputs.
    always @(*) begin        
        case (state)
        /* 0 */     S_IDLE:             if      (CTRL_NEUR_EVENT)                   state_next = S_FETCH_SYN;
                                        else if (CTRL_NEUR_TREF)                    state_next = S_READ_TREF;
                                        else                                        state_next = S_IDLE;

        /* 1 */     S_FETCH_SYN:        if (read_length == 8'd0)                    state_next = S_IDLE;
                                        else                                        state_next = S_WAIT_EVENT;

        /* 2 */     S_WAIT_EVENT:       if (!OUT_NEUR_BUSY)                         state_next = S_WRITE_EVENT;
                                        else                                        state_next = S_WAIT_EVENT;

        /* 3 */     S_WRITE_EVENT:                                                  state_next = S_WRITE_WAIT;

        /* 4 */     S_WRITE_WAIT:      if (!OUT_NEUR_BUSY)
                                        if (post_syn_counter == read_length - 1)    state_next = S_IDLE;
                                        else                                        state_next = S_FETCH_SYN;
                                    else                                            state_next = S_WRITE_WAIT;

        /* 5 */     S_READ_TREF:        if (!OUT_NEUR_BUSY)                         state_next = S_WRITE_TREF;
                                        else                                        state_next = S_READ_TREF;

        /* 6 */     S_WRITE_TREF:       if (tref_counter == MAX_LIF_NEURONS - 1)    state_next = S_IDLE;
                                        else                                        state_next = S_READ_TREF;

            default:                                                                state_next = S_IDLE;
        endcase
    end

    always @(*) begin
        case (olla_state)
        /* 0 */     S_OLLA_IDLE:        if (state == S_WRITE_EVENT && OP_MODE == 1'b1)      next_olla_state = S_OLLA_VALID;
                                else                                                        next_olla_state = S_OLLA_IDLE;

        /* 1 */     S_OLLA_VALID:       if (OUTPUT_BITS_ONION_A_AO)                         next_olla_state = S_OLLA_NEUTRAL;
                                else                                                        next_olla_state = S_OLLA_VALID;

        /* 2 */     S_OLLA_NEUTRAL:     if (!OUTPUT_BITS_ONION_A_AO)                        next_olla_state = S_OLLA_IDLE;
                                else                                                        next_olla_state = S_OLLA_NEUTRAL;

            default:                                                                        next_olla_state = S_OLLA_IDLE;
        endcase
    end

    genvar i;
    generate
        for (i=0; i < 9; i = i + 1) begin
            assign OUTPUT_BITS_ONION_p[i] = (olla_state == S_OLLA_VALID) ? (olla_data_latch[i] ? 1'b1 : 1'b0) : 1'b0;
            assign OUTPUT_BITS_ONION_n[i] = (olla_state == S_OLLA_VALID) ? (olla_data_latch[i] ? 1'b0 : 1'b1) : 1'b0;
        end
    endgenerate

    //---------------------------------------------------------
    //  Sequential Logic
    //---------------------------------------------------------
    always @(*) begin           
        
        if (state == S_FETCH_SYN) begin
            CTRL_NEURMEM_CS_REG      <= 1'b0;
            CTRL_NEURMEM_WE_REG      <= 1'b0;
            syn_event                <= 1'b0;
            time_ref                 <= 1'b0;
        end

        else if (state == S_WAIT_EVENT) begin
            syn_weight_reg           <= synapse_bram_rdata[3:0];
            neur_mem_addr_int        <= synapse_bram_rdata[11:4];
            olla_data_latch          <= {synapse_bram_rdata[8:4], synapse_bram_rdata[3:0]};
            OP_MODE                  <= synapse_bram_rdata[12];
            CTRL_NEURMEM_CS_REG      <= 1'b1;
            CTRL_NEURMEM_WE_REG      <= 1'b0;
            syn_event                <= 1'b1;
            time_ref                 <= 1'b0;
        end

        else if (state == S_WRITE_EVENT) begin
            syn_weight_reg           <= synapse_bram_rdata[3:0];
            neur_mem_addr_int        <= synapse_bram_rdata[11:4];
            olla_data_latch          <= {synapse_bram_rdata[8:4], synapse_bram_rdata[3:0]};
            OP_MODE                  <= synapse_bram_rdata[12];
            CTRL_NEURMEM_CS_REG      <= 1'b1;
            CTRL_NEURMEM_WE_REG      <= 1'b1;
            syn_event                <= 1'b1;
            time_ref                 <= 1'b0;
        end

        else if (state == S_WRITE_WAIT) begin
            syn_weight_reg           <= synapse_bram_rdata[3:0];
            neur_mem_addr_int        <= synapse_bram_rdata[11:4];
            olla_data_latch          <= {synapse_bram_rdata[8:4], synapse_bram_rdata[3:0]};
            OP_MODE                  <= synapse_bram_rdata[12];
            CTRL_NEURMEM_CS_REG      <= 1'b0;
            CTRL_NEURMEM_WE_REG      <= 1'b0;
            syn_event                <= 1'b0;
            time_ref                 <= 1'b0;
        end

        else if (state == S_READ_TREF) begin
            syn_weight_reg           <= 4'b0;
            olla_data_latch          <= 8'b0;
            neur_mem_addr_int        <= tref_counter;
            CTRL_NEURMEM_CS_REG      <= 1'b1;
            CTRL_NEURMEM_WE_REG      <= 1'b0;
            syn_event                <= 1'b0;
            time_ref                 <= 1'b1;
        end

        else if (state == S_WRITE_TREF) begin
            syn_weight_reg           <= 4'b0;
            olla_data_latch          <= 8'b0;
            neur_mem_addr_int        <= tref_counter;
            CTRL_NEURMEM_CS_REG      <= 1'b1;
            CTRL_NEURMEM_WE_REG      <= 1'b1;
            syn_event                <= 1'b0;
            time_ref                 <= 1'b1;
        end

        else begin
            syn_weight_reg            <= 4'b0;
            neur_mem_addr_int         <= 8'b0;
            olla_data_latch           <= 8'b0;
            OP_MODE                   <= 1'b0;
            CTRL_NEURMEM_CS_REG       <= 1'b0;
            CTRL_NEURMEM_WE_REG       <= 1'b0;
            syn_event                 <= 1'b0;
            time_ref                  <= 1'b0;
        end
            
    end


    // Neuron update logic for leaky integrate-and-fire (LIF) model

    lif_neuron lif_neuron_0 (
        .param_leak_str(            NEUR_STATE[30:24]),
        .param_thr(                 NEUR_STATE[23:12]),

        .state_core(                NEUR_STATE[11: 0]),
        .state_core_next(  LIF_neuron_next_NEUR_STATE),

        .syn_weight(                       syn_weight),
        .syn_event(                        syn_event),
        .time_ref(                           time_ref),

        .spike_out(              LIF_neuron_event_out)
    );

    // Neuron memory wrapper

    BRAM_256x32_wrapper neurarray_0 (
        .CK         (CLK),
        .CS         (mem_cs_mux),
        .WE         (mem_we_mux),
        .A          (neur_mem_addr_int),
        .D          (neuron_data),
        .Q          (NEUR_STATE)
    );

    BRAM_Synapse synarray_0 (
        .CK         (CLK),
        .CS         (syn_cs_mux),
        .WE         (1'b0),
        .A          (synapse_bram_addr),
        .D          (syn_wdata),
        .Q          (synapse_bram_rdata)
    );
endmodule


module BRAM_256x32_wrapper (

    // Global inputs
    input          CK,                       // Clock (synchronous read/write)

    // Control and data inputs
    input          CS,                       // Chip select
    input          WE,                       // Write enable
    input  [  7:0] A,                        // Address bus
    input  [ 31:0] D,                        // Data input bus (write)

    // Data output
    output [ 31:0] Q                         // Data output bus (read)
);
/*
     * Simple behavioral code for simulation, to be replaced by a 256-word 32-bit SRAM macro
     * or Block RAM (BRAM) memory with the same format for FPGA implementations.
     */
        reg [31:0] BRAM_Neuron[255:0];
        reg [31:0] Qr;

        assign Q = Qr;

        initial begin
            $readmemh("/home/s6425496/tinyODIN_r01/src/neuron_memory_data.mem", BRAM_Neuron);
        end

        always @(posedge CK) begin
        Qr <= CS ? BRAM_Neuron[A] : Qr;
        if (CS & WE) begin
            BRAM_Neuron[A] <= D;
        end
    end


endmodule

module BRAM_Synapse (

    // Global inputs
    input          CK,                       // Clock (synchronous read/write)

    // Control and data inputs
    input          CS,                       // Chip select
    input          WE,                       // Write enable
    input  [ 16:0] A,                        // Address bus
    input  [ 12:0] D,                        // Data input bus (write)

    // Data output
    output [ 12:0] Q                         // Data output bus (read)
);

        reg [12:0] BRAM_Synapse[4095:0];
        reg [12:0] Qr;

        assign Q = Qr;

        initial begin
            $readmemh("/home/s6425496/tinyODIN_r01/src/bram_synapse_data.mem", BRAM_Synapse);
        end

        always @(posedge CK) begin
        if (CS) begin
            Qr <= BRAM_Synapse[A];
            if (WE) begin
                BRAM_Synapse[A] <= D;
            end
        end else begin
            Qr <= Qr;
        end
    end
endmodule