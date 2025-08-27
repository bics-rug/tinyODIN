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
// "controller.v" - Controller module
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
// Modify Date: 28/08/2025 04:37:30 PM
// Module Name: controller
// Target Devices: Kr260 - Olla
// 
// Revision: r0.1
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module controller #(
    parameter N = 256,
    parameter M = 8
)(    

    // Global inputs ------------------------------------------
    input  wire           CLK,
    input  wire           RST,
    
    // Inputs from AER ----------------------------------------
    input  wire   [M+1:0] AERIN_ADDR,
    input  wire           AERIN_REQ,
    output reg            AERIN_ACK,
    
    // Control interface for readback -------------------------
    input  wire           CTRL_READBACK_EVENT,
    input  wire           CTRL_PROG_EVENT,
    input  wire [2*M-1:0] CTRL_SPI_ADDR,
    input  wire     [1:0] CTRL_OP_CODE,
    
    // Inputs from SPI configuration registers ----------------
    input  wire           SPI_GATE_ACTIVITY, 
    output reg            SPI_GATE_ACTIVITY_sync,
    input  wire   [M-1:0] SPI_MAX_NEUR,
    
    // Inputs from scheduler ----------------------------------
    input  wire           SCHED_EMPTY,
    input  wire           SCHED_FULL,
    input  wire    [12:0] SCHED_DATA_OUT,

    // Inputs from neuron core --------------------------------
    input  wire           NEUR_CTRL_BUSY,
    
    // Input from AER output ----------------------------------
    input  wire           AEROUT_CTRL_BUSY,
    
    // Outputs to synaptic core -------------------------------
    output reg            CTRL_SYNARRAY_WE,
    output reg            CTRL_SYNARRAY_CS,
    output reg    [  M:0] CTRL_SYNARRAY_ADDR,
    
    // Outputs to neurons -------------------------------------
    output reg            CTRL_NEUR_EVENT, 
    output reg            CTRL_NEUR_TREF,
    output reg      [3:0] CTRL_NEUR_VIRTS,
    output reg            CTRL_NEURMEM_WE,
    output reg    [M-1:0] CTRL_NEURMEM_ADDR,
    
    // Outputs to scheduler -----------------------------------
    output reg            CTRL_SCHED_POP_N,
    output reg    [M-1:0] CTRL_SCHED_ADDR,
    output reg            CTRL_SCHED_EVENT_IN,
    output reg    [  3:0] CTRL_SCHED_VIRTS,
    
    // Output to AER output -----------------------------------
    output wire           CTRL_AEROUT_POP_NEUR
);
    
	//----------------------------------------------------------------------------------
	//	PARAMETERS 
	//----------------------------------------------------------------------------------

	// FSM states 
	localparam WAIT             = 4'd0; 
    localparam W_NEUR           = 4'd1;
    localparam R_NEUR           = 4'd2;
    localparam W_SYN            = 4'd3;
    localparam R_SYN            = 4'd4;
	localparam TREF             = 4'd5;
	localparam TREF_WAIT        = 4'd6;
    localparam PUSH             = 4'd7;
	localparam POP_NEUR         = 4'd8;
    localparam POP_NEUR_WAIT    = 4'd9;
    localparam POP_VIRT         = 4'd10;
    localparam AER_POP          = 4'd11;
    localparam WAIT_SPIDN       = 4'd12;
    localparam WAIT_REQDN       = 4'd13;


	//----------------------------------------------------------------------------------
	//	REGS & WIRES
	//----------------------------------------------------------------------------------
    
    reg          AERIN_REQ_sync_int, AERIN_REQ_sync;
    reg          SPI_GATE_ACTIVITY_sync_int;
    reg          CTRL_READBACK_EVENT_sync_int, CTRL_READBACK_EVENT_sync;
    reg          CTRL_PROG_EVENT_sync_int, CTRL_PROG_EVENT_sync;

    wire         tref_event, virt_event, neuron_event;
    
    // reg  [ 31:0] ctrl_cnt;
    
    reg  [  3:0] state, nextstate;
    
	//----------------------------------------------------------------------------------
	//	EVENT TYPE DECODING 
	//----------------------------------------------------------------------------------

    assign tref_event        = AERIN_ADDR[M  ];
    assign virt_event        = AERIN_ADDR[M+1];
    assign neuron_event      = !tref_event && !virt_event;
    assign CTRL_AEROUT_POP_NEUR = (state == POP_NEUR_WAIT) && (nextstate != POP_NEUR_WAIT);

	//----------------------------------------------------------------------------------
	//	SYNC BARRIERS FROM AER AND FROM SPI
	//----------------------------------------------------------------------------------
    
   always @(posedge CLK, posedge RST) begin
		if(RST) begin
			AERIN_REQ_sync_int           <= 1'b0;
			AERIN_REQ_sync	             <= 1'b0;
            SPI_GATE_ACTIVITY_sync_int   <= 1'b0;
            SPI_GATE_ACTIVITY_sync       <= 1'b0;
            CTRL_READBACK_EVENT_sync_int <= 1'b0;
            CTRL_READBACK_EVENT_sync     <= 1'b0;
            CTRL_PROG_EVENT_sync_int     <= 1'b0;
            CTRL_PROG_EVENT_sync         <= 1'b0;
		end
		else begin
			AERIN_REQ_sync_int           <= AERIN_REQ;
			AERIN_REQ_sync	             <= AERIN_REQ_sync_int;
            SPI_GATE_ACTIVITY_sync_int   <= SPI_GATE_ACTIVITY;
            SPI_GATE_ACTIVITY_sync       <= SPI_GATE_ACTIVITY_sync_int;
            CTRL_READBACK_EVENT_sync_int <= CTRL_READBACK_EVENT;
            CTRL_READBACK_EVENT_sync     <= CTRL_READBACK_EVENT_sync_int;
            CTRL_PROG_EVENT_sync_int     <= CTRL_PROG_EVENT;
            CTRL_PROG_EVENT_sync         <= CTRL_PROG_EVENT_sync_int;
		end
	end
    
	//----------------------------------------------------------------------------------
	//	CONTROL FSM
	//----------------------------------------------------------------------------------
    
    // State register
	always @(posedge CLK, posedge RST)
	begin
		if   (RST) state <= WAIT;
		else       state <= nextstate;
	end
    
	// Next state logic
	always @(*) begin
        // Default assignments.
		case(state)
			WAIT 		    :	if      (AEROUT_CTRL_BUSY)                                                          nextstate = WAIT;
			                    // TODO: Add W/R to Neuron Core
//                                else if (SPI_GATE_ACTIVITY_sync)
//                                    if      (CTRL_PROG_EVENT_sync     && (CTRL_OP_CODE == 2'b01))                   nextstate = W_NEUR;
//                                    else if (CTRL_READBACK_EVENT_sync && (CTRL_OP_CODE == 2'b01))                   nextstate = R_NEUR;
//                                    else if (CTRL_PROG_EVENT_sync     && (CTRL_OP_CODE == 2'b10))                   nextstate = W_SYN;
//                                    else if (CTRL_READBACK_EVENT_sync && (CTRL_OP_CODE == 2'b10))                   nextstate = R_SYN;
//                                    else                                                                            nextstate = WAIT;
                                else
                                    if (SCHED_FULL)
                                        if      (|SCHED_DATA_OUT[12:9])                                             nextstate = POP_VIRT;
                                        else                                                                        nextstate = POP_NEUR;
                                    else if (AERIN_REQ_sync)
                                        if      (tref_event)                                                        nextstate = TREF;
                                        else if (virt_event | neuron_event)                                         nextstate = PUSH;
                                        else                                                                        nextstate = WAIT;
                                    else if (~SCHED_EMPTY)
                                        if      (|SCHED_DATA_OUT[12:9])                                             nextstate = POP_VIRT;
                                        else                                                                        nextstate = POP_NEUR;
                                    else                                                                            nextstate = WAIT;
//			W_NEUR    	    :   if      (ctrl_cnt == 32'd1 )                                                        nextstate = WAIT_SPIDN; // TODO: Add W/R to Neuron Core
//						    	else					                                                            nextstate = W_NEUR;     // TODO: Add W/R to Neuron Core
//			R_NEUR    	    :                                                                                       nextstate = WAIT_SPIDN; // TODO: Add W/R to Neuron Core
//			W_SYN    	    :   if      (ctrl_cnt == 32'd1 )                                                        nextstate = WAIT_SPIDN; // TODO: Add W/R to Neuron Core
//						    	else					                                                            nextstate = W_SYN;      // TODO: Add W/R to Neuron Core
//			R_SYN    	    :                                                                                       nextstate = WAIT_SPIDN; // TODO: Add W/R to Neuron Core
			TREF            :                                                                                       nextstate = TREF_WAIT;
			TREF_WAIT    	:   if      (!NEUR_CTRL_BUSY)                                                           nextstate = WAIT_REQDN; // TODO: Check timing
						    	else					                                                            nextstate = TREF_WAIT;
            PUSH            :                                                                                       nextstate = WAIT_REQDN;
            POP_NEUR        :                                                                                       nextstate = POP_NEUR_WAIT; 
			POP_NEUR_WAIT   :   if      (!NEUR_CTRL_BUSY)                                                           nextstate = AER_POP;
						    	else					                                                            nextstate = POP_NEUR_WAIT; 
//			POP_VIRT        :   if      (~CTRL_SCHED_POP_N)                                                         nextstate = WAIT;      // TODO: Add virtual
//						    	else					                                                            nextstate = POP_VIRT;
            AER_POP         :   if      (!AEROUT_CTRL_BUSY)                                                         nextstate = WAIT;
                                else                                                                                nextstate = AER_POP; 
			WAIT_SPIDN 	    :   if      (~CTRL_PROG_EVENT_sync && ~CTRL_READBACK_EVENT_sync)                        nextstate = WAIT;
						    	else					                                                            nextstate = WAIT_SPIDN;
			WAIT_REQDN 	    :   if      (~AERIN_REQ_sync)                                                           nextstate = WAIT;
						    	else					                                                            nextstate = WAIT_REQDN;
			default		    :							                                                            nextstate = WAIT;
		endcase 
    end

    // Output logic      
    always @(*) begin
        if (state == TREF) begin
            CTRL_SYNARRAY_ADDR  = 9'b0;
            CTRL_SYNARRAY_CS    = 1'b0;
            CTRL_SYNARRAY_WE    = 1'b0;
            CTRL_NEURMEM_ADDR   = 8'b0;
            CTRL_NEURMEM_WE     = 1'b0;
            CTRL_NEUR_VIRTS     = 4'b0;
            CTRL_SCHED_VIRTS    = 4'b0;
            CTRL_SCHED_ADDR     = 8'b0;
            CTRL_SCHED_EVENT_IN = 1'b0;
            CTRL_SCHED_POP_N    = 1'b1;
            AERIN_ACK           = 1'b0;
            
            CTRL_NEUR_EVENT     = 1'b0;
            CTRL_NEUR_TREF      = 1'b1;

        end else if (state == PUSH) begin
            CTRL_SYNARRAY_ADDR  = 9'b0;
            CTRL_SYNARRAY_CS    = 1'b0;
            CTRL_SYNARRAY_WE    = 1'b0;
            CTRL_NEURMEM_ADDR   = 8'b0;
            CTRL_NEURMEM_WE     = 1'b0;
            CTRL_NEUR_VIRTS     = 4'b0;
            CTRL_NEUR_EVENT     = 1'b0;
            CTRL_NEUR_TREF      = 1'b0;
            CTRL_SCHED_POP_N    = 1'b1;
            AERIN_ACK           = 1'b0;
            
            CTRL_SCHED_VIRTS    = AERIN_ADDR[M+1] ?        AERIN_ADDR[M-1:4]  :              4'b0;
            CTRL_SCHED_ADDR     = AERIN_ADDR[M+1] ? {4'h0, AERIN_ADDR[  3:0]} : AERIN_ADDR[M-1:0];
            CTRL_SCHED_EVENT_IN = 1'b1;

        end else if (state == POP_NEUR) begin  
            CTRL_NEURMEM_ADDR   = 8'b0;
            CTRL_NEURMEM_WE     = 1'b0;
            CTRL_NEUR_VIRTS     = 4'b0;
            CTRL_NEUR_TREF      = 1'b0;
            CTRL_SCHED_VIRTS    = 4'b0;
            CTRL_SCHED_ADDR     = 8'b0;
            CTRL_SCHED_EVENT_IN = 1'b0;
            AERIN_ACK           = 1'b0;
            
            CTRL_SYNARRAY_ADDR  = SCHED_DATA_OUT[M:0];
            CTRL_SYNARRAY_CS    = 1'b1;
            CTRL_SYNARRAY_WE    = 1'b0;
            CTRL_SCHED_POP_N    = 1'b1;
            CTRL_NEUR_EVENT     = 1'b1;
        
//        end else if (state == POP_VIRT) begin  
//            CTRL_SYNARRAY_ADDR  = 9'b0;
//            CTRL_SYNARRAY_CS    = 1'b0;
//            CTRL_SYNARRAY_WE    = 1'b0;
//            CTRL_NEUR_TREF      = 1'b0;
//            CTRL_SCHED_VIRTS    = 4'b0;
//            CTRL_SCHED_ADDR     = 8'b0;
//            CTRL_SCHED_EVENT_IN = 1'b0;
//            AERIN_ACK           = 1'b0;
            
//            CTRL_NEURMEM_ADDR   = SCHED_DATA_OUT[M-1:0];
//            CTRL_NEUR_VIRTS     = SCHED_DATA_OUT[ 11:M];
//            CTRL_NEUR_EVENT     = 1'b1;

        
        end else if (state == AER_POP) begin  
            CTRL_SYNARRAY_ADDR  = 9'b0;
            CTRL_SYNARRAY_CS    = 1'b0;
            CTRL_SYNARRAY_WE    = 1'b0;
            CTRL_NEURMEM_ADDR   = 8'b0;
            CTRL_NEURMEM_WE     = 1'b0;
            CTRL_NEUR_VIRTS     = 4'b0;
            CTRL_NEUR_EVENT     = 1'b0;
            CTRL_NEUR_TREF      = 1'b0;
            CTRL_SCHED_VIRTS    = 4'b0;
            CTRL_SCHED_ADDR     = 8'b0;
            CTRL_SCHED_EVENT_IN = 1'b0;
            AERIN_ACK           = 1'b0;

            CTRL_SCHED_POP_N    = AEROUT_CTRL_BUSY;
        
        end else if (state == WAIT_REQDN) begin
            CTRL_SYNARRAY_ADDR  = 9'b0;
            CTRL_SYNARRAY_CS    = 1'b0;
            CTRL_SYNARRAY_WE    = 1'b0;
            CTRL_NEURMEM_ADDR   = 8'b0;
            CTRL_NEURMEM_WE     = 1'b0;
            CTRL_NEUR_VIRTS     = 4'b0;
            CTRL_NEUR_EVENT     = 1'b0;
            CTRL_NEUR_TREF      = 1'b0;
            CTRL_SCHED_VIRTS    = 4'b0;
            CTRL_SCHED_ADDR     = 8'b0;
            CTRL_SCHED_EVENT_IN = 1'b0;
            CTRL_SCHED_POP_N    = 1'b1;
            
            AERIN_ACK           = 1'b1;

        end else begin
            CTRL_SYNARRAY_ADDR  = 9'b0;
            CTRL_SYNARRAY_CS    = 1'b0;
            CTRL_SYNARRAY_WE    = 1'b0;
            CTRL_NEURMEM_ADDR   = 8'b0;
            CTRL_NEURMEM_WE     = 1'b0;
            CTRL_NEUR_VIRTS     = 4'b0;
            CTRL_NEUR_EVENT     = 1'b0;
            CTRL_NEUR_TREF      = 1'b0;
            CTRL_SCHED_VIRTS    = 4'b0;
            CTRL_SCHED_ADDR     = 8'b0;
            CTRL_SCHED_EVENT_IN = 1'b0;
            CTRL_SCHED_POP_N    = 1'b1;
            AERIN_ACK           = 1'b0;
        end
    end

    
endmodule


