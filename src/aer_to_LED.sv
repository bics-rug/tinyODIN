`timescale 1ns / 1ps
module aer_to_LED
    #(
        parameter DATA_WIDTH = 8 // Data width set to 8 bits
    )
    (
    // Global Signals
    input   logic                           CLK,  
    input   logic                           RST,  

    // AER Interface
    input   logic   [DATA_WIDTH-1:0]        AEROUT_ADDR,
    output  logic                           AEROUT_ACK,
    input   logic                           AEROUT_REQ,

    // Output
    output  logic                           LED        
    );

    // PARAMETERS
    localparam int ONE_SEC_LIMIT = 25_000_000 - 1;
    localparam logic [DATA_WIDTH-1:0] LED_ADDR = 8'd2;

    // FSM State Definitions (Updated)
    typedef enum logic [3:0] {
        S_IDLE,                
        S_CHECK_ADDR,          
        S_TIMER_START,          
        S_TIMER_WAIT,          
        S_TIMER_END,           
        S_BLANK_WAIT,          
        S_SEND_ACK,            
        S_WAIT_REQ_LOW,        
        S_ACK_LOW              
    } state_t;

    state_t state, next_state;

    logic   [DATA_WIDTH-1:0] latched_addr;
    logic   [26:0]           counter_reg;

    //---------------------------------------------------------
    // 1. Sequential Logic: Counter and Latched Address
    //---------------------------------------------------------
    always_ff @(posedge CLK)
    begin
        if (RST) begin
            counter_reg  <= '0;
            latched_addr <= '0;
        end
        else begin
            // Latch Address
            if (state == S_IDLE && AEROUT_REQ)
                latched_addr <= AEROUT_ADDR;

            // Counter Logic: Increments in S_TIMER_WAIT (ON time) OR S_BLANK_WAIT (OFF time)
            if (state == S_TIMER_WAIT || state == S_BLANK_WAIT) begin
                if (counter_reg == ONE_SEC_LIMIT)
                    counter_reg <= '0;
                else
                    counter_reg <= counter_reg + 1;
            end
            // Reset counter when a new timer sequence starts
            else if (state == S_TIMER_START || state == S_TIMER_END)
                counter_reg <= '0;
            else if (counter_reg != '0)
                counter_reg <= '0;
        end
    end

    //---------------------------------------------------------
    // 2. Sequential Logic: State Register
    //---------------------------------------------------------
    always_ff @(posedge CLK)
    begin
        if   (RST)  state <= S_IDLE;
        else        state <= next_state;
    end

    //----------------------------------------------------------
    // 3. Combinational Logic: Next State Determination (FSM)
    //----------------------------------------------------------
    always_comb begin
        next_state = state;

        case (state)
            S_IDLE:             if (AEROUT_REQ)
                                    next_state = S_CHECK_ADDR;
           
            S_CHECK_ADDR:       if (latched_addr == LED_ADDR)
                                    next_state = S_TIMER_START;
                                else
                                    next_state = S_SEND_ACK;
           
            S_TIMER_START:      next_state = S_TIMER_WAIT;
                               
            S_TIMER_WAIT:       if (counter_reg == ONE_SEC_LIMIT)
                                    next_state = S_TIMER_END;
                               
            S_TIMER_END:        next_state = S_BLANK_WAIT;
                               
            S_BLANK_WAIT:       if (counter_reg == ONE_SEC_LIMIT)
                                    next_state = S_SEND_ACK;

            S_SEND_ACK:             next_state = S_WAIT_REQ_LOW;

            S_WAIT_REQ_LOW:     if (!AEROUT_REQ)
                                    next_state = S_ACK_LOW;
                               
            S_ACK_LOW:          next_state = S_IDLE;
                               
            default:            next_state = S_IDLE;
        endcase
    end

    //-----------------------------------------------------------
    // 4. Combinational Logic: Output Generation
    //-----------------------------------------------------------
    always_comb begin
        AEROUT_ACK = 1'b0;
        LED        = 1'b0;

        case (state)
            S_SEND_ACK, S_WAIT_REQ_LOW:
                AEROUT_ACK = 1'b1;
           
            S_TIMER_START, S_TIMER_WAIT:
                LED = 1'b1;
               
            default: ;
        endcase
    end

endmodule