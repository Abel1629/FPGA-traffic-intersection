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
    wire mode_sel   = SW[0];  // SW[0]: 0 = 1. mód (egyszer?), 1 = 2. mód (komplex keresztez?dés)
    wire sound_en   = SW[1];  // SW[1]: Hangjelzés engedélyezése (1 = be, 0 = néma)
    wire fast_mode  = SW[3];  // SW[3]: 5x gyorsított teszt üzemmód
    wire night_mode = SW[4];  // SW[4]: Éjszakai mód
    wire rst        = SW[15]; // SW[15]: Reset

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

    // 3. Gyalogos kérés tároló (1. módhoz)
    reg  ped_request_pending;
    wire clear_ped_req;

    always @(posedge clk) begin
        if (rst) begin
            ped_request_pending <= 1'b0;
        end else if (clear_ped_req) begin
            ped_request_pending <= 1'b0;
        end else if (ped_btn_pulse && !mode_sel) begin
            ped_request_pending <= 1'b1;
        end
    end

    // 4/A. Közlekedési lámpa állapotgép (1. mód)
    wire [2:0] m1_car_light;
    wire [1:0] m1_ped_light;
    wire [5:0] m1_display_sec;
    wire       m1_is_ped_green;
    wire [2:0] m1_fsm_state;

    traffic_fsm_mode1 u_fsm_mode1 (
        .clk           (clk),
        .rst           (rst || mode_sel),
        .tick_1hz      (tick_1hz),
        .night_mode    (night_mode),
        .ped_req       (ped_request_pending),
        .clear_ped_req (clear_ped_req),
        .car_light     (m1_car_light),
        .ped_light     (m1_ped_light),
        .display_sec   (m1_display_sec),
        .is_ped_green  (m1_is_ped_green),
        .current_state (m1_fsm_state)
    );

    // 4/B. Közlekedési lámpa állapotgép (2. mód: komplex keresztez?dés)
    wire [2:0] m2_main_outer;
    wire       m2_main_yield;
    wire [2:0] m2_main_inner;
    wire [2:0] m2_west_light;
    wire       m2_west_yield;
    wire       m2_west_rgrn;
    wire [2:0] m2_east_light;
    wire       m2_east_yield;
    wire       m2_east_rgrn;
    wire [1:0] m2_ped_west;
    wire [1:0] m2_ped_east;
    wire [1:0] m2_ped_south;
    wire [1:0] m2_ped_north;
    wire [5:0] m2_display_sec;
    wire [2:0] m2_phase_num;

    traffic_fsm_mode2 u_fsm_mode2 (
        .clk              (clk),
        .rst              (rst || !mode_sel),
        .tick_1hz         (tick_1hz),
        .main_outer_light (m2_main_outer),
        .main_yield_yel   (m2_main_yield),
        .main_inner_light (m2_main_inner),
        .west_light       (m2_west_light),
        .west_yield_yel   (m2_west_yield),
        .west_right_grn   (m2_west_rgrn),
        .east_light       (m2_east_light),
        .east_yield_yel   (m2_east_yield),
        .east_right_grn   (m2_east_rgrn),
        .ped_west_light   (m2_ped_west),
        .ped_east_light   (m2_ped_east),
        .ped_south_light  (m2_ped_south),
        .ped_north_light  (m2_ped_north),
        .display_sec      (m2_display_sec),
        .phase_num        (m2_phase_num)
    );

    // 5. 7-szegmenses kijelz? meghajtó (mindkét módban mutatja az aktuális visszaszámlálót)
    wire [5:0] active_display_sec = mode_sel ? m2_display_sec : m1_display_sec;

    seven_seg_driver u_7seg (
        .clk    (clk),
        .rst    (rst),
        .number (active_display_sec),
        .seg    (SEG),
        .dp     (DP),
        .an     (AN)
    );

    // 6. Csipogó hangjelzés meghajtó (1. módban aktív)
    audio_beeper u_beeper (
        .clk          (clk),
        .rst          (rst),
        .enable_sound (sound_en && !mode_sel),
        .ped_green    (m1_is_ped_green),
        .aud_pwm      (AUD_PWM),
        .aud_sd       (AUD_SD)
    );

    // 7. VGA Szinkronizáló és mindkét mód rajzolója
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

    wire [3:0] r_m1, g_m1, b_m1;
    vga_renderer_mode1 u_vga_render1 (
        .video_on    (vga_video_on),
        .pixel_x     (vga_pixel_x),
        .pixel_y     (vga_pixel_y),
        .night_mode  (night_mode),
        .car_light   (m1_car_light),
        .ped_light   (m1_ped_light),
        .display_sec (m1_display_sec),
        .ped_req     (ped_request_pending),
        .vga_r       (r_m1),
        .vga_g       (g_m1),
        .vga_b       (b_m1)
    );

    wire [3:0] r_m2, g_m2, b_m2;
    vga_renderer_mode2 u_vga_render2 (
        .video_on         (vga_video_on),
        .pixel_x          (vga_pixel_x),
        .pixel_y          (vga_pixel_y),
        .main_outer_light (m2_main_outer),
        .main_yield_yel   (m2_main_yield),
        .main_inner_light (m2_main_inner),
        .west_light       (m2_west_light),
        .west_yield_yel   (m2_west_yield),
        .west_right_grn   (m2_west_rgrn),
        .east_light       (m2_east_light),
        .east_yield_yel   (m2_east_yield),
        .east_right_grn   (m2_east_rgrn),
        .ped_west_light   (m2_ped_west),
        .ped_east_light   (m2_ped_east),
        .ped_south_light  (m2_ped_south),
        .ped_north_light  (m2_ped_north),
        .display_sec      (m2_display_sec),
        .phase_num        (m2_phase_num),
        .vga_r            (r_m2),
        .vga_g            (g_m2),
        .vga_b            (b_m2)
    );

    // Képválasztó multiplexer az SW[0] kapcsoló alapján
    assign VGA_R = mode_sel ? r_m2 : r_m1;
    assign VGA_G = mode_sel ? g_m2 : g_m1;
    assign VGA_B = mode_sel ? b_m2 : b_m1;

    // LED-ek kiosztása
    assign LED[0]     = heartbeat_led;
    assign LED[1]     = ped_request_pending;
    assign LED[2]     = night_mode;
    assign LED[4:3]   = m1_ped_light;
    assign LED[5]     = mode_sel;
    assign LED[8:6]   = mode_sel ? m2_main_outer : m1_car_light;
    assign LED[11:9]  = mode_sel ? m2_main_inner : 3'd0;
    assign LED[14:12] = mode_sel ? m2_phase_num  : 3'd0;
    assign LED[15]    = rst;

endmodule