`timescale 1ns / 1ps

module play_music(
    input clk_27m,           // 27MHz时钟
    output reg [3:0] col,    // 矩阵键盘列输出
    input [3:0] row,         // 矩阵键盘行输入
    output beep,             // 蜂鸣器输出
    input light_do, 
    input play_pause,        // 播放/暂停控制 (1:播放, 0:暂停)
    output reg [1:0] music_select_out,  // 输出当前选择的歌曲
    output reg [2:0] volume_out         // 输出当前音量 (0-5)
);

    // ========== 音乐选择信号 ==========
    reg [1:0] music_select;
    
    // ========== 键盘扫描相关寄存器 ==========
    reg [1:0] scan_cnt;
    reg [19:0] delay_cnt;
    reg [3:0] row_reg;
    reg [3:0] raw_key;
    reg key_detected, key_detected_last;
    reg [25:0] note_duration;
    
    // ========== 晴天播放相关寄存器 ==========
    reg beep_r_qingtian;
    reg [7:0] state_qingtian;
    reg [16:0] count_qingtian, count1_qingtian;
    reg [25:0] count2_qingtian;
    reg [25:0] note_duration_qingtian;
    reg pause_qingtian;
   
    // ========== 小星星播放相关寄存器 ==========
    reg beep_r_littlestar;
    reg [7:0] state_littlestar;
    reg [16:0] count_littlestar, count1_littlestar;
    reg [25:0] count2_littlestar;
    reg pause_littlestar;
    
    // ========== 两只老虎播放相关寄存器 ==========
    reg beep_r_twotigers;
    reg [7:0] state_twotigers;
    reg [16:0] count_twotigers, count1_twotigers;
    reg [25:0] count2_twotigers;
    reg [25:0] note_duration_twotigers;
    reg pause_twotigers;
    
    // ========== 铃儿响叮当播放相关寄存器 ==========
    reg beep_r_jingle;
    reg [7:0] state_jingle;
    reg [16:0] count_jingle, count1_jingle;
    reg [25:0] count2_jingle;
    reg [25:0] note_duration_jingle;
    reg pause_jingle;
    
    // ========== 音量控制寄存器 ==========
    reg [2:0] volume_reg;        // 当前音量 0-5
    reg [7:0] pwm_cnt;           // PWM计数器 0-1023
    reg [7:0] pwm_threshold;     // PWM阈值
    wire beep_raw;                // 原始方波
    reg beep_pwm;                // PWM调制后输出
    
    // ========== 音符频率参数 ==========
    parameter L_1 = 18'd127552, L_2 = 18'd113636, L_3 = 18'd101236,
              L_4 = 18'd95548,  L_5 = 18'd85136,  L_6 = 18'd75838, L_7 = 18'd67567,
              M_1 = 18'd63776, M_2 = 18'd56818, M_3 = 18'd50607,
              M_4 = 18'd47778, M_5 = 18'd42553, M_6 = 18'd37936, M_7 = 18'd33783,
              H_1 = 18'd31888, H_2 = 18'd28409, H_3 = 18'd25303,
              REST = 18'd0;
    
    parameter TIME_NOTE = 26'd8_100_000;      // 音符时长
    parameter TIME_REST = 26'd2_700_000;      // 音符间停顿
    parameter TIME_REST_LONG = 26'd8_100_000; // 句子间长停顿

    // ========== 原始方波选择 ==========
    assign beep_raw = (music_select == 2'b00) ? beep_r_jingle :
                      (music_select == 2'b01) ? beep_r_qingtian : 
                      (music_select == 2'b10) ? beep_r_littlestar :
                      (music_select == 2'b11) ? beep_r_twotigers : 1'b0;
    
    // ========== PWM调制输出 ==========
    assign beep = beep_pwm;
    
    // 将 music_select 和 volume 输出到屏幕模块
    always @(*) begin
        music_select_out = music_select;
        volume_out = volume_reg;
    end
    
    // ========== 晴天播放模块 ==========
    // 产生音符频率的方波
    always @(posedge clk_27m) begin
        if(music_select == 2'b01 && !pause_qingtian) begin 
            count_qingtian <= count_qingtian + 1'b1;
            if (count_qingtian == count1_qingtian) begin
                count_qingtian <= 17'h0;
                beep_r_qingtian <= ~beep_r_qingtian;
            end
        end
        else begin
            count_qingtian <= 1'b0;
            beep_r_qingtian <= 1'b0;
        end
    end
    
    // 晴天乐谱状态机
    always @(posedge clk_27m) begin
        if(music_select == 2'b01) begin
            if(play_pause == 1'b0) begin
                pause_qingtian <= 1'b1;
            end else begin
                pause_qingtian <= 1'b0;
            end
            
            if(!pause_qingtian) begin
                if (count2_qingtian < note_duration_qingtian)
                    count2_qingtian <= count2_qingtian + 1'b1;
                else begin
                    count2_qingtian <= 26'd0;
                    if (state_qingtian == 8'd65)
                        state_qingtian <= 8'd0;
                    else
                        state_qingtian <= state_qingtian + 1'b1;
                    
                    case(state_qingtian)
                        8'd0:  begin count1_qingtian = L_6; note_duration_qingtian = TIME_NOTE; end
                        8'd2:  begin count1_qingtian = M_1; note_duration_qingtian = TIME_NOTE; end
                        8'd4:  begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd6:  begin count1_qingtian = M_1; note_duration_qingtian = TIME_NOTE; end
                        8'd8:  begin count1_qingtian = L_4; note_duration_qingtian = TIME_NOTE; end
                        8'd10: begin count1_qingtian = L_5; note_duration_qingtian = TIME_NOTE; end
                        8'd12: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd14: begin count1_qingtian = M_1; note_duration_qingtian = TIME_NOTE; end
                        8'd16: begin count1_qingtian = L_1; note_duration_qingtian = TIME_NOTE; end
                        8'd18: begin count1_qingtian = L_5; note_duration_qingtian = TIME_NOTE; end
                        8'd20: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd22: begin count1_qingtian = M_1; note_duration_qingtian = TIME_NOTE; end
                        8'd24: begin count1_qingtian = L_1; note_duration_qingtian = TIME_NOTE; end
                        8'd26: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd28: begin count1_qingtian = L_1; note_duration_qingtian = TIME_NOTE; end
                        8'd30: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd32: begin count1_qingtian = L_6; note_duration_qingtian = TIME_NOTE; end
                        8'd34: begin count1_qingtian = M_1; note_duration_qingtian = TIME_NOTE; end
                        8'd36: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd38: begin count1_qingtian = L_6; note_duration_qingtian = TIME_NOTE; end
                        8'd40: begin count1_qingtian = L_4; note_duration_qingtian = TIME_NOTE; end
                        8'd42: begin count1_qingtian = L_5; note_duration_qingtian = TIME_NOTE; end
                        8'd44: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd46: begin count1_qingtian = M_1; note_duration_qingtian = TIME_NOTE; end
                        8'd48: begin count1_qingtian = L_1; note_duration_qingtian = TIME_NOTE; end
                        8'd50: begin count1_qingtian = L_5; note_duration_qingtian = TIME_NOTE; end
                        8'd52: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd54: begin count1_qingtian = M_1; note_duration_qingtian = TIME_NOTE; end
                        8'd56: begin count1_qingtian = L_1; note_duration_qingtian = TIME_NOTE; end
                        8'd58: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        8'd60: begin count1_qingtian = L_7; note_duration_qingtian = TIME_NOTE; end
                        8'd62: begin count1_qingtian = M_1; note_duration_qingtian = TIME_NOTE; end
                        8'd64: begin count1_qingtian = M_5; note_duration_qingtian = TIME_NOTE; end
                        
                        8'd1, 8'd3, 8'd5, 8'd7, 8'd9, 8'd11, 8'd13, 8'd15,
                        8'd17, 8'd19, 8'd21, 8'd23, 8'd25, 8'd27, 8'd29, 8'd31,
                        8'd33, 8'd35, 8'd37, 8'd39, 8'd41, 8'd43, 8'd45, 8'd47,
                        8'd49, 8'd51, 8'd53, 8'd55, 8'd57, 8'd59, 8'd61, 8'd63,
                        8'd65: begin count1_qingtian = REST; note_duration_qingtian = TIME_REST; end
                        
                        default: begin count1_qingtian = 16'h0; note_duration_qingtian = TIME_NOTE; end
                    endcase
                end
            end
        end
        else begin
            count2_qingtian <= 1'b0;
            state_qingtian <= 8'd0;
            note_duration_qingtian <= TIME_NOTE;
            pause_qingtian <= 1'b0;
        end
    end
    
    // ========== 小星星播放模块 ==========
    always @(posedge clk_27m) begin
        if(music_select == 2'b10 && !pause_littlestar) begin 
            count_littlestar <= count_littlestar + 1'b1;
            if (count_littlestar == count1_littlestar) begin
                count_littlestar <= 17'h0;
                beep_r_littlestar <= ~beep_r_littlestar;
            end
        end
        else begin
            count_littlestar <= 1'b0;
            beep_r_littlestar <= 1'b0;
        end
    end
    
    // 小星星乐谱状态机
    always @(posedge clk_27m) begin
        if(music_select == 2'b10) begin
            if(play_pause == 1'b0) begin
                pause_littlestar <= 1'b1;
            end else begin
                pause_littlestar <= 1'b0;
            end
            
            if(!pause_littlestar) begin
                if (count2_littlestar < note_duration)
                    count2_littlestar <= count2_littlestar + 1'b1;
                else begin
                    count2_littlestar <= 26'd0;
                    if (state_littlestar == 8'd63)
                        state_littlestar <= 8'd0;
                    else
                        state_littlestar <= state_littlestar + 1'b1;
                    
                    case(state_littlestar)
                        8'd0:  begin count1_littlestar = M_1; note_duration = TIME_NOTE; end
                        8'd1:  begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd2:  begin count1_littlestar = M_1; note_duration = TIME_NOTE; end
                        8'd3:  begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd4:  begin count1_littlestar = M_5; note_duration = TIME_NOTE; end
                        8'd5:  begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd6:  begin count1_littlestar = M_5; note_duration = TIME_NOTE; end
                        8'd7:  begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd8:  begin count1_littlestar = M_6; note_duration = TIME_NOTE; end
                        8'd9:  begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd10: begin count1_littlestar = M_6; note_duration = TIME_NOTE; end
                        8'd11: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd12: begin count1_littlestar = M_5; note_duration = TIME_NOTE; end
                        8'd13: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd14: begin count1_littlestar = REST; note_duration = TIME_REST_LONG; end
                        8'd15: begin count1_littlestar = REST; note_duration = TIME_REST_LONG; end
                        
                        8'd16: begin count1_littlestar = M_4; note_duration = TIME_NOTE; end
                        8'd17: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd18: begin count1_littlestar = M_4; note_duration = TIME_NOTE; end
                        8'd19: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd20: begin count1_littlestar = M_3; note_duration = TIME_NOTE; end
                        8'd21: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd22: begin count1_littlestar = M_3; note_duration = TIME_NOTE; end
                        8'd23: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd24: begin count1_littlestar = M_2; note_duration = TIME_NOTE; end
                        8'd25: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd26: begin count1_littlestar = M_2; note_duration = TIME_NOTE; end
                        8'd27: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd28: begin count1_littlestar = M_1; note_duration = TIME_NOTE; end
                        8'd29: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd30: begin count1_littlestar = REST; note_duration = TIME_REST_LONG; end
                        8'd31: begin count1_littlestar = REST; note_duration = TIME_REST_LONG; end
                        
                        8'd32: begin count1_littlestar = M_5; note_duration = TIME_NOTE; end
                        8'd33: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd34: begin count1_littlestar = M_5; note_duration = TIME_NOTE; end
                        8'd35: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd36: begin count1_littlestar = M_4; note_duration = TIME_NOTE; end
                        8'd37: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd38: begin count1_littlestar = M_4; note_duration = TIME_NOTE; end
                        8'd39: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd40: begin count1_littlestar = M_3; note_duration = TIME_NOTE; end
                        8'd41: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd42: begin count1_littlestar = M_3; note_duration = TIME_NOTE; end
                        8'd43: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd44: begin count1_littlestar = M_2; note_duration = TIME_NOTE; end
                        8'd45: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd46: begin count1_littlestar = REST; note_duration = TIME_REST_LONG; end
                        8'd47: begin count1_littlestar = REST; note_duration = TIME_REST_LONG; end

                        8'd48: begin count1_littlestar = M_5; note_duration = TIME_NOTE; end
                        8'd49: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd50: begin count1_littlestar = M_5; note_duration = TIME_NOTE; end
                        8'd51: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd52: begin count1_littlestar = M_4; note_duration = TIME_NOTE; end
                        8'd53: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd54: begin count1_littlestar = M_4; note_duration = TIME_NOTE; end
                        8'd55: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd56: begin count1_littlestar = M_3; note_duration = TIME_NOTE; end
                        8'd57: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd58: begin count1_littlestar = M_3; note_duration = TIME_NOTE; end
                        8'd59: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd60: begin count1_littlestar = M_2; note_duration = TIME_NOTE; end
                        8'd61: begin count1_littlestar = REST; note_duration = TIME_REST; end
                        8'd62: begin count1_littlestar = REST; note_duration = TIME_REST_LONG; end
                        8'd63: begin count1_littlestar = REST; note_duration = TIME_REST_LONG; end
                        
                        default: begin count1_littlestar = 16'h0; note_duration = TIME_NOTE; end
                    endcase
                end
            end
        end
        else begin
            count2_littlestar <= 1'b0;
            state_littlestar <= 8'd0;
            note_duration <= TIME_NOTE;
            pause_littlestar <= 1'b0;
        end
    end
    
    // ========== 两只老虎播放模块 ==========
    always @(posedge clk_27m) begin
        if(music_select == 2'b11 && !pause_twotigers) begin 
            count_twotigers <= count_twotigers + 1'b1;
            if (count_twotigers == count1_twotigers) begin
                count_twotigers <= 17'h0;
                beep_r_twotigers <= ~beep_r_twotigers;
            end
        end
        else begin
            count_twotigers <= 1'b0;
            beep_r_twotigers <= 1'b0;
        end
    end
    
    // 两只老虎乐谱状态机
    always @(posedge clk_27m) begin
        if(music_select == 2'b11) begin
            if(play_pause == 1'b0) begin
                pause_twotigers <= 1'b1;
            end else begin
                pause_twotigers <= 1'b0;
            end
            
            if(!pause_twotigers) begin
                if (count2_twotigers < note_duration_twotigers)
                    count2_twotigers <= count2_twotigers + 1'b1;
                else begin
                    count2_twotigers <= 26'd0;
                    if (state_twotigers == 8'd78)
                        state_twotigers <= 8'd0;
                    else
                        state_twotigers <= state_twotigers + 1'b1;
                    
                    case(state_twotigers)
                        8'd0:  begin count1_twotigers = M_1; note_duration_twotigers = TIME_NOTE; end
                        8'd2:  begin count1_twotigers = M_2; note_duration_twotigers = TIME_NOTE; end
                        8'd4:  begin count1_twotigers = M_3; note_duration_twotigers = TIME_NOTE; end
                        8'd6:  begin count1_twotigers = M_1; note_duration_twotigers = TIME_NOTE; end
                        8'd8:  begin count1_twotigers = REST; note_duration_twotigers = TIME_REST_LONG; end
                        
                        8'd10: begin count1_twotigers = M_1; note_duration_twotigers = TIME_NOTE; end
                        8'd12: begin count1_twotigers = M_2; note_duration_twotigers = TIME_NOTE; end
                        8'd14: begin count1_twotigers = M_3; note_duration_twotigers = TIME_NOTE; end
                        8'd16: begin count1_twotigers = M_1; note_duration_twotigers = TIME_NOTE; end
                        8'd18: begin count1_twotigers = REST; note_duration_twotigers = TIME_REST_LONG; end
                        
                        8'd20: begin count1_twotigers = M_3; note_duration_twotigers = TIME_NOTE; end
                        8'd22: begin count1_twotigers = M_4; note_duration_twotigers = TIME_NOTE; end
                        8'd24: begin count1_twotigers = M_5; note_duration_twotigers = TIME_NOTE; end
                        8'd26: begin count1_twotigers = REST; note_duration_twotigers = TIME_REST_LONG; end
                        
                        8'd28: begin count1_twotigers = M_3; note_duration_twotigers = TIME_NOTE; end
                        8'd30: begin count1_twotigers = M_4; note_duration_twotigers = TIME_NOTE; end
                        8'd32: begin count1_twotigers = M_5; note_duration_twotigers = TIME_NOTE; end
                        8'd34: begin count1_twotigers = REST; note_duration_twotigers = TIME_REST_LONG; end
                        
                        8'd36: begin count1_twotigers = M_5; note_duration_twotigers = TIME_NOTE; end
                        8'd38: begin count1_twotigers = M_6; note_duration_twotigers = TIME_NOTE; end
                        8'd40: begin count1_twotigers = M_5; note_duration_twotigers = TIME_NOTE; end
                        8'd42: begin count1_twotigers = M_4; note_duration_twotigers = TIME_NOTE; end
                        8'd44: begin count1_twotigers = M_3; note_duration_twotigers = TIME_NOTE; end
                        8'd46: begin count1_twotigers = M_1; note_duration_twotigers = TIME_NOTE; end
                        8'd48: begin count1_twotigers = REST; note_duration_twotigers = TIME_REST_LONG; end
                        
                        8'd50: begin count1_twotigers = M_5; note_duration_twotigers = TIME_NOTE; end
                        8'd52: begin count1_twotigers = M_6; note_duration_twotigers = TIME_NOTE; end
                        8'd54: begin count1_twotigers = M_5; note_duration_twotigers = TIME_NOTE; end
                        8'd56: begin count1_twotigers = M_4; note_duration_twotigers = TIME_NOTE; end
                        8'd58: begin count1_twotigers = M_3; note_duration_twotigers = TIME_NOTE; end
                        8'd60: begin count1_twotigers = M_1; note_duration_twotigers = TIME_NOTE; end
                        8'd62: begin count1_twotigers = REST; note_duration_twotigers = TIME_REST_LONG; end
                        
                        8'd64: begin count1_twotigers = M_2; note_duration_twotigers = TIME_NOTE; end
                        8'd66: begin count1_twotigers = L_5; note_duration_twotigers = TIME_NOTE; end
                        8'd68: begin count1_twotigers = M_1; note_duration_twotigers = TIME_NOTE; end
                        8'd70: begin count1_twotigers = REST; note_duration_twotigers = TIME_REST_LONG; end
                        
                        8'd72: begin count1_twotigers = M_2; note_duration_twotigers = TIME_NOTE; end
                        8'd74: begin count1_twotigers = L_5; note_duration_twotigers = TIME_NOTE; end
                        8'd76: begin count1_twotigers = M_1; note_duration_twotigers = TIME_NOTE; end
                        8'd78: begin count1_twotigers = REST; note_duration_twotigers = TIME_REST_LONG; end
                        
                        8'd1, 8'd3, 8'd5, 8'd7,
                        8'd11, 8'd13, 8'd15, 8'd17,
                        8'd21, 8'd23, 8'd25,
                        8'd29, 8'd31, 8'd33,
                        8'd37, 8'd39, 8'd41, 8'd43, 8'd45, 8'd47,
                        8'd51, 8'd53, 8'd55, 8'd57, 8'd59, 8'd61,
                        8'd65, 8'd67, 8'd69,
                        8'd73, 8'd75, 8'd77: 
                            begin count1_twotigers = REST; note_duration_twotigers = TIME_REST; end
                        
                        default: begin count1_twotigers = 16'h0; note_duration_twotigers = TIME_NOTE; end
                    endcase
                end
            end
        end
        else begin
            count2_twotigers <= 1'b0;
            state_twotigers <= 8'd0;
            note_duration_twotigers <= TIME_NOTE;
            pause_twotigers <= 1'b0;
        end
    end
    
    // ========== 铃儿响叮当播放模块 ==========
    // 产生音符频率的方波
    always @(posedge clk_27m) begin
        if(music_select == 2'b00 && !pause_jingle) begin 
            count_jingle <= count_jingle + 1'b1;
            if (count_jingle == count1_jingle) begin
                count_jingle <= 17'h0;
                beep_r_jingle <= ~beep_r_jingle;
            end
        end
        else begin
            count_jingle <= 1'b0;
            beep_r_jingle <= 1'b0;
        end
    end
    
    // 铃儿响叮当乐谱状态机
    always @(posedge clk_27m) begin
        if(music_select == 2'b00) begin
            if(play_pause == 1'b0) begin
                pause_jingle <= 1'b1;
            end else begin
                pause_jingle <= 1'b0;
            end
            
            if(!pause_jingle) begin
                if (count2_jingle < note_duration_jingle)
                    count2_jingle <= count2_jingle + 1'b1;
                else begin
                    count2_jingle <= 26'd0;
                    if (state_jingle == 8'd117)
                        state_jingle <= 8'd0;
                    else
                        state_jingle <= state_jingle + 1'b1;
                    
                    case(state_jingle)
                        // ========== 第一句: 3 3 3 | 3 3 3 | 3 5 1 2 | 3 ==========
                        8'd0:  begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd1:  begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd2:  begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd3:  begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd4:  begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd5:  begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd6:  begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd7:  begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd8:  begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd9:  begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd10: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd11: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd12: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd13: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd14: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd15: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd16: begin count1_jingle = M_5; note_duration_jingle = TIME_NOTE; end
                        8'd17: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd18: begin count1_jingle = H_1; note_duration_jingle = TIME_NOTE; end
                        8'd19: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd20: begin count1_jingle = M_2; note_duration_jingle = TIME_NOTE; end
                        8'd21: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd22: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd23: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd24: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd25: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        8'd26: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        // ========== 第二句: 4 4 4 | 4 4 3 | 3 3 3 2 | 2 3 2 5 ==========
                        8'd27: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd28: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd29: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd30: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd31: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd32: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd33: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd34: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd35: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd36: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd37: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd38: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd39: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd40: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd41: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd42: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd43: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd44: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd45: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd46: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd47: begin count1_jingle = M_2; note_duration_jingle = TIME_NOTE; end
                        8'd48: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd49: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd50: begin count1_jingle = M_2; note_duration_jingle = TIME_NOTE; end
                        8'd51: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd52: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd53: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd54: begin count1_jingle = M_2; note_duration_jingle = TIME_NOTE; end
                        8'd55: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd56: begin count1_jingle = M_5; note_duration_jingle = TIME_NOTE; end
                        8'd57: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd58: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        8'd59: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        // ========== 第三句: 重复第一句 ==========
                        8'd60: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd61: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd62: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd63: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd64: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd65: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd66: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd67: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd68: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd69: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd70: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd71: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd72: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd73: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd74: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd75: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd76: begin count1_jingle = M_5; note_duration_jingle = TIME_NOTE; end
                        8'd77: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd78: begin count1_jingle = H_1; note_duration_jingle = TIME_NOTE; end
                        8'd79: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd80: begin count1_jingle = M_2; note_duration_jingle = TIME_NOTE; end
                        8'd81: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd82: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd83: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd84: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd85: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        8'd86: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        // ========== 第四句: 4 4 4 | 4 4 3 | 3 3 5 5 | 4 2 1 ==========
                        8'd87: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd88: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd89: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd90: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd91: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd92: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd93: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd94: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd95: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd96: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd97: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd98: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd99: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd100: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd101: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd102: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd103: begin count1_jingle = M_3; note_duration_jingle = TIME_NOTE; end
                        8'd104: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd105: begin count1_jingle = M_5; note_duration_jingle = TIME_NOTE; end
                        8'd106: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd107: begin count1_jingle = M_5; note_duration_jingle = TIME_NOTE; end
                        8'd108: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd109: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        8'd110: begin count1_jingle = M_4; note_duration_jingle = TIME_NOTE; end
                        8'd111: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd112: begin count1_jingle = M_2; note_duration_jingle = TIME_NOTE; end
                        8'd113: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd114: begin count1_jingle = M_1; note_duration_jingle = TIME_NOTE; end
                        8'd115: begin count1_jingle = REST; note_duration_jingle = TIME_REST; end
                        8'd116: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        8'd117: begin count1_jingle = REST; note_duration_jingle = TIME_REST_LONG; end
                        
                        default: begin count1_jingle = 16'h0; note_duration_jingle = TIME_NOTE; end
                    endcase
                end
            end
        end
        else begin
            count2_jingle <= 1'b0;
            state_jingle <= 8'd0;
            note_duration_jingle <= TIME_NOTE;
            pause_jingle <= 1'b0;
        end
    end
    
    // ========== 键盘扫描 ==========
    always @(posedge clk_27m) begin
        delay_cnt <= delay_cnt + 1;
        if(delay_cnt == 20'd270000) begin
            delay_cnt <= 0;
            scan_cnt <= scan_cnt + 1;
            case(scan_cnt)
                2'd0: col <= 4'b1110;
                2'd1: col <= 4'b1101;
                2'd2: col <= 4'b1011;
                2'd3: col <= 4'b0111;
            endcase
        end
    end
    
    // ========== 按键解码 ==========
    always @(posedge clk_27m) begin
        row_reg <= row;
        
        case({scan_cnt, row_reg})
            {2'd0, 4'b1110}: raw_key <= 4'b0000;
            {2'd1, 4'b1110}: raw_key <= 4'b1101;
            {2'd2, 4'b1110}: raw_key <= 4'b1110;
            {2'd3, 4'b1110}: raw_key <= 4'b1111;
            
            {2'd0, 4'b1101}: raw_key <= 4'b0111;
            {2'd1, 4'b1101}: raw_key <= 4'b1100;
            {2'd2, 4'b1101}: raw_key <= 4'b1001;
            {2'd3, 4'b1101}: raw_key <= 4'b1000;
            
            {2'd0, 4'b1011}: raw_key <= 4'b0100;
            {2'd1, 4'b1011}: raw_key <= 4'b1011;
            {2'd2, 4'b1011}: raw_key <= 4'b0110;
            {2'd3, 4'b1011}: raw_key <= 4'b0101;
            
            {2'd0, 4'b0111}: raw_key <= 4'b0001;
            {2'd1, 4'b0111}: raw_key <= 4'b1010;
            {2'd2, 4'b0111}: raw_key <= 4'b0011;
            {2'd3, 4'b0111}: raw_key <= 4'b0010;
            
            default: raw_key <= 4'b1111;
        endcase
        
        key_detected <= (row_reg != 4'b1111);
    end
    
    // ========== 按键检测和音乐选择/播放控制/音量控制逻辑 ==========
    reg play_pause_reg;
    reg [22:0] key_lock;          // 按键锁定计数器
    reg light_do_old; 
    reg [24:0] cd_cnt;
    wire wave_pulse = light_do_old & ~light_do;
    initial begin
        play_pause_reg = 1'b0;
        music_select = 2'b01;
        volume_reg = 3'd2;
        key_lock = 21'd0;
        cd_cnt = 25'd0; 
    end
    
    always @(posedge clk_27m) begin
        light_do_old <= light_do;
        // 按键锁定计数
        if(key_lock > 0) begin
            key_lock <= key_lock - 1'b1;
        end
        
        if (wave_pulse && cd_cnt == 0) begin
            music_select <= music_select + 1'b1;
            cd_cnt <= 25'd5400000;
        end else if (cd_cnt > 0) begin
            cd_cnt <= cd_cnt - 1'b1;
        end
        // 只有在未锁定时才检测按键
        if(key_lock == 0 && key_detected && !key_detected_last) begin
            key_lock <= 23'd8100000;  // 锁定18.5ms，防止重复检测
            
            case(raw_key)
                4'b1110: begin
                    music_select <= music_select + 1'b1;
                    play_pause_reg <= 1'b1;
                end
                
                4'b1000: begin
                    if(volume_reg < 3'd4) volume_reg <= volume_reg + 1'b1;
                end
                4'b1001: begin
                    if(volume_reg > 3'd0) volume_reg <= volume_reg - 1'b1;
                end
                
                4'b1010: play_pause_reg <= 1'b1;
                4'b1011: play_pause_reg <= 1'b0;
                default: ;
            endcase
        end
        key_detected_last <= key_detected;
    end
    
    assign play_pause = play_pause_reg;
    
    // ========== 音量系数 → PWM阈值映射 ==========
    // 音量挡位: 0(0%), 1(25%), 2(50%), 3(75%), 4(100%)
    always @(*) begin
        case(volume_reg)
            3'd0: pwm_threshold = 8'd0;       // 0% → 静音
            3'd1: pwm_threshold = 8'd64;      // 25%
            3'd2: pwm_threshold = 8'd128;     // 50%
            3'd3: pwm_threshold = 8'd192;     // 75%
            3'd4: pwm_threshold = 8'd255;     // 100%
            default: pwm_threshold = 8'd128;
        endcase
    end
    
    // ========== PWM调制：原始方波 × 音量系数 ==========
    always @(posedge clk_27m) begin
        pwm_cnt <= pwm_cnt + 1'b1;  // 自由运行 0 → 255 → 0
        
        if(pwm_threshold == 8'd0) begin
            beep_pwm <= 1'b0;                    // 静音
        end else if(pwm_threshold == 8'd255) begin
            beep_pwm <= beep_raw;                // 100%音量，原样输出
        end else begin
            // 占空比 = pwm_threshold / 256
            beep_pwm <= (pwm_cnt < pwm_threshold) ? beep_raw : 1'b0;
        end
    end

endmodule