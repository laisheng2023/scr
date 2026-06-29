module lcd_driver(
    input  clk,                    // 27MHz时钟
    input  [3:0] group,            // 来自键盘的音组 (2-5)
    input  [2:0] note,             // 来自键盘的音符 (1-7)
    input  group_valid,            // 音组是否有效
    input  note_valid,
    
    // LCD 接口
    output cs,
    output dc,
    output scl,
    output sda,
    output rst
);

    // ========== 屏幕显示参数 ==========
    localparam LCD_W = 8'd132;
    localparam LCD_H = 8'd162;
    
    // 颜色定义（8 位 RGB 332，不是 16 位）
    localparam COLOR_RED    = 8'b111_000_00;  // 红色
    localparam COLOR_GREEN  = 8'b000_000_11;  // 绿色（原蓝色值）
    localparam COLOR_BLUE   = 8'b000_111_00;  // 蓝色（原绿色值）
    localparam COLOR_WHITE  = 8'b111_111_11;  // 白色
    localparam COLOR_BLACK  = 8'b000_000_00;  // 黑色
    localparam COLOR_YELLOW = 8'b111_111_00;  // 黄色
    
    // 三个暖黄色（补偿 G/B 反接）
    localparam COLOR_DARK_YELLOW  = 8'b111_000_11;  // 深暖黄
    localparam COLOR_WARM_YELLOW  = 8'b111_010_10;  // 暖米黄
    localparam COLOR_LIGHT_YELLOW = 8'b111_010_11;  // 亮淡黄
    
    localparam IDLE  = 4'd0;
    localparam MAIN  = 4'd1;
    localparam INIT  = 4'd2;
    localparam SCAN  = 4'd3;
    localparam WRITE = 4'd4;
    localparam DELAY = 4'd5;
    
    localparam LOW  = 1'b0;
    localparam HIGH = 1'b1;
    
    // ========== 寄存器 ==========
    reg [3:0] state;
    reg [3:0] state_back;
    reg [7:0] x_cnt;
    reg [7:0] y_cnt;
    reg [5:0] cnt_write;
    reg [23:0] cnt_delay;
    reg [23:0] num_delay;
    reg [15:0] cnt;
    reg [2:0] cnt_main;
    reg [2:0] cnt_init;
    reg [3:0] cnt_scan;
    reg [8:0] data_reg;
    reg high_word;
    reg [1:0] clk_div;
    
    reg cs_r;
    reg dc_r;
    reg scl_r;
    reg sda_r;
    reg rst_r;
    
    reg show_pixel;
    reg [15:0] pixel_color;
    
    wire clk_spi = clk_div[0];
    
    // ========== 初始化命令 ==========
    reg [8:0] reg_init [0:5];
    reg [8:0] reg_setxy [0:10];
    
    // ========== 点阵数据 ==========
    reg [0:63] yanzoumoshi [0:15];
    reg [0:63] jianzu [0:15];
    reg [0:63] yinliang [0:15];
    reg [0:63] yingao [0:15];
    reg [0:63] A [0:15];
    reg [0:63] B [0:15];
    reg [0:63] C [0:15];
    reg [0:63] D [0:15];
    reg [0:63] F [0:15];
    reg [0:15] ling [0:15];      // 0
    reg [0:15] er [0:15];        // 2
    reg [0:15] san [0:15];       // 3
    reg [0:15] si [0:15];        // 4
    reg [0:15] wu [0:15];        // 5
    reg [0:15] yi [0:15];        // 1
    reg [0:15] liu [0:15];       // 6
    reg [0:15] qi [0:15];        // 7
    (* keep = "true" *) reg [31:0] Do [0:15];
    (* DONT_TOUCH = "true" *) reg [31:0] Re [0:15];
    (* keep = "true" *) reg [31:0] Mi [0:15];
    (* keep = "true" *) reg [31:0] Fa [0:15];
    (* keep = "true" *) reg [31:0] So [0:15];
    (* keep = "true" *) reg [31:0] La [0:15];
    (* keep = "true" *) reg [31:0] Si [0:15];
    
    // ========== 点阵演奏模式数据加载 ==========
    initial begin
        $readmemh("yanzoumoshi.hex", yanzoumoshi);
        $readmemh("jianzu.hex", jianzu);
        $readmemh("yinliang.hex", yinliang);
        $readmemh("yingao.hex", yingao);
        $readmemh("A.hex", A);
        $readmemh("B.hex", B);
        $readmemh("C.hex", C);
        $readmemh("D.hex", D);
        $readmemh("F.hex", F);
        $readmemh("Do.hex", Do);
        $readmemh("Re.hex", Re);
        $readmemh("Mi.hex", Mi);
        $readmemh("Fa.hex", Fa);
        $readmemh("So.hex", So);
        $readmemh("La.hex", La);
        $readmemh("Si_note.hex", Si);
    end

    // ========== 初始化命令赋值 ==========
    integer j;
    initial begin
        reg_init[0] = {1'b0, 8'h11};  // 退出睡眠
        reg_init[1] = {1'b0, 8'h3a};  // 像素格式
        reg_init[2] = {1'b1, 8'h05};  // 16位色
        reg_init[3] = {1'b0, 8'h36};  // 内存访问控制
        reg_init[4] = {1'b1, 8'h80};  // 设置
        reg_init[5] = {1'b0, 8'h29};  // 开启显示
        
        reg_setxy[0]  = {1'b0, 8'h2a};  // 列地址
        reg_setxy[1]  = {1'b1, 8'h00};
        reg_setxy[2]  = {1'b1, 8'h00};
        reg_setxy[3]  = {1'b1, 8'h00};
        reg_setxy[4]  = {1'b1, 8'd131};
        reg_setxy[5]  = {1'b0, 8'h2b};  // 行地址
        reg_setxy[6]  = {1'b1, 8'h00};
        reg_setxy[7]  = {1'b1, 8'h00};
        reg_setxy[8]  = {1'b1, 8'h00};
        reg_setxy[9]  = {1'b1, 8'd161};
        reg_setxy[10] = {1'b0, 8'h2c};  // 写内存
    end
    
    // ========== 状态机初始化 ==========
    initial begin
        state = IDLE;
        state_back = IDLE;
        x_cnt = 8'd0;
        y_cnt = 8'd0;
        cnt_write = 6'd0;
        cnt_delay = 24'd0;
        num_delay = 24'd0;
        cnt = 16'd0;
        cnt_main = 3'd0;
        cnt_init = 3'd0;
        cnt_scan = 4'd0;
        data_reg = 9'd0;
        high_word = 1'b1;
        clk_div = 2'd0;
        cs_r = 1'b1;
        dc_r = 1'b1;
        scl_r = 1'b1;
        sda_r = 1'b1;
        rst_r = 1'b0;
        show_pixel = 1'b0;
        pixel_color = COLOR_WHITE;
    end
    
    assign cs = cs_r;
    assign dc = dc_r;
    assign scl = scl_r;
    assign sda = sda_r;
    assign rst = rst_r;
    
    // ========== 时钟分频 ==========
    always @(posedge clk) begin
        clk_div <= clk_div + 1'b1;
    end
    
    // ========== 主状态机 ==========
    always @(posedge clk_spi) begin
        case(state)
            IDLE: begin
                x_cnt <= 8'd0;
                y_cnt <= 8'd0;
                cnt_main <= 3'd0;
                cnt_init <= 3'd0;
                cnt_scan <= 4'd0;
                high_word <= 1'b1;
                cnt <= 16'd0;
                cnt_write <= 6'd0;
                cnt_delay <= 24'd0;
                cs_r <= 1'b1;
                scl_r <= 1'b1;
                rst_r <= 1'b1;
                state <= MAIN;
                state_back <= MAIN;
            end
            
            MAIN: begin
                case(cnt_main)
                    3'd0: begin state <= INIT; cnt_main <= cnt_main + 1'b1; end
                    3'd1: begin state <= SCAN; cnt_main <= cnt_main + 1'b1; end
                    3'd2: begin cnt_main <= 3'd1; end
                    default: cnt_main <= 3'd0;
                endcase
            end
            
            INIT: begin
                case(cnt_init)
                    3'd0: begin
                        num_delay <= 24'd500000;
                        state <= DELAY;
                        state_back <= INIT;
                        cnt_init <= cnt_init + 1'b1;
                    end
                    3'd1: begin
                        if(cnt >= 6) begin
                            cnt <= 16'd0;
                            cnt_init <= cnt_init + 1'b1;
                        end else begin
                            data_reg <= reg_init[cnt];
                            num_delay <= 24'd5000;
                            cnt <= cnt + 1;
                            state <= WRITE;
                            state_back <= INIT;
                        end
                    end
                    3'd2: begin
                        cnt_init <= 3'd0;
                        state <= MAIN;
                    end
                    default: cnt_init <= 3'd0;
                endcase
            end
            
            SCAN: begin
                case(cnt_scan)
                    4'd0: begin
                        if(cnt >= 11) begin
                            cnt <= 16'd0;
                            cnt_scan <= cnt_scan + 1'b1;
                        end else begin
                            data_reg <= reg_setxy[cnt];
                            cnt <= cnt + 1;
                            num_delay <= 24'd1000;
                            state <= WRITE;
                            state_back <= SCAN;
                        end
                    end
                    
                    4'd1: begin
                        show_pixel = 1'b0;
                        pixel_color = COLOR_WHITE;
                        
                        // ========== 演奏模式 ==========
                        if(y_cnt >= 5 && y_cnt <= 20 && x_cnt >= 34 && x_cnt <= 97) begin
                            if(yanzoumoshi[y_cnt-5][(x_cnt-34)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_RED;
                            end
                        end
                        // ========== 键组 ==========
                        else if(y_cnt >= 30 && y_cnt <= 45 && x_cnt >= 62 && x_cnt <= 125) begin
                            if(jianzu[y_cnt-30][(x_cnt-62)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_GREEN;
                            end
                        end
                        // ========== 显示当前音组（复用 A,B,C,D 的左边32列）==========
                        else if(y_cnt >= 30 && y_cnt <= 45 && x_cnt >= 30 && x_cnt <= 61) begin
                            show_pixel = 1'b0;
                            if(group_valid) begin
                                case(group)
                                    4'd2: if(A[y_cnt-30][(x_cnt-30)]) show_pixel = 1'b1;
                                    4'd3: if(B[y_cnt-30][(x_cnt-30)]) show_pixel = 1'b1;
                                    4'd4: if(C[y_cnt-30][(x_cnt-30)]) show_pixel = 1'b1;
                                    4'd5: if(D[y_cnt-30][(x_cnt-30)]) show_pixel = 1'b1;
                                endcase
                                if(show_pixel) pixel_color = COLOR_GREEN;
                            end
                        end
                        // ========== 音量 ==========
                        else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 62 && x_cnt <= 125) begin
                            if(yingao[y_cnt-47][(x_cnt-62)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_BLUE;
                            end
                        end
                        // ========== 音符 Do ==========
                        else if(y_cnt >= 73 && y_cnt <= 88 && x_cnt >= 0 && x_cnt <= 1) begin
                            if(Do[y_cnt-73][(x_cnt)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_WHITE;
                            end
                        end
                        // ========== 音符 Re ==========
                        else if(y_cnt >= 73 && y_cnt <= 88 && x_cnt >= 2 && x_cnt <= 3) begin
                            if(Re[y_cnt-73][(x_cnt-2)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_WHITE;
                            end
                        end
                        // ========== 音符 Mi ==========
                        else if(y_cnt >= 73 && y_cnt <= 88 && x_cnt >= 4 && x_cnt <= 5) begin
                            if(Mi[y_cnt-73][(x_cnt-4)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_WHITE;
                            end
                        end
                        // ========== 音符 Fa ==========
                        else if(y_cnt >= 105 && y_cnt <= 120 && x_cnt >= 6 && x_cnt <= 7) begin
                            if(Fa[y_cnt-105][(x_cnt-6)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_WHITE;
                            end
                        end
                        // ========== 音符 So ==========
                        else if(y_cnt >= 39 && y_cnt <= 40 && x_cnt >= 8 && x_cnt <= 9) begin
                            if(So[y_cnt-39][(x_cnt-8)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_WHITE;
                            end
                        end                        
                        // ========== 音符 La ==========
                        else if(y_cnt >= 39 && y_cnt <= 40 && x_cnt >= 10 && x_cnt <= 11) begin
                            if(La[y_cnt-39][(x_cnt-10)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_WHITE;
                            end
                        end
                        // ========== 音符 Si ==========
                        else if(y_cnt >= 39 && y_cnt <= 40 && x_cnt >= 12 && x_cnt <= 13) begin
                            if(Si[y_cnt-39][(x_cnt-12)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_WHITE;
                            end
                        end
                        // ========== 显示当前按下的音符 ==========
                        else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 30 && x_cnt <= 61) begin
                            show_pixel = 1'b0;  
                            if(note_valid && group_valid) begin
                                case(note)
                                    3'd1: if(Do[y_cnt-47][(x_cnt-30)]) show_pixel = 1'b1;
                                    3'd2: if(Re[y_cnt-47][(x_cnt-30)]) show_pixel = 1'b1;
                                    3'd3: if(Mi[y_cnt-47][(x_cnt-30)]) show_pixel = 1'b1;
                                    3'd4: if(Fa[y_cnt-47][(x_cnt-30)]) show_pixel = 1'b1;
                                    3'd5: if(So[y_cnt-47][(x_cnt-30)]) show_pixel = 1'b1;
                                    3'd6: if(La[y_cnt-47][(x_cnt-30)]) show_pixel = 1'b1;
                                    3'd7: if(Si[y_cnt-47][(x_cnt-30)]) show_pixel = 1'b1;
                                endcase
                                if(show_pixel) pixel_color = COLOR_BLUE;
                            end
                        end
                        // ========== A ==========
                        else if(y_cnt >= 73 && y_cnt <= 88 && x_cnt >= 62 && x_cnt <= 125) begin
                            if(A[y_cnt-73][(x_cnt-62)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_BLACK;
                            end
                        end
                        // ========== B ==========
                        else if(y_cnt >= 90 && y_cnt <= 105 && x_cnt >= 62 && x_cnt <= 125) begin
                            if(B[y_cnt-90][(x_cnt-62)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_BLACK;
                            end
                        end
                        // ========== C ==========
                        else if(y_cnt >= 107 && y_cnt <= 122 && x_cnt >= 62 && x_cnt <= 125) begin
                            if(C[y_cnt-107][(x_cnt-62)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_BLACK;
                            end
                        end
                        // ========== D ==========
                        else if(y_cnt >= 124 && y_cnt <= 139 && x_cnt >= 62 && x_cnt <= 125) begin
                            if(D[y_cnt-124][(x_cnt-62)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_BLACK;
                            end
                        end
                        // ========== F ==========
                        else if(y_cnt >= 141 && y_cnt <= 156 && x_cnt >= 62 && x_cnt <= 125) begin
                            if(F[y_cnt-141][(x_cnt-62)]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_RED;
                            end
                        end
                        
                        // ========== 发送数据或背景 ==========
                        if(show_pixel) begin
                            data_reg <= {1'b1, pixel_color[7:0]};
                        end else begin
                            if(y_cnt >= 0 && y_cnt <= 25) begin
                                data_reg <= {1'b1, COLOR_DARK_YELLOW[7:0]};
                            end else if(y_cnt >= 26 && y_cnt <= 67) begin
                                data_reg <= {1'b1, COLOR_WHITE[7:0]};
                            end else if(y_cnt >= 68 && y_cnt <= 163) begin
                                data_reg <= {1'b1, COLOR_WHITE[7:0]};
                            end else begin
                                data_reg <= {1'b1, COLOR_WHITE[7:0]};
                            end
                        end
                        num_delay <= 24'd100;
                        state <= WRITE;
                        state_back <= SCAN;
                        cnt_scan <= cnt_scan + 1'b1;
                    end
                    
                    4'd2: begin
                        if(high_word) begin
                            if(show_pixel) begin
                                data_reg <= {1'b1, pixel_color[7:0]};
                            end else begin
                                data_reg <= {1'b1, COLOR_WHITE[7:0]};
                            end
                            num_delay <= 24'd100;
                            state <= WRITE;
                            state_back <= SCAN;
                            high_word <= 1'b0;
                        end else begin
                            high_word <= 1'b1;
                            if(x_cnt >= LCD_W-1) begin
                                x_cnt <= 8'd0;
                                if(y_cnt >= LCD_H-1) begin
                                    y_cnt <= 8'd0;
                                    cnt_scan <= 4'd0;
                                end else begin
                                    y_cnt <= y_cnt + 1'b1;
                                    cnt_scan <= 4'd1;
                                end
                            end else begin
                                x_cnt <= x_cnt + 1'b1;
                                cnt_scan <= 4'd1;
                            end
                        end
                    end
                    
                    default: cnt_scan <= 4'd0;
                endcase
            end
            
            WRITE: begin
                if(cnt_write >= 6'd17) begin
                    cnt_write <= 6'd0;
                    state <= DELAY;
                end else begin
                    cnt_write <= cnt_write + 1'b1;
                end
                cs_r <= 1'b0;
                case(cnt_write)
                    6'd0:  dc_r <= data_reg[8];
                    6'd1:  begin scl_r <= LOW; sda_r <= data_reg[7]; end
                    6'd2:  scl_r <= HIGH;
                    6'd3:  begin scl_r <= LOW; sda_r <= data_reg[6]; end
                    6'd4:  scl_r <= HIGH;
                    6'd5:  begin scl_r <= LOW; sda_r <= data_reg[5]; end
                    6'd6:  scl_r <= HIGH;
                    6'd7:  begin scl_r <= LOW; sda_r <= data_reg[4]; end
                    6'd8:  scl_r <= HIGH;
                    6'd9:  begin scl_r <= LOW; sda_r <= data_reg[3]; end
                    6'd10: scl_r <= HIGH;
                    6'd11: begin scl_r <= LOW; sda_r <= data_reg[2]; end
                    6'd12: scl_r <= HIGH;
                    6'd13: begin scl_r <= LOW; sda_r <= data_reg[1]; end
                    6'd14: scl_r <= HIGH;
                    6'd15: begin scl_r <= LOW; sda_r <= data_reg[0]; end
                    6'd16: scl_r <= HIGH;
                    6'd17: scl_r <= LOW;
                    default: begin end
                endcase
            end
            
            DELAY: begin
                cs_r <= 1'b1;
                if(cnt_delay >= num_delay) begin
                    cnt_delay <= 24'd0;
                    state <= state_back;
                end else begin
                    cnt_delay <= cnt_delay + 1'b1;
                end
            end
            
            default: state <= IDLE;
        endcase
    end

endmodule