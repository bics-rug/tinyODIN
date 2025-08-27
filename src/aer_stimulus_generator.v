`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Groningen 
// Engineer: H. Basri Bilge
// 
// Module Name: aer_stimulus_generator
// Target Devices: Kr260 - Olla
// Revision: r0.2 (handshake corrected)
// 
// Description:
// Generates a sequence of AER input events with proper handshake:
//   REQ ↑ → ACK ↑ → REQ ↓ → ACK ↓
//
// This module is fully synthesizable.
//
//////////////////////////////////////////////////////////////////////////////////

module aer_stimulus_generator
    #(
        parameter M = 8
    )
    (
        input   wire                    CLK,
        input   wire                    RST,

        // AER Interface (Output to tinyODIN controller)
        output  reg   [M+1:0]           AERIN_ADDR,
        output  reg                     AERIN_REQ,
        input   wire                    AERIN_ACK
    );

    // Internal counters
    reg [7:0] event_counter;
    reg [4:0] delay_counter;

    // FSM states
    localparam [2:0]
        STATE_IDLE          = 3'd0,
        STATE_SEND_REQ      = 3'd1,
        STATE_WAIT_ACK_HIGH = 3'd2,
        STATE_WAIT_ACK_LOW  = 3'd3,
        STATE_WAIT_DELAY    = 3'd4;

    reg [2:0] current_state;

    // Sequential logic
    always @(posedge CLK or posedge RST) begin
        if (RST) begin
            AERIN_REQ       <= 1'b0;
            AERIN_ADDR      <= {M+2{1'b0}};
            event_counter   <= 8'd0;
            delay_counter   <= 5'd0;
            current_state   <= STATE_IDLE;
        end else begin
            case (current_state)
                //--------------------------------------------------------------
                STATE_IDLE: begin
                    // Prepare next event
                    case (event_counter)
                        8'd0: AERIN_ADDR <= {2'b00, 8'd1};
                        8'd1: AERIN_ADDR <= {2'b00, 8'd1};
                        8'd2: AERIN_ADDR <= {2'b00, 8'd1};
                        8'd3: AERIN_ADDR <= {2'b00, 8'd1};
                        8'd4: AERIN_ADDR <= {2'b00, 8'd1};
                        default: begin
                            AERIN_ADDR    <= {2'b00, 8'd1};
                            event_counter <= 8'd0;
                        end
                    endcase
                    current_state <= STATE_SEND_REQ;
                end

                //--------------------------------------------------------------
                STATE_SEND_REQ: begin
                    // Assert REQ to signal event ready
                    AERIN_REQ <= 1'b1;
                    if (AERIN_ACK)
                        current_state <= STATE_WAIT_ACK_LOW;
                    else
                        current_state <= STATE_WAIT_ACK_HIGH;
                end

                //--------------------------------------------------------------
                STATE_WAIT_ACK_HIGH: begin
                    // Wait for receiver to acknowledge
                    if (AERIN_ACK) begin
                        AERIN_REQ     <= 1'b0;  // drop REQ
                        current_state <= STATE_WAIT_ACK_LOW;
                    end
                end

                //--------------------------------------------------------------
                STATE_WAIT_ACK_LOW: begin
                    // Wait until ACK drops again (handshake complete)
                    if (!AERIN_ACK) begin
                        event_counter <= event_counter + 1'b1;
                        delay_counter <= 5'd0;
                        current_state <= STATE_WAIT_DELAY;
                    end
                end

                //--------------------------------------------------------------
                STATE_WAIT_DELAY: begin
                    // Optional delay between events (prevents back-to-back firing)
                    if (delay_counter == 5'd20) begin
                        delay_counter <= 5'd0;
                        current_state <= STATE_IDLE;
                    end else begin
                        delay_counter <= delay_counter + 1'b1;
                    end
                end

                //--------------------------------------------------------------
                default: current_state <= STATE_IDLE;
            endcase
        end
    end

endmodule
