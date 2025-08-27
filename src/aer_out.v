`timescale 1ns / 1ps
// Copyright (C) 2019-2022, Université catholique de Louvain (UCLouvain, Belgium), University of Zürich (UZH, Switzerland),
//         Katholieke Universiteit Leuven (KU Leuven, Belgium), and Delft University of Technology (TU Delft, Netherlands).
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
//
// Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file except in compliance
// with the License, or, at your option, the Apache License version 2.0. You may obtain a copy of the License at
// https://solderpad.org/licenses/SHL-2.1/
//
// Unless required by applicable law or agreed to in writing, any work distributed under the License is distributed on
// an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
// specific language governing permissions and limitations under the License.
//
//------------------------------------------------------------------------------
//
// "aer_out.v" - Output AER module, custom monitoring mode from ODIN was removed
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


module aer_out #(
	parameter N = 256,
	parameter M = 8
)(

    // Global input ----------------------------------- 
    input  wire           CLK,
    input  wire           RST,
    
    // Inputs from SPI configuration latches ----------
    input  wire           SPI_GATE_ACTIVITY_sync,
    input  wire           SPI_AER_SRC_CTRL_nNEUR,
    
    // Neuron data inputs -----------------------------
    input  wire           NEUR_EVENT_OUT,
    input  wire [  M-1:0] ADDR_D,
    input  wire [    3:0] SYN_WEIGHT,
    
    // Input from scheduler ---------------------------
    input  wire [   12:0] SCHED_DATA_OUT,
  
    // Input from controller --------------------------
    input  wire           CTRL_AEROUT_POP_NEUR,
    
    // Output to controller ---------------------------
    output wire            AEROUT_CTRL_BUSY,
    
	// Output 9-bit AER link --------------------------
	output wire  [    M-1:0] AEROUT_ADDR,
	output wire    	        AEROUT_REQ,
	input  wire 	        AEROUT_ACK
);


    reg            AEROUT_ACK_sync_int, AEROUT_ACK_sync, AEROUT_ACK_sync_del;
    wire           AEROUT_ACK_sync_negedge;
    wire           rst_activity;

    reg            AEROUT_CTRL_BUSY_reg;
    reg            AEROUT_REQ_reg;
    reg    [M-1:0] AEROUT_ADDR_reg;   

    assign rst_activity = RST || SPI_GATE_ACTIVITY_sync;

    assign AEROUT_CTRL_BUSY = AEROUT_CTRL_BUSY_reg;
    assign AEROUT_ADDR = AEROUT_ADDR_reg;
    assign AEROUT_REQ  = AEROUT_REQ_reg;

    //ILA
    reg            DEBUG_SGNL = 1'b0;

    always @(posedge CLK) begin
        DEBUG_SGNL <= ~DEBUG_SGNL;
	end

    ila_3 aer_out_ila_inst (
	.clk(CLK), // input wire clk


	.probe0(DEBUG_SGNL), // input wire [0:0]  probe0  
	.probe1(AEROUT_ADDR), // input wire [7:0]  probe1 
	.probe2(AEROUT_REQ), // input wire [0:0]  probe2 
	.probe3(AEROUT_ACK), // input wire [0:0]  probe3 
	.probe4(NEUR_EVENT_OUT) // input wire [0:0]  probe4

);
   
   // Sync barrier
   always @(posedge CLK) begin
		if (rst_activity) begin
			AEROUT_ACK_sync_int <= 1'b0;
			AEROUT_ACK_sync	    <= 1'b0;
			AEROUT_ACK_sync_del <= 1'b0;
		end
		else begin
			AEROUT_ACK_sync_int <= AEROUT_ACK;
			AEROUT_ACK_sync	    <= AEROUT_ACK_sync_int;
			AEROUT_ACK_sync_del <= AEROUT_ACK_sync;
		end
	end
    assign AEROUT_ACK_sync_negedge = ~AEROUT_ACK_sync & AEROUT_ACK_sync_del;
    
    
    // Output AER interface
    always @(posedge CLK) begin
		if (rst_activity) begin
			AEROUT_ADDR_reg             <= 8'b0;
			AEROUT_REQ_reg              <= 1'b0;
            AEROUT_CTRL_BUSY_reg        <= 1'b0;
		end else begin
            if (NEUR_EVENT_OUT && ~AEROUT_ACK_sync) begin
                AEROUT_ADDR_reg      <= ADDR_D;
                AEROUT_REQ_reg       <= 1'b1;
                AEROUT_CTRL_BUSY_reg <= 1'b1;
            end else if (AEROUT_ACK_sync) begin
                AEROUT_REQ_reg       <= 1'b0;
                AEROUT_CTRL_BUSY_reg <= 1'b1;
            end else if (AEROUT_ACK_sync_negedge) begin
                AEROUT_REQ_reg       <= 1'b0;
                AEROUT_CTRL_BUSY_reg <= 1'b0;
            end 
            // For Debugging
            // else begin
            //     AEROUT_ADDR_reg      <= 8'b0;
            //     AEROUT_REQ_reg       <= 1'b0;
            //     AEROUT_CTRL_BUSY_reg <= 1'b0;
            // end 
        end
	end


endmodule 
