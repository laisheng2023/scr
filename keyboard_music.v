module keyboard_music(
    input  clk,
    output reg [3:0] col,
    input  [3:0] row,
    output beep,
    
    // ========== 输出给屏幕的信号 ==========
    output reg [3:0] selected_group,
    output reg [2:0] selected_note,
    output reg group_selected,
    output reg note_selected,
    output reg [2:0] volume,
    
    // ========== LED输出 ==========
    output reg [3:0] led_group,
    output reg [7:0] led_flow
);

    // ========== 音符频率参数 ==========
    parameter C2=18'd206346, D2=18'd183876, E2=18'd163820, F2=18'd154624,
              G2=18'd137755, A2=18'd122727, B2=18'd109338;
    parameter C3=18'd103196, D3=18'd91938,  E3=18'd81910,  F3=18'd77312,
              G3=18'd68877,  A3=18'd61364,  B3=18'd54669;
    parameter C4=18'd51598,  D4=18'd45969,  E4=18'd40955,  F4=18'd38656,
              G4=18'd34439,  A4=18'd30682,  B4=18'd27335;
    parameter C5=18'd25799,  D5=18'd22985,  E5=18'd20478,  F5=18'd19328,
              G5=18'd17219,  A5=18'd15341,  B5=18'd13667;
    parameter SILENCE = 18'd0;

    // ========== 键盘扫描 ==========
    reg [1:0] scan_cnt;
    reg [19:0] delay_cnt;
    reg [3:0] col_reg, row_reg;
    reg key_detected, key_detected_last;
    reg [3:0] raw_key;
    
    // ========== 播放控制 ==========
    reg playing;
    reg [25:0] tone_timer;
    reg [17:0] play_freq;
    reg [17:0] current_freq;
    reg [17:0] count, count1;
    reg beep_r;
    
    // ========== PWM音量控制 ==========
    reg [2:0] volume_reg;
    reg [9:0] pwm_counter;
    reg pwm_out;
    
    // ========== LED控制 ==========
    reg [24:0] led_timer;
    reg [2:0] speed_note;  // 当前流水灯速度（由按键更新，保持不变）
    
    parameter TONE_DURATION = 26'd13500000;
    assign beep = pwm_out;

    // ========== 列扫描 ==========
    always @(posedge clk) begin
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
            col_reg <= col;
        end
    end
    
    // ========== 获取原始按键编码 ==========
    always @(posedge clk) begin
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
    
    // ========== 初始化 ==========
    initial begin
        volume_reg <= 3'd3;
        led_timer <= 25'd0;
        speed_note <= 3'd0;  // 默认速度（0=最慢）
    end
    
    // ========== 核心逻辑 ==========
    always @(posedge clk) begin
        if(key_detected && !key_detected_last) begin
            case(raw_key)
                4'b1010: begin
                    selected_group <= 4'd2;
                    group_selected <= 1'b1;
                end
                4'b1011: begin
                    selected_group <= 4'd3;
                    group_selected <= 1'b1;
                end
                4'b1100: begin
                    selected_group <= 4'd4;
                    group_selected <= 1'b1;
                end
                4'b1101: begin
                    selected_group <= 4'd5;
                    group_selected <= 1'b1;
                end
                
                4'b1000: begin
                    if(volume_reg < 3'd5) begin
                        volume_reg <= (volume_reg + 1'b1) % 6;
                    end
                end
                4'b1001: begin
                    if(volume_reg > 3'd0) begin
                        volume_reg <= (volume_reg - 1'b1) % 6;
                    end
                end
                
                4'b0001: begin
                    selected_note <= 3'd1;
                    note_selected <= 1'b1;
                    speed_note <= 3'd1;  // 记录速度
                    if(group_selected) begin
                        playing <= 1'b1;
                        tone_timer <= TONE_DURATION;
                        play_freq <= get_freq(selected_group, 3'd1);
                    end
                end
                4'b0010: begin
                    selected_note <= 3'd2;
                    note_selected <= 1'b1;
                    speed_note <= 3'd2;
                    if(group_selected) begin
                        playing <= 1'b1;
                        tone_timer <= TONE_DURATION;
                        play_freq <= get_freq(selected_group, 3'd2);
                    end
                end
                4'b0011: begin
                    selected_note <= 3'd3;
                    note_selected <= 1'b1;
                    speed_note <= 3'd3;
                    if(group_selected) begin
                        playing <= 1'b1;
                        tone_timer <= TONE_DURATION;
                        play_freq <= get_freq(selected_group, 3'd3);
                    end
                end
                4'b0100: begin
                    selected_note <= 3'd4;
                    note_selected <= 1'b1;
                    speed_note <= 3'd4;
                    if(group_selected) begin
                        playing <= 1'b1;
                        tone_timer <= TONE_DURATION;
                        play_freq <= get_freq(selected_group, 3'd4);
                    end
                end
                4'b0101: begin
                    selected_note <= 3'd5;
                    note_selected <= 1'b1;
                    speed_note <= 3'd5;
                    if(group_selected) begin
                        playing <= 1'b1;
                        tone_timer <= TONE_DURATION;
                        play_freq <= get_freq(selected_group, 3'd5);
                    end
                end
                4'b0110: begin
                    selected_note <= 3'd6;
                    note_selected <= 1'b1;
                    speed_note <= 3'd6;
                    if(group_selected) begin
                        playing <= 1'b1;
                        tone_timer <= TONE_DURATION;
                        play_freq <= get_freq(selected_group, 3'd6);
                    end
                end
                4'b0111: begin
                    selected_note <= 3'd7;
                    note_selected <= 1'b1;
                    speed_note <= 3'd7;
                    if(group_selected) begin
                        playing <= 1'b1;
                        tone_timer <= TONE_DURATION;
                        play_freq <= get_freq(selected_group, 3'd7);
                    end
                end
                
                4'b1111: begin
                    group_selected <= 1'b0;
                    note_selected <= 1'b0;
                    playing <= 1'b0;
                    speed_note <= 3'd0;
                    // 按F时不清除速度，流水灯继续
                end
                
                default: ;
            endcase
        end
        
        key_detected_last <= key_detected;
        
        if(playing) begin
            if(tone_timer > 0) begin
                tone_timer <= tone_timer - 1'b1;
                current_freq <= play_freq;
            end else begin
                playing <= 1'b0;
                current_freq <= SILENCE;
            end
        end else begin
            current_freq <= SILENCE;
        end
        
        volume <= volume_reg;
    end
    
    // ========== 频率查找函数 ==========
    function [17:0] get_freq;
        input [3:0] group;
        input [2:0] note;
        begin
            case({group, note})
                {4'd2,3'd1}: get_freq = C2; {4'd2,3'd2}: get_freq = D2;
                {4'd2,3'd3}: get_freq = E2; {4'd2,3'd4}: get_freq = F2;
                {4'd2,3'd5}: get_freq = G2; {4'd2,3'd6}: get_freq = A2;
                {4'd2,3'd7}: get_freq = B2;
                
                {4'd3,3'd1}: get_freq = C3; {4'd3,3'd2}: get_freq = D3;
                {4'd3,3'd3}: get_freq = E3; {4'd3,3'd4}: get_freq = F3;
                {4'd3,3'd5}: get_freq = G3; {4'd3,3'd6}: get_freq = A3;
                {4'd3,3'd7}: get_freq = B3;
                
                {4'd4,3'd1}: get_freq = C4; {4'd4,3'd2}: get_freq = D4;
                {4'd4,3'd3}: get_freq = E4; {4'd4,3'd4}: get_freq = F4;
                {4'd4,3'd5}: get_freq = G4; {4'd4,3'd6}: get_freq = A4;
                {4'd4,3'd7}: get_freq = B4;
                
                {4'd5,3'd1}: get_freq = C5; {4'd5,3'd2}: get_freq = D5;
                {4'd5,3'd3}: get_freq = E5; {4'd5,3'd4}: get_freq = F5;
                {4'd5,3'd5}: get_freq = G5; {4'd5,3'd6}: get_freq = A5;
                {4'd5,3'd7}: get_freq = B5;
                default: get_freq = SILENCE;
            endcase
        end
    endfunction
    
    // ========== 方波生成 ==========
    always @(posedge clk) begin
        if(current_freq != SILENCE) begin
            count <= count + 1'b1;
            if(count == count1) begin
                count <= 17'd0;
                beep_r <= ~beep_r;
            end
        end else begin
            count <= 17'd0;
            beep_r <= 1'b0;
        end
    end
    
    always @(posedge clk) begin
        count1 <= current_freq;
    end
    
    // ========== PWM音量调节 ==========
    always @(posedge clk) begin
        pwm_counter <= pwm_counter + 1'b1;
        
        case(volume_reg)
            3'd0: pwm_out <= 1'b0;
            3'd1: pwm_out <= (pwm_counter < 10'd102) ? beep_r : 1'b0;
            3'd2: pwm_out <= (pwm_counter < 10'd256) ? beep_r : 1'b0;
            3'd3: pwm_out <= (pwm_counter < 10'd512) ? beep_r : 1'b0;
            3'd4: pwm_out <= (pwm_counter < 10'd768) ? beep_r : 1'b0;
            3'd5: pwm_out <= beep_r;
            default: pwm_out <= beep_r;
        endcase
    end
    
// ========== LED控制 ==========
always @(posedge clk) begin
    led_timer <= led_timer + 1;
    
    // ===== 音组指示灯：A/B/C/D亮对应灯 =====
    if(group_selected) begin
        case(selected_group)
            4'd2: led_group <= 4'b0001;  // A
            4'd3: led_group <= 4'b0011;  // B
            4'd4: led_group <= 4'b0111;  // C
            4'd5: led_group <= 4'b1111;  // D
            default: led_group <= 4'b0000;
        endcase
    end else begin
        led_group <= 4'b0000;
    end
    
    // ===== 往返流水灯：速度线性分布 =====
    // speed_note = 0：全灭（未按任何音符键）
    // speed_note = 1~7：速度线性递增
if(group_selected) begin
case(speed_note)
    3'd0: begin  // 未按音符：全灭
        led_flow <= 8'b0000_0000;
    end
    3'd1: begin  // Do：2颗往返
        case(led_timer[24:21])
            4'd0:  led_flow <= 8'b0000_0001;
            4'd1:  led_flow <= 8'b0000_0010;
            4'd2:  led_flow <= 8'b0000_0001;
            4'd3:  led_flow <= 8'b0000_0010;
            4'd4:  led_flow <= 8'b0000_0001;
            4'd5:  led_flow <= 8'b0000_0010;
            4'd6:  led_flow <= 8'b0000_0001;
            4'd7:  led_flow <= 8'b0000_0010;
            4'd8:  led_flow <= 8'b0000_0001;
            4'd9:  led_flow <= 8'b0000_0010;
            4'd10:  led_flow <= 8'b0000_0001;
            4'd11:  led_flow <= 8'b0000_0010;
            4'd12:  led_flow <= 8'b0000_0001;
            4'd13:  led_flow <= 8'b0000_0010;
            4'd14:  led_flow <= 8'b0000_0001;
            4'd15:  led_flow <= 8'b0000_0010;
            default: led_flow <= 8'b0000_0000;
        endcase
    end
    3'd2: begin  // Re：3颗往返
        case(led_timer[24:21])
            4'd0:  led_flow <= 8'b0000_0001;
            4'd1:  led_flow <= 8'b0000_0010;
            4'd2:  led_flow <= 8'b0000_0100;
            4'd3:  led_flow <= 8'b0000_0010;
            4'd4:  led_flow <= 8'b0000_0001;
            4'd5:  led_flow <= 8'b0000_0010;
            4'd6:  led_flow <= 8'b0000_0100;
            4'd7:  led_flow <= 8'b0000_0010;
            4'd8:  led_flow <= 8'b0000_0001;
            4'd9:  led_flow <= 8'b0000_0010;
            4'd10: led_flow <= 8'b0000_0100;
            4'd11: led_flow <= 8'b0000_0010;
            4'd12: led_flow <= 8'b0000_0001;
            4'd13: led_flow <= 8'b0000_0010;
            4'd14: led_flow <= 8'b0000_0100;
            4'd15: led_flow <= 8'b0000_0010;
            default: led_flow <= 8'b0000_0000;
        endcase
    end
    3'd3: begin  // Mi：4颗往返
        case(led_timer[24:21])
            4'd0:  led_flow <= 8'b0000_0001;
            4'd1:  led_flow <= 8'b0000_0010;
            4'd2:  led_flow <= 8'b0000_0100;
            4'd3:  led_flow <= 8'b0000_1000;
            4'd4:  led_flow <= 8'b0000_0100;
            4'd5:  led_flow <= 8'b0000_0010;
            4'd6:  led_flow <= 8'b0000_0001;
            4'd7:  led_flow <= 8'b0000_0010;
            4'd8:  led_flow <= 8'b0000_0100;
            4'd9:  led_flow <= 8'b0000_1000;
            4'd10: led_flow <= 8'b0000_0100;
            4'd11: led_flow <= 8'b0000_0010;
            4'd12: led_flow <= 8'b0000_0001;
            default: led_flow <= 8'b0000_0000;
        endcase
    end
    3'd4: begin  // Fa：5颗往返
        case(led_timer[24:21])
            4'd0:  led_flow <= 8'b0000_0001;
            4'd1:  led_flow <= 8'b0000_0010;
            4'd2:  led_flow <= 8'b0000_0100;
            4'd3:  led_flow <= 8'b0000_1000;
            4'd4:  led_flow <= 8'b0001_0000;
            4'd5:  led_flow <= 8'b0000_1000;
            4'd6:  led_flow <= 8'b0000_0100;
            4'd7:  led_flow <= 8'b0000_0010;
            4'd8:  led_flow <= 8'b0000_0001;
            4'd9:  led_flow <= 8'b0000_0010;
            4'd10: led_flow <= 8'b0000_0100;
            4'd11: led_flow <= 8'b0000_1000;
            4'd12: led_flow <= 8'b0001_0000;
            4'd13: led_flow <= 8'b0000_1000;
            4'd14: led_flow <= 8'b0000_0100;
            4'd15: led_flow <= 8'b0000_0010;
            default: led_flow <= 8'b0000_0000;
        endcase
    end
    3'd5: begin  // Sol：6颗往返
        case(led_timer[24:21])
            4'd0:  led_flow <= 8'b0000_0001;
            4'd1:  led_flow <= 8'b0000_0010;
            4'd2:  led_flow <= 8'b0000_0100;
            4'd3:  led_flow <= 8'b0000_1000;
            4'd4:  led_flow <= 8'b0001_0000;
            4'd5:  led_flow <= 8'b0010_0000;
            4'd6:  led_flow <= 8'b0001_0000;
            4'd7:  led_flow <= 8'b0000_1000;
            4'd8:  led_flow <= 8'b0000_0100;
            4'd9:  led_flow <= 8'b0000_0010;
            4'd10: led_flow <= 8'b0000_0001;
            default: led_flow <= 8'b0000_0000;
        endcase
    end
    3'd6: begin  // La：7颗往返
        case(led_timer[24:21])
            4'd0:  led_flow <= 8'b0000_0001;
            4'd1:  led_flow <= 8'b0000_0010;
            4'd2:  led_flow <= 8'b0000_0100;
            4'd3:  led_flow <= 8'b0000_1000;
            4'd4:  led_flow <= 8'b0001_0000;
            4'd5:  led_flow <= 8'b0010_0000;
            4'd6:  led_flow <= 8'b0100_0000;
            4'd7:  led_flow <= 8'b0010_0000;
            4'd8:  led_flow <= 8'b0001_0000;
            4'd9:  led_flow <= 8'b0000_1000;
            4'd10: led_flow <= 8'b0000_0100;
            4'd11: led_flow <= 8'b0000_0010;
            4'd12: led_flow <= 8'b0000_0001;
            default: led_flow <= 8'b0000_0000;
        endcase
    end
    3'd7: begin  // Si：8颗往返
        case(led_timer[24:21])
            4'd0:  led_flow <= 8'b0000_0001;
            4'd1:  led_flow <= 8'b0000_0010;
            4'd2:  led_flow <= 8'b0000_0100;
            4'd3:  led_flow <= 8'b0000_1000;
            4'd4:  led_flow <= 8'b0001_0000;
            4'd5:  led_flow <= 8'b0010_0000;
            4'd6:  led_flow <= 8'b0100_0000;
            4'd7:  led_flow <= 8'b1000_0000;
            4'd8:  led_flow <= 8'b0100_0000;
            4'd9:  led_flow <= 8'b0010_0000;
            4'd10: led_flow <= 8'b0001_0000;
            4'd11: led_flow <= 8'b0000_1000;
            4'd12: led_flow <= 8'b0000_0100;
            4'd13: led_flow <= 8'b0000_0010;
            4'd14: led_flow <= 8'b0000_0001;
            default: led_flow <= 8'b0000_0000;
        endcase
    end
    default: begin
        led_flow <= 8'b0000_0000;
    end
endcase
end else begin
        led_flow <= 8'b0000_0000;  // 未选音组：全灭
end
end

endmodule