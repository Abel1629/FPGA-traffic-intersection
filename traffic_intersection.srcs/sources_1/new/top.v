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
    output wire        AUD_SD,  // Audio er?sít? engedélyezés
    output wire [3:0]  VGA_R,   // VGA Piros (4 bit)
    output wire [3:0]  VGA_G,   // VGA Zöld (4 bit)
    output wire [3:0]  VGA_B,   // VGA Kék (4 bit)
    output wire        VGA_HS,  // VGA vízszintes szinkron
    output wire        VGA_VS   // VGA függ?leges szinkron
);

    // Kezel?szervek kiosztása
    wire rst       = SW[15]; // Bal széls? kapcsoló: Reset
    wire sound_en  = SW[1];  // SW[1]: Hangjelzés engedélyezése (1 = be, 0 = néma)
    wire fast_mode = SW[3];  // SW[3]: 5x gyorsított teszt üzemmód

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
            ped_request_pending <= 1'b0;
        end else if (ped_btn_pulse) begin
            ped_request_pending <= 1'b1;
        end
    end

    // 4. Közlekedési lámpa állapotgép (1. mód)
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

    // 5. 7-szegmenses kijelz? meghajtó
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

    // 7. VGA Szinkronizáló és Rajzoló (640x480 @ 60 Hz)
    wire       vga_video_on;
    wire [9:0] vga_pixel_x;
    wire [9:0] vga_pixel_y;

    vga_sync u_vga_sync (
        .clk      (clk),
        .rst      (rst),
        .hsync    (VGA_HS),
        .vsync    (VGA_VS),
        .video_on (vga_video_on),
        .pixel_x  (vga_pixel_x),
        .pixel_y  (vga_pixel_y)
    );

    vga_renderer_mode1 u_vga_render1 (
        .video_on    (vga_video_on),
        .pixel_x     (vga_pixel_x),
        .pixel_y     (vga_pixel_y),
        .car_light   (car_light),
        .ped_light   (ped_light),
        .display_sec (display_sec),
        .ped_req     (ped_request_pending),
        .vga_r       (VGA_R),
        .vga_g       (VGA_G),
        .vga_b       (VGA_B)
    );

    // LED-ek kiosztása
    assign LED[0]     = heartbeat_led;
    assign LED[1]     = ped_request_pending;
    assign LED[2]     = 1'b0;
    assign LED[4:3]   = ped_light;
    assign LED[5]     = 1'b0;
    assign LED[8:6]   = car_light;
    assign LED[14:9]  = 6'd0;
    assign LED[15]    = rst;

endmodule