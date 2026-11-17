`timescale 1ns / 1ps

module button_debouncer (
    input  wire clk,        // 100 MHz-es f? órajel
    input  wire rst,        // Szinkron reset
    input  wire btn_in,     // Nyers, perg? nyomógomb bemenet a kártyáról
    output reg  btn_pulse   // Tiszta, 1 órajelciklusos impulzus a gomb lenyomásakor
);

    // 20 ms pergésmentesítési id? 100 MHz-en = 2 000 000 órajelciklus
    // 2^21 = 2 097 152, így 21 bit elég a számlálónak
    localparam integer DEBOUNCE_LIMIT = 2_000_000 - 1;

    // 1. fokozat: 2-lépcs?s szinkronizáló lánc a metastabilitás ellen
    reg btn_sync_0;
    reg btn_sync_1;

    always @(posedge clk) begin
        if (rst) begin
            btn_sync_0 <= 1'b0;
            btn_sync_1 <= 1'b0;
        end else begin
            btn_sync_0 <= btn_in;
            btn_sync_1 <= btn_sync_0;
        end
    end

    // 2. fokozat: Pergésmentesít? számláló
    reg [20:0] debounce_cnt;
    reg        btn_stable;
    reg        btn_stable_prev;

    always @(posedge clk) begin
        if (rst) begin
            debounce_cnt    <= 21'd0;
            btn_stable      <= 1'b0;
            btn_stable_prev <= 1'b0;
            btn_pulse       <= 1'b0;
        end else begin
            // Elmentjük az el?z? órajelciklus stabil állapotát él-detektáláshoz
            btn_stable_prev <= btn_stable;

            if (btn_sync_1 == btn_stable) begin
                // A jel nem változott a stabil állapothoz képest, nullázzuk a számlálót
                debounce_cnt <= 21'd0;
            end else begin
                // A jel eltér, számoljuk, meddig marad így folyamatosan
                if (debounce_cnt >= DEBOUNCE_LIMIT) begin
                    btn_stable   <= btn_sync_1; // Elfogadjuk az új stabil állapotot!
                    debounce_cnt <= 21'd0;
                end else begin
                    debounce_cnt <= debounce_cnt + 21'd1;
                end
            end

            // Felfutó él detektálása: akkor adunk 1 ciklusos impulzust,
            // amikor a stabil jel most váltott 0-ról 1-re (lenyomás pillanata)
            btn_pulse <= (btn_stable == 1'b1) && (btn_stable_prev == 1'b0);
        end
    end

endmodule