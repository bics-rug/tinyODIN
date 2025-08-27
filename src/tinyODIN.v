`timescale 1ns / 1ps
// Copyright (C) 2019-2022, Universit� catholique de Louvain (UCLouvain, Belgium), University of Z�rich (UZH, Switzerland),
//         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the �License�); you may not use this file except in compliance
// with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
// an �AS IS� BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
//------------------------------------------------------------------------------
//
// "tinyODIN.v" - Toplevel file
// 
// Project: tinyODIN - A low-cost digital spiking neuromorphic processor adapted from ODIN.
//
// Author:  C. Frenkel, Delft University of Technology
//
// Cite/paper: C. Frenkel, M. Lefebvre, J.-D. Legat and D. Bol, "A 0.086-mm� 12.7-pJ/SOP 64k-Synapse 256-Neuron Online-Learning
//             Digital Spiking Neuromorphic Processor in 28-nm CMOS," IEEE Transactions on Biomedical Circuits and Systems,
//             vol. 13, no. 1, pp. 145-158, 2019.
//
//------------------------------------------------------------------------------


module tinyODIN #(
	parameter N = 256,
	parameter M = 8
)(
    // Global input     -------------------------------
    input  wire                 CLK,
    //input  wire                 RST,
    
    // SPI slave        -------------------------------
    input  wire                 SCK,
    input  wire                 MOSI,
    output wire                 MISO,

	// Output 9-bit AER -------------------------------
    output wire  [         M:0] OUTPUT_BITS_ONION_p,
    output wire  [         M:0] OUTPUT_BITS_ONION_n,
	//input  wire 	            OUTPUT_BITS_ONION_A_AO,

    output wire                 LED,

    // Debug ------------------------------------------
    output wire                 SCHED_FULL
);

    //----------------------------------------------------------------------------------
	//	Internal regs and wires
	//----------------------------------------------------------------------------------

    // Reset
    reg                  RST_sync_int, RST_sync;
    wire                 RSTN_sync;
    reg                  RST;   
    reg  [   15:0]       reset_counter = 16'h0000;

    // AER Input
    wire [  M+1:0]       AERIN_ADDR;
    wire                 AERIN_REQ;
    wire 		         AERIN_ACK;

    // // AER output
    wire                 AEROUT_CTRL_BUSY;
    wire [       M-1:0]  AEROUT_ADDR;
    wire                 AEROUT_REQ;
    wire                 AEROUT_ACK;

    // SPI + parameter bank
    wire                 SPI_GATE_ACTIVITY, SPI_GATE_ACTIVITY_sync;
    wire                 SPI_OPEN_LOOP;
    wire                 SPI_AER_SRC_CTRL_nNEUR;
    wire [        M-1:0] SPI_MAX_NEUR;

    // Controller
    wire                 CTRL_READBACK_EVENT;
    wire                 CTRL_PROG_EVENT;
    wire [      2*M-1:0] CTRL_SPI_ADDR;
    wire [          1:0] CTRL_OP_CODE;
    wire [      2*M-1:0] CTRL_PROG_DATA;
    wire                 CTRL_SYNARRAY_WE;
    wire                 CTRL_NEURMEM_WE;
    wire [          M:0] CTRL_SYNARRAY_ADDR;
    wire [        M-1:0] CTRL_NEURMEM_ADDR;
    wire                 CTRL_SYNARRAY_CS;
    wire                 CTRL_NEUR_EVENT; 
    wire                 CTRL_NEUR_TREF;  
    wire [          3:0] CTRL_NEUR_VIRTS;
    wire                 CTRL_SCHED_POP_N;
    wire [        M-1:0] CTRL_SCHED_ADDR;
    wire                 CTRL_SCHED_EVENT_IN;
    wire [          3:0] CTRL_SCHED_VIRTS;
    wire                 CTRL_AEROUT_POP_NEUR;
    wire                 NEUR_CTRL_BUSY;
    wire [          7:0] ADDR_D;
    
    // Synaptic core
    wire [         24:0] SYNARRAY_RDATA;
    
    // Scheduler
    wire                 SCHED_EMPTY;
    wire [         12:0] SCHED_DATA_OUT;
    
    // Neuron core
    wire [         31:0] NEUR_STATE;
    wire [          3:0] SYN_WEIGHT;
    wire                 NEUR_EVENT_OUT;
    
    reg                  DEBUG_SGNL = 1'b0;

    //----------------------------------------------------------------------------------
	//	Reset (with double sync barrier)
	//----------------------------------------------------------------------------------
    
    always @(posedge CLK) begin
        RST_sync_int <= RST;
		RST_sync     <= RST_sync_int;
	end
    
    assign RSTN_sync = ~RST_sync;

    always @(posedge CLK) begin
        if (reset_counter != 16'hFFFF) begin
            reset_counter <= reset_counter + 1;
        end
    end

    always @(*) begin
        if (reset_counter != 16'hFFFF) begin
            RST = 1'b1;
        end else begin
            RST = 1'b0;
        end
    end

    //----------------------------------------------------------------------------------
	//	AER STIMULUS GENERATOR
	//----------------------------------------------------------------------------------

    aer_stimulus_generator #(
        .M(M)
    ) aer_stimulus_generator_inst (
        .CLK(CLK),
        .RST(RST),
        // AER Interface (Output to tinyODIN's controller)
        .AERIN_ADDR(AERIN_ADDR),
        .AERIN_REQ(AERIN_REQ),
        .AERIN_ACK(AERIN_ACK)
    );

    //----------------------------------------------------------------------------------
	//	AER -> LED
	//----------------------------------------------------------------------------------

    // aer_to_LED #(
    //     .DATA_WIDTH(8)
    // ) aer_to_LED_inst
    // (
    //     // Global Inputs
    //     .CLK(CLK),
    //     .RST(RST),

    //     // AER Interface (Input from tinyODIN's aer_out)
    //     .AEROUT_ADDR(AEROUT_ADDR),
    //     .AEROUT_ACK(AEROUT_ACK),
    //     .AEROUT_REQ(AEROUT_REQ),

    //     // 4-phase Dual-Rail Interface (Output to Olla)
    //     .LED(LED)
    // );

    //----------------------------------------------------------------------------------
	//	Olla -> LED
	//----------------------------------------------------------------------------------

    olla_to_LED olla_to_LED_inst(
    .CLK(CLK),  
    .RST(RST),  
    .OUTPUT_BITS_ONION_p(OUTPUT_BITS_ONION_p),   
    .OUTPUT_BITS_ONION_n(OUTPUT_BITS_ONION_n),   
    .OUTPUT_BITS_ONION_A_AO(OUTPUT_BITS_ONION_A_AO),
    .LED(LED)
    );

    //----------------------------------------------------------------------------------
	//	AER OUT
	//----------------------------------------------------------------------------------

    aer_out #(
        .N(N),
        .M(M)
    ) aer_out_0 (

        // Global input ----------------------------------- 
        .CLK(CLK),
        .RST(RST_sync),
        
        // Inputs from SPI configuration latches ----------
        .SPI_GATE_ACTIVITY_sync(1'b0),
        .SPI_AER_SRC_CTRL_nNEUR(1'b0),
        
        // Neuron data inputs -----------------------------
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        .ADDR_D(ADDR_D),
        .SYN_WEIGHT(SYN_WEIGHT),
        
        // Input from scheduler ---------------------------
        .SCHED_DATA_OUT(SCHED_DATA_OUT),
        
        // Input from controller --------------------------
        .CTRL_AEROUT_POP_NEUR(CTRL_AEROUT_POP_NEUR),
        
        // Output to controller ---------------------------
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),
        
        // Output 8-bit AER link --------------------------
        .AEROUT_ADDR(AEROUT_ADDR),
        .AEROUT_REQ(AEROUT_REQ),
        .AEROUT_ACK(AEROUT_ACK)
    );
    
    
    //----------------------------------------------------------------------------------
	//	SPI + parameter bank
	//----------------------------------------------------------------------------------

    spi_slave #(
        .N(N),
        .M(M)
    ) spi_slave_0 (

        // Global inputs ------------------------------------------
        .RST_async(RST),
    
        // SPI slave interface ------------------------------------
        .SCK(SCK),
        .MISO(MISO),
        .MOSI(MOSI),
        
        // Control interface for readback -------------------------
        .CTRL_READBACK_EVENT(CTRL_READBACK_EVENT),
        .CTRL_PROG_EVENT(CTRL_PROG_EVENT),
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),
        .CTRL_OP_CODE(CTRL_OP_CODE),
        .CTRL_PROG_DATA(CTRL_PROG_DATA),
        .SYNARRAY_RDATA(SYNARRAY_RDATA),
        .NEUR_STATE(NEUR_STATE),
    
        // Configuration registers output -------------------------
        .SPI_GATE_ACTIVITY(SPI_GATE_ACTIVITY),
        .SPI_OPEN_LOOP(SPI_OPEN_LOOP),
        .SPI_AER_SRC_CTRL_nNEUR(SPI_AER_SRC_CTRL_nNEUR),
        .SPI_MAX_NEUR(SPI_MAX_NEUR)
    );
    
    
    //----------------------------------------------------------------------------------
	//	Controller
	//----------------------------------------------------------------------------------

    controller #(
        .N(N),
        .M(M)
    ) controller_0 (
    
        // Global inputs ------------------------------------------
        .CLK(CLK),
        .RST(RST_sync),
    
        // Inputs from AER ----------------------------------------
        .AERIN_ADDR(AERIN_ADDR),
        .AERIN_REQ(AERIN_REQ),
        .AERIN_ACK(AERIN_ACK),

        // Control interface for readback -------------------------
        .CTRL_READBACK_EVENT(1'b0),
        .CTRL_PROG_EVENT(1'b0),
        .CTRL_SPI_ADDR({(2*M){1'b0}}),
        .CTRL_OP_CODE(2'b0),
        
        // Inputs from SPI configuration registers ----------------
        .SPI_GATE_ACTIVITY(1'b0),
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),
        .SPI_MAX_NEUR({(M){1'b0}}),
        
        // Inputs from scheduler ----------------------------------
        .SCHED_EMPTY(SCHED_EMPTY),
        .SCHED_FULL(SCHED_FULL),
        .SCHED_DATA_OUT(SCHED_DATA_OUT),
        
        // Input from AER output ----------------------------------
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),
        
        // Outputs to synaptic core -------------------------------
        .CTRL_SYNARRAY_WE(CTRL_SYNARRAY_WE),
        .CTRL_SYNARRAY_ADDR(CTRL_SYNARRAY_ADDR),
        .CTRL_SYNARRAY_CS(CTRL_SYNARRAY_CS),
        .CTRL_NEURMEM_WE(CTRL_NEURMEM_WE),
        .CTRL_NEURMEM_ADDR(CTRL_NEURMEM_ADDR),

        // Inputs from neuron
        .NEUR_CTRL_BUSY(NEUR_CTRL_BUSY),  
        
        // Outputs to neurons -------------------------------------
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT), 
        .CTRL_NEUR_TREF(CTRL_NEUR_TREF),
        .CTRL_NEUR_VIRTS(CTRL_NEUR_VIRTS),
        
        // Outputs to scheduler -----------------------------------
        .CTRL_SCHED_POP_N(CTRL_SCHED_POP_N),
        .CTRL_SCHED_ADDR(CTRL_SCHED_ADDR),
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),
        .CTRL_SCHED_VIRTS(CTRL_SCHED_VIRTS),

        // Output to AER output -----------------------------------
        .CTRL_AEROUT_POP_NEUR(CTRL_AEROUT_POP_NEUR)
    );
    
    
    //----------------------------------------------------------------------------------
	//	Scheduler
	//----------------------------------------------------------------------------------

    scheduler #(
        .N(N),
        .M(M)
    ) scheduler_0 (
    
        // Global inputs ------------------------------------------
        .CLK(CLK),
        .RSTN(RSTN_sync),
    
        // Inputs from controller ---------------------------------
        .CTRL_SCHED_POP_N(CTRL_SCHED_POP_N),
        .CTRL_SCHED_VIRTS(CTRL_SCHED_VIRTS),
        .CTRL_SCHED_ADDR(CTRL_SCHED_ADDR),
        .CTRL_SCHED_EVENT_IN(CTRL_SCHED_EVENT_IN),
        
        // Inputs from neurons ------------------------------------
        .CTRL_NEURMEM_ADDR(ADDR_D),
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        
        // Inputs from SPI configuration registers ----------------
        .SPI_OPEN_LOOP(1'b0),
        
        // Outputs ------------------------------------------------
        .SCHED_EMPTY(SCHED_EMPTY),
        .SCHED_FULL(SCHED_FULL),
        .SCHED_DATA_OUT(SCHED_DATA_OUT)
    );
    
    
    //----------------------------------------------------------------------------------
	//	Synaptic core
	//----------------------------------------------------------------------------------
   
    synaptic_core #(
        .N(N),
        .M(M)
    ) synaptic_core_0 (
    
        // Global inputs ------------------------------------------
        .CLK(CLK),
        
        // Inputs from controller ---------------------------------
        .CTRL_SYNARRAY_WE(CTRL_SYNARRAY_WE),
        .CTRL_SYNARRAY_ADDR(CTRL_SYNARRAY_ADDR),
        .CTRL_SYNARRAY_CS(CTRL_SYNARRAY_CS),
        .CTRL_PROG_DATA(CTRL_PROG_DATA),
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),
        
        // Outputs ------------------------------------------------
        .SYNARRAY_RDATA(SYNARRAY_RDATA)
	);
    
    
    //----------------------------------------------------------------------------------
	//	Neuron core
	//----------------------------------------------------------------------------------
      
    neuron_core #(
        .N(N),
        .M(M)
    ) neuron_core_0 (
    
        // Global inputs ------------------------------------------
        .CLK(CLK),
        .RST(RST),                                              
        
        // Inputs from SPI configuration registers ----------------
        .SPI_GATE_ACTIVITY_sync(SPI_GATE_ACTIVITY_sync),
		
        // Synaptic inputs ----------------------------------------
        .SYNARRAY_RDATA(SYNARRAY_RDATA),

        // AEROUT inputs
        .AEROUT_CTRL_BUSY(AEROUT_CTRL_BUSY),

        // Olla Input
        .OUTPUT_BITS_ONION_A_AO(OUTPUT_BITS_ONION_A_AO),
        
        // Inputs from controller ---------------------------------
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),
        .CTRL_NEUR_TREF(CTRL_NEUR_TREF),
        .CTRL_NEUR_VIRTS(CTRL_NEUR_VIRTS),
        .CTRL_PROG_DATA(CTRL_PROG_DATA),
        .CTRL_SPI_ADDR(CTRL_SPI_ADDR),  

        // Outputs ------------------------------------------------
        .NEUR_CTRL_BUSY(NEUR_CTRL_BUSY),  
        .NEUR_STATE(NEUR_STATE),
        .NEUR_EVENT_OUT(NEUR_EVENT_OUT),
        .OUTPUT_BITS_ONION_p(OUTPUT_BITS_ONION_p),
        .OUTPUT_BITS_ONION_n(OUTPUT_BITS_ONION_n),
        .ADDR_D(ADDR_D),                                        
        .SYN_WEIGHT(SYN_WEIGHT)                                
    );
            
    
endmodule


