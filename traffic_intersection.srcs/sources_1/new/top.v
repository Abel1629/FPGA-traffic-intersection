`timescale 1ns / 1ps

module top (
    input  wire        clk,     // 100 MHz-es orajel (E3 lab)
    input  wire [15:0] SW,      // 16 darab csuszokapcsolo
    input  wire        BTNC,    // Kozepso gomb: Gyalogos keres
    output wire [15:0] LED,     // 16 darab zold LED
    output wire [6:0]  SEG,     // 7-szegmenses kijelzo szegmensei
    output wire        DP,      // 7-szegmenses tizedespont
    output wire [7:0]  AN,      // 7-szegmenses digit kivalasztok
    output wire        AUD_PWM, // Audio kimenet
    output wire        AUD_SD,  // Audio erosito engedelyezes
    output reg  [3:0]  VGA_R,   // Regiszterezett VGA Piros (4 bit)
    output reg  [3:0]  VGA_G,   // Regiszterezett VGA Zold (4 bit)
    output reg  [3:0]  VGA_B,   // Regiszterezett VGA Kek (4 bit)
    output reg         VGA_HS,  // Regiszterezett VGA vizszintes szinkron
    output reg         VGA_VS   // Regiszterezett VGA fuggoleges szinkron
);

    // Kezeloszervek kiosztasa
    wire mode_sel   = SW[0];  // SW[0]: 0 = 1. mod (egyszeru), 1 = 2. mod (komplex keresztezodes)
    wire sound_en   = SW[1];  // SW[1]: Hangjelzes engedelyezese (1 = be, 0 = nema)
    wire fast_mode  = SW[3];  // SW[3]: 5x gyorsitott teszt uzemmod
    wire night_mode = SW[4];  // SW[4]: Ejszakai mod (1. modban)
    wire rst        = SW[15]; // SW[15]: Reset

    // 1. Orajeloszto (1 Hz)
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

    // 2. Gyalogos nyomogomb pergesmentesitese
    wire ped_btn_pulse;

    button_debouncer u_deb_ped (
        .clk       (clk),
        .rst       (rst),
        .btn_in    (BTNC),
        .btn_pulse (ped_btn_pulse)
    );

    // 3. Gyalogos keres tarolo (1. modhoz)
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

    // 4/A. Kozlekedesi lampa allapotgep (1. mod)
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

    // 4/B. Kozlekedesi lampa allapotgep (2. mod: komplex keresztezodes)
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

    // 5. 7-szegmenses kijelzo meghajto
    wire [5:0] active_display_sec = mode_sel ? m2_display_sec : m1_display_sec;

    seven_seg_driver u_7seg (
        .clk    (clk),
        .rst    (rst),
        .number (active_display_sec),
        .seg    (SEG),
        .dp     (DP),
        .an     (AN)
    );

    // 6. Csipogo hangjelzes meghajto (1. modban aktiv)
    audio_beeper u_beeper (
        .clk          (clk),
        .rst          (rst),
        .enable_sound (sound_en && !mode_sel),
        .ped_green    (m1_is_ped_green),
        .aud_pwm      (AUD_PWM),
        .aud_sd       (AUD_SD)
    );

    // 7. VGA Szinkronizalo + 60 Hz kepkocka utemjel
    wire       vga_video_on;
    wire [9:0] vga_pixel_x;
    wire [9:0] vga_pixel_y;
    wire       hsync_raw;
    wire       vsync_raw;

    vga_sync u_vga_sync (
        .clk      (clk),
        .rst      (rst),
        .hsync    (hsync_raw),
        .vsync    (vsync_raw),
        .video_on (vga_video_on),
        .pixel_x  (vga_pixel_x),
        .pixel_y  (vga_pixel_y)
    );

    // 1 orajelciklusos impulzus minden kepkocka vegen (60 Hz)
    reg vsync_prev;
    always @(posedge clk) begin
        if (rst)
            vsync_prev <= 1'b1;
        else
            vsync_prev <= vsync_raw;
    end
    wire frame_tick = (vsync_prev == 1'b1) && (vsync_raw == 1'b0);

    // 8. Forgalmi szimulator (1. mod: 3 auto + 4 gyalogos)
    wire signed [10:0] sim_car0_y, sim_car1_y, sim_car2_y;
    wire signed [10:0] sim_ped0_x, sim_ped1_x, sim_ped2_x, sim_ped3_x;

    traffic_sim_mode1 u_sim_mode1 (
        .clk         (clk),
        .rst         (rst || mode_sel),
        .frame_tick  (frame_tick),
        .fast_mode   (fast_mode),
        .car_light   (m1_car_light),
        .fsm_state   (m1_fsm_state),
        .display_sec (m1_display_sec),
        .car0_y      (sim_car0_y),
        .car1_y      (sim_car1_y),
        .car2_y      (sim_car2_y),
        .ped0_x      (sim_ped0_x),
        .ped1_x      (sim_ped1_x),
        .ped2_x      (sim_ped2_x),
        .ped3_x      (sim_ped3_x)
    );

    // 9. VGA Rajzolok (1. es 2. mod)
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
        .car0_y      (sim_car0_y),
        .car1_y      (sim_car1_y),
        .car2_y      (sim_car2_y),
        .ped0_x      (sim_ped0_x),
        .ped1_x      (sim_ped1_x),
        .ped2_x      (sim_ped2_x),
        .ped3_x      (sim_ped3_x),
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

    // 10. VGA kimenetek szinkron regiszterezese (glitch-mentes kephez)
    always @(posedge clk) begin
        if (rst) begin
            VGA_R  <= 4'd0;
            VGA_G  <= 4'd0;
            VGA_B  <= 4'd0;
            VGA_HS <= 1'b1;
            VGA_VS <= 1'b1;
        end else begin
            VGA_R  <= mode_sel ? r_m2 : r_m1;
            VGA_G  <= mode_sel ? g_m2 : g_m1;
            VGA_B  <= mode_sel ? b_m2 : b_m1;
            VGA_HS <= hsync_raw;
            VGA_VS <= vsync_raw;
        end
    end

    // LED-ek kiosztasa
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