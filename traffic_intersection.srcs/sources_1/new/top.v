`timescale 1ns / 1ps

module top (
    input  wire        clk,     // 100 MHz-es órajel (E3 láb)
    input  wire [15:0] SW,      // 16 darab csúszókapcsoló
    input  wire        BTNC,    // Középs? gomb: Gyalogos kérés
    output wire [15:0] LED,     // 16 darab zöld LED
    output wire [6:0]  SEG,     // 7-szegmenses kijelz? szegmensei
    output wire        DP,      // 7-szegmenses tizedespont
    output wire [7:0]  AN,      // 7-szegmenses digit kiválasztók
    output wire        AUD_PWM, // Audio kimenet
    output wire        AUD_SD   // Audio er?sít? engedélyezés
);

    // Kezel?szervek kiosztása (kerülve a kontakthibás SW[2]-t: SW[3] lesz a gyors mód!)
    wire rst        = SW[15]; // Bal széls? kapcsoló: Reset
    wire sound_en   = SW[1];  // SW[1]: Hangjelzés engedélyezése (1 = be, 0 = néma)
    wire fast_mode  = SW[3];  // SW[3]: 5x gyorsított teszt üzemmód

    // 1. Órajelosztó (1 Hz)
    wire tick_1hz;
    reg  heartbeat_led;

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

    // 2. Gyalogos nyomógomb pergésmentesítése
    wire ped_btn_pulse;

    button_debouncer u_deb_ped (
        .clk       (clk),
        .rst       (rst),
        .btn_in    (BTNC),
        .btn_pulse (ped_btn_pulse)
    );

    // 3. Gyalogos kérés tároló
    reg  ped_request_pending;
    wire clear_ped_req;

    always @(posedge clk) begin
        if (rst) begin
            ped_request_pending <= 1'b0;
        end else if (clear_ped_req) begin
            ped_request_pending <= 1'b0; // Az állapotgép törli, amikor elindul a váltás
        end else if (ped_btn_pulse) begin
            ped_request_pending <= 1'b1; // A gyalogos megnyomta a gombot
        end
    end

    // 4. Közlekedési lámpa állapotgép (1. mód: egyszer? út + zebra)
    wire [2:0] car_light;      // [2]=Piros, [1]=Sárga, [0]=Zöld
    wire [1:0] ped_light;      // [1]=Piros, [0]=Zöld
    wire [5:0] display_sec;
    wire       is_ped_green;
    wire [2:0] fsm_state;

    traffic_fsm_mode1 u_fsm_mode1 (
        .clk           (clk),
        .rst           (rst),
        .tick_1hz      (tick_1hz),
        .ped_req       (ped_request_pending),
        .clear_ped_req (clear_ped_req),
        .car_light     (car_light),
        .ped_light     (ped_light),
        .display_sec   (display_sec),
        .is_ped_green  (is_ped_green),
        .current_state (fsm_state)
    );

    // 5. 7-szegmenses kijelz? meghajtó (visszaszámláló)
    seven_seg_driver u_7seg (
        .clk    (clk),
        .rst    (rst),
        .number (display_sec),
        .seg    (SEG),
        .dp     (DP),
        .an     (AN)
    );

    // 6. Csipogó hangjelzés meghajtó
    audio_beeper u_beeper (
        .clk          (clk),
        .rst          (rst),
        .enable_sound (sound_en),
        .ped_green    (is_ped_green),
        .aud_pwm      (AUD_PWM),
        .aud_sd       (AUD_SD)
    );

    // LED-ek logikus elrendezése a kártyán:
    assign LED[0]     = heartbeat_led;       // 1 Hz életjel
    assign LED[1]     = ped_request_pending; // Világít, amíg a gyalogos kérés várakozik
    assign LED[2]     = 1'b0;                // Tartalék
    // Gyalogos lámpa (LED[4] = Piros, LED[3] = Zöld)
    assign LED[4:3]   = ped_light;
    assign LED[5]     = 1'b0;                // Elválasztó üres LED
    // Autós lámpa (LED[8] = Piros, LED[7] = Sárga, LED[6] = Zöld)
    assign LED[8:6]   = car_light;
    assign LED[14:9]  = 6'd0;
    assign LED[15]    = rst;                 // Reset jelz?

endmodule