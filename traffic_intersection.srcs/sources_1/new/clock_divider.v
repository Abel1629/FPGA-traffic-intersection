`timescale 1ns / 1ps

module clock_divider (
    input  wire clk,        // 100 MHz-es f? órajel
    input  wire rst,        // Szinkron reset (1 = alaphelyzet)
    input  wire fast_mode,  // 1 = 5x gyorsított teszt üzemmód, 0 = valós 1 másodperc
    output reg  tick_1hz    // 1 órajelciklusig tartó impulzus minden "másodpercben"
);

    // 100 000 000 ciklus = 1 másodperc (0-tól 99 999 999-ig számolunk)
    // A 100 000 000 tárolásához 27 bit szükséges (2^27 = 134 217 728)
    localparam integer MAX_COUNT_NORMAL = 100_000_000 - 1;
    localparam integer MAX_COUNT_FAST   =  20_000_000 - 1; // 0.2 másodperc (5x gyorsabb)

    reg [26:0] counter;
    wire [26:0] target_count;

    // Kiválasztjuk, meddig számoljon a számláló a mód kapcsoló alapján
    assign target_count = fast_mode ? MAX_COUNT_FAST : MAX_COUNT_NORMAL;

    always @(posedge clk) begin
        if (rst) begin
            counter  <= 27'd0;
            tick_1hz <= 1'b0;
        end else begin
            if (counter >= target_count) begin
                counter  <= 27'd0;
                tick_1hz <= 1'b1; // Most telt le a 1 másodperc!
            end else begin
                counter  <= counter + 27'd1;
                tick_1hz <= 1'b0;
            end
        end
    end

endmodule