`timescale 1ns / 1ps
module olla_to_LED (
    // Global Signals
    input  logic                   CLK,  
    input  logic                   RST,  

    // Olla Dual-Rail Interface (9-bit veri, 18 dual-rail hattı)
    input  logic [DATA_BITS-1:0]   OUTPUT_BITS_ONION_p,    // Positive (True) Data Lines
    input  logic [DATA_BITS-1:0]   OUTPUT_BITS_ONION_n,    // Negative (False) Data Lines
    output logic                   OUTPUT_BITS_ONION_A_AO, // Acknowledge (ACK) to Sender

    // Output
    output logic                   LED    // LED output
    );

    //---------------------------------------------------------
    // Local Parameters
    //---------------------------------------------------------
    localparam int DATA_BITS = 9;
    localparam int COUNTER_WIDTH = 27; 
    // Örnek: CLK = 25 MHz ise 25,000,000 çevrim 1 saniyedir.
    localparam int ONE_SEC_LIMIT = 25_000_000 - 1; 

    reg            DEBUG_SGNL = 1'b0;

   always @(posedge CLK) begin
        DEBUG_SGNL <= ~DEBUG_SGNL;
	end

    ila_0 your_instance_name (
	.clk(CLK), // input wire clk


	.probe0(DEBUG_SGNL), // input wire [0:0]  probe0  
	.probe1(state), // input wire [3:0]  probe1 
	.probe2(next_state), // input wire [3:0]  probe2 
	.probe3(counter_reg), // input wire [26:0]  probe3 
	.probe4(data_arrived), // input wire [0:0]  probe4 
	.probe5(data_is_blank), // input wire [0:0]  probe5 
	.probe6(OUTPUT_BITS_ONION_p), // input wire [8:0]  probe6 
	.probe7(OUTPUT_BITS_ONION_n), // input wire [8:0]  probe7 
	.probe8(OUTPUT_BITS_ONION_A_AO), // input wire [0:0]  probe8 
	.probe9(LED) // input wire [26:0]  probe9
);

    
    //---------------------------------------------------------
    // Internal Signals
    //---------------------------------------------------------
    
    // FSM State Definitions
    typedef enum logic [3:0] {
        S_WAIT_DATA_BLANK,      // Faz 1: Veri hatlarının ve ACK'nin 0 olmasını bekle.
        S_DATA_LATCH,           // Faz 2: Veri geldi, veriyi/adresi yakala.
        S_TIMER_START,          // LED zamanlayıcısını başlat (Sayacı sıfırla).
        S_TIMER_WAIT,           // LED açıkken 1 saniye bekle (ON Time).
        S_LED_BLANK_WAIT,       // LED kapalıyken 1 saniye bekle (OFF Time).
        S_SEND_ACK,             // Faz 3: ACK'yi '1' yap.
        S_WAIT_DATA_BLANK_LOW,  // Faz 4: Göndericinin veri hatlarını '0' çekmesini bekle.
        S_ACK_LOW               // Faz 5: ACK'yi '0' yap ve S_WAIT_DATA_BLANK'e dön.
    } state_t;

    state_t state, next_state;

    logic [COUNTER_WIDTH-1:0] counter_reg;

    //---------------------------------------------------------
    // 1. Dual-Rail Veri Kontrolü
    //---------------------------------------------------------
    // 'data_arrived' sinyali: Data hatlarından herhangi biri '1' ise veri gelmiştir.
    logic data_arrived;
    assign data_arrived = |OUTPUT_BITS_ONION_p | |OUTPUT_BITS_ONION_n;

    // 'data_is_blank' sinyali: Tüm data hatları '0' ise hat boş/temizdir.
    logic data_is_blank;
    assign data_is_blank = ~data_arrived; 
    

    //---------------------------------------------------------
    // 2. Sequential Logic: Counter Register
    //---------------------------------------------------------
    always_ff @(posedge CLK)
    begin
        if (RST) begin
            counter_reg <= '0;
        end
        else begin
            // Counter Logic: Increments in S_TIMER_WAIT (LED ON time) 
            // OR S_LED_BLANK_WAIT (LED OFF time)
            if (state == S_TIMER_WAIT || state == S_LED_BLANK_WAIT) begin
                if (counter_reg == ONE_SEC_LIMIT)
                    counter_reg <= '0;
                else
                    counter_reg <= counter_reg + 1;
            end
            // Reset counter when a new timer sequence starts
            else if (state == S_TIMER_START)
                counter_reg <= '0;
            // Reset counter in other states if it's not already 0 (safety)
            else if (counter_reg != '0 && state != S_TIMER_WAIT && state != S_LED_BLANK_WAIT)
                 counter_reg <= '0; 
        end
    end

    //---------------------------------------------------------
    // 3. Sequential Logic: State Register
    //---------------------------------------------------------
    always_ff @(posedge CLK)
    begin
        if  (RST)  state <= S_WAIT_DATA_BLANK;
        else       state <= next_state;
    end

    //----------------------------------------------------------
    // 4. Combinational Logic: Next State Determination (FSM)
    //----------------------------------------------------------
    always_comb begin
        next_state = state;

        case (state)
            S_WAIT_DATA_BLANK:      // Faz 1: Hatların boş olmasını bekle
                if (data_arrived)   // Veri geldiğinde (Dual-rail sinyalleri 0'dan farklı)
                    next_state = S_DATA_LATCH;
            
            S_DATA_LATCH:           // Faz 2: Veri geldi, zamanlayıcıyı başlat
                next_state = S_TIMER_START;
            
            S_TIMER_START:          // LED ON süresini başlatmak için sayacı sıfırla
                next_state = S_TIMER_WAIT;
                                    
            S_TIMER_WAIT:           // LED açıkken 1 saniye bekle
                if (counter_reg == ONE_SEC_LIMIT)
                    next_state = S_LED_BLANK_WAIT; // LED'i söndürme süresine geç
                                    
            S_LED_BLANK_WAIT:       // LED kapalıyken 1 saniye bekle (Blink süresi)
                if (counter_reg == ONE_SEC_LIMIT)
                    next_state = S_SEND_ACK; // ACK gönderme döngüsüne geç

            S_SEND_ACK:             // Faz 3: ACK'yi '1' yap
                next_state = S_WAIT_DATA_BLANK_LOW;
                
            S_WAIT_DATA_BLANK_LOW:  // Faz 4: Göndericinin veri hatlarını '0' çekmesini bekle
                if (data_is_blank)  // Veri hatları boşaldı (tümü '0')
                    next_state = S_ACK_LOW;
            
            S_ACK_LOW:              // Faz 5: ACK'yi '0' yap
                next_state = S_WAIT_DATA_BLANK;
                                    
            default:                
                next_state = S_WAIT_DATA_BLANK;
        endcase
    end

    //-----------------------------------------------------------
    // 5. Combinational Logic: Output Generation
    //-----------------------------------------------------------
    always_comb begin
        // Default değerler
        OUTPUT_BITS_ONION_A_AO = 1'b0; 
        LED                    = 1'b0;

        case (state)
            // ACK YÜKSEK (Faz 3/4)
            S_SEND_ACK, S_WAIT_DATA_BLANK_LOW:
                OUTPUT_BITS_ONION_A_AO = 1'b1;
            
            // LED YÜKSEK (Sadece S_TIMER_WAIT durumunda)
            S_TIMER_WAIT:
                LED = 1'b1;
                
            default: ; 
        endcase
    end

endmodule