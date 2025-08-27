`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: University of Groningen 
// Engineer: H. Basri Bilge
// 
// Create Date: 27/08/2025 04:22:30 PM
// Module Name: synaptic_core
// Target Devices: Kr260 - Olla
// 
// Revision: r0.1
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module synaptic_core #(
    parameter N = 256,
    parameter M = 8
)(
    
    // Global inputs ------------------------------------------
    input  wire           CLK,
    
    // Inputs from controller ---------------------------------
    input  wire           CTRL_SYNARRAY_WE,
    input  wire [    8:0] CTRL_SYNARRAY_ADDR,
    input  wire           CTRL_SYNARRAY_CS,
    input  wire [2*M-1:0] CTRL_PROG_DATA, // Unused for now
    input  wire [2*M-1:0] CTRL_SPI_ADDR,  // Unused for now
    
    // Outputs ------------------------------------------------
    output wire [   24:0] SYNARRAY_RDATA
);
    // Write data register for SPI communication
    reg [24:0] w_data;

    // Memory registers
    reg [24:0] BRAM_Lut[511:0];
    reg [24:0] Qr;

    assign SYNARRAY_RDATA = Qr;

    //***********************************
    //
    // (SPI Write function) *Coming soon*
    //
    //***********************************

    initial begin
        $readmemh("/home/s6425496/tinyODIN_r01/src/bram_lut_data.mem", BRAM_Lut);
    end


    // Read/Write block for BRAM_LUT
    always @(posedge CLK ) begin
        if (CTRL_SYNARRAY_CS) begin
            Qr <= BRAM_Lut[CTRL_SYNARRAY_ADDR];
            if (CTRL_SYNARRAY_WE) begin
                BRAM_Lut[CTRL_SYNARRAY_ADDR] <= w_data;
            end
        end
    end
    
    
endmodule

