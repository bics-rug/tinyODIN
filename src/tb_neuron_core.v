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


module tb_neuron_core #(
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
	//output wire [    M:0][1:0]  OUTPUT_BITS_ONION,
    output wire  [         M:0] OUTPUT_BITS_ONION_p,
    output wire  [         M:0] OUTPUT_BITS_ONION_n,
	input  wire 	            OUTPUT_BITS_ONION_A_AO,

    // Input 10-bit AER -------------------------------
    // input  wire [  M+1:0]       AERIN_ADDR,
    // input  wire                 AERIN_REQ,
    // output wire 		        AERIN_ACK,

    // Output 9-bit AER ------------------------------
    // output wire [         M:0]  AEROUT_ADDR,
    // output wire                 AEROUT_REQ,
    // input  wire                 AEROUT_ACK,
    output wire                 LED,

    // Debug ------------------------------------------
    output wire                 SCHED_FULL
);

    //----------------------------------------------------------------------------------
	//	Internal regs and wires
	//----------------------------------------------------------------------------------

    // Reset
    reg                  RST_sync_int, RST_sync;
    reg                  RST;   
    reg  [   15:0]       reset_counter = 16'h0000;

    // // AER output
    wire                 AEROUT_CTRL_BUSY;

    // Controller
    wire [      2*M-1:0] CTRL_SPI_ADDR;
    wire [      2*M-1:0] CTRL_PROG_DATA;
    reg                  CTRL_NEUR_EVENT; 
    wire                 CTRL_NEUR_TREF;  
    wire [          3:0] CTRL_NEUR_VIRTS;
    wire                 NEUR_CTRL_BUSY;
    wire [          7:0] ADDR_D;
    
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

    // ILA (Integrated Logic Analyzer)
    always @(posedge CLK) begin
        DEBUG_SGNL <= ~DEBUG_SGNL;
	end
      
    always @(posedge DEBUG_SGNL) begin
        CTRL_NEUR_EVENT <= ~CTRL_NEUR_EVENT;
	end

    neuron_core #(
        .N(N),
        .M(M)
    ) neuron_core_0 (
    
        // Global inputs ------------------------------------------
        .CLK(CLK),
        .RST(RST),                                              
        
        // Inputs from SPI configuration registers ----------------
        .SPI_GATE_ACTIVITY_sync(1'b0),
		
        // Synaptic inputs ----------------------------------------
        .SYNARRAY_RDATA(25'h0000102), //0000102

        // AEROUT inputs
        .AEROUT_CTRL_BUSY(1'b0),

        // Olla Input
        .OUTPUT_BITS_ONION_A_AO(1'b0),
        
        // Inputs from controller ---------------------------------
        .CTRL_NEUR_EVENT(CTRL_NEUR_EVENT),
        .CTRL_NEUR_TREF(1'b0),
        .CTRL_NEUR_VIRTS(4'h0),
        .CTRL_PROG_DATA(16'h0000),
        .CTRL_SPI_ADDR(16'h0000),  

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


