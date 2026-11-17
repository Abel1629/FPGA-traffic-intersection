`timescale 1ns / 1ps

module top (
    input  wire        clk,   // 100 MHz-es órajel (E3 láb)
    input  wire [15:0] SW,    // 16 darab csúszókapcsoló
    input  wire        BTNC,  // Középs? nyomógomb: Gyalogos kérés
    input  wire        BTND,  // Alsó nyomógomb: Teszt törlés (kés?bb az FSM végzi)
    output wire [15:0] LED    // 16 darab zöld LED
);

    wire rst       = SW[15]; // Bal széls? kapcsoló: Reset
    wire fast_mode = SW[2];  // SW2: Gyorsított teszt mód

    wire tick_1hz;
    reg  heartbeat_led;

    // 1. Órajelosztó modul
    clock_divider u_clk_div (
        .clk       (clk),
        .rst       (rst),
        .fast_mode (fast_mode),
        .tick_1hz  (tick_1hz)
    );

    always @(posedge clk) begin
        if (rst) begin
            heartbeat_led <= 1'b0;
        end else if (tick_1hz) begin
            heartbeat_led <= ~heartbeat_led;
        end
    end

    // 2. Nyomógombok pergésmentesítése
    wire ped_btn_pulse;
    wire clear_btn_pulse;

    button_debouncer u_deb_ped (
        .clk       (clk),
        .rst       (rst),
        .btn_in    (BTNC),
        .btn_pulse (ped_btn_pulse)
    );

    button_debouncer u_deb_clear (
        .clk       (clk),
        .rst       (rst),
        .btn_in    (BTND),
        .btn_pulse (clear_btn_pulse)
    );

    // 3. Gyalogos kérés tároló (Latch / Flip-Flop)
    // Megjegyzi a kérést akkor is, ha a gyalogos csak röviden nyomta meg a gombot
    reg ped_request_pending;

    always @(posedge clk) begin
        if (rst) begin
            ped_request_pending <= 1'b0;
        end else if (ped_btn_pulse) begin
            ped_request_pending <= 1'b1; // Kérés rögzítve!
        end else if (clear_btn_pulse) begin
            ped_request_pending <= 1'b0; // Kérés kiszolgálva / törölve
        end
    end

    // LED kimenetek:
    assign LED[0]    = (!fast_mode) ? heartbeat_led : 1'b0;
    assign LED[1]    = ( fast_mode) ? heartbeat_led : 1'b0;
    assign LED[2]    = ped_request_pending; // Világít, amíg a gyalogos kérés várakozik!
    assign LED[14:3] = 12'd0;
    assign LED[15]   = rst;

endmodule