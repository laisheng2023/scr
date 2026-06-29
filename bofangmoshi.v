module bofangmoshi(
    input  clk_27m,
    output cs,
    output dc,
    output scl,
    output sda,
    output rst,
    input [1:0] music_select,
    input play_pause,
    input [2:0] volume
);

// ========== 参数 ==========
localparam LCD_W = 8'd132;
localparam LCD_H = 8'd162;

localparam COLOR_RED    = 8'b111_000_00;
localparam COLOR_GREEN  = 8'b000_000_11;
localparam COLOR_BLUE   = 8'b000_111_00;
localparam COLOR_WHITE  = 8'b111_111_11;
localparam COLOR_BLACK  = 8'b000_000_00;
localparam COLOR_YELLOW = 8'b111_111_00;
localparam COLOR_DARK_YELLOW  = 8'b111_000_11;
localparam COLOR_WARM_YELLOW  = 8'b111_010_10;
localparam COLOR_LIGHT_YELLOW = 8'b111_010_11;

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

// ========== 点阵存储 ==========
reg [0:63] bofangmoshi [0:15];
reg [0:63] zhuangtai [0:15];
reg [0:127] kongzhi [0:15];
reg [0:63] yinliang [0:15];
reg [0:127] yljj [0:15];
reg [0:127] fanhui [0:15];
reg [63:0] xiaoxx [0:15];
reg [63:0] qingtian [0:15];
reg [63:0] laohu [0:15];
reg [63:0] jinglebells [0:15];
reg [63:0] gequ [0:15];
reg [63:0] xiangdd [0:15];
reg [0:15] er [0:15];
reg [0:15] san [0:15];
reg [0:15] si [0:15];
reg [0:15] ling [0:15];
reg [0:15] yi [0:15];

// ========== 初始化命令 ==========
reg [8:0] reg_init [0:5];
reg [8:0] reg_setxy [0:10];

// ========== 加载点阵数据 ==========
initial begin
    $readmemh("bofangmoshi.hex", bofangmoshi);
    $readmemh("zhuangtai.hex", zhuangtai);
    $readmemh("kongzhi.hex", kongzhi);
    $readmemh("yinliang.hex", yinliang);
    $readmemh("yljj.hex", yljj);
    $readmemh("fanhui.hex", fanhui);
    $readmemh("xiaoxx.hex", xiaoxx);
    $readmemh("qingtian.hex", qingtian);
    $readmemh("laohu.hex", laohu);
    $readmemh("gequ.hex", gequ);
    $readmemh("xiangdd.hex", xiangdd);
    $readmemh("er.hex", er);
    $readmemh("san.hex", san);
    $readmemh("si.hex", si);
    $readmemh("ling.hex", ling);
    $readmemh("yi.hex", yi);
    $display("All bitmap files loaded successfully");
end

// ========== 初始化命令赋值 ==========
integer j;
initial begin
    reg_init[0] = {1'b0, 8'h11};
    reg_init[1] = {1'b0, 8'h3a};
    reg_init[2] = {1'b1, 8'h05};
    reg_init[3] = {1'b0, 8'h36};
    reg_init[4] = {1'b1, 8'h80};
    reg_init[5] = {1'b0, 8'h29};

    reg_setxy[0]  = {1'b0, 8'h2a};
    reg_setxy[1]  = {1'b1, 8'h00};
    reg_setxy[2]  = {1'b1, 8'h00};
    reg_setxy[3]  = {1'b1, 8'h00};
    reg_setxy[4]  = {1'b1, 8'd131};
    reg_setxy[5]  = {1'b0, 8'h2b};
    reg_setxy[6]  = {1'b1, 8'h00};
    reg_setxy[7]  = {1'b1, 8'h00};
    reg_setxy[8]  = {1'b1, 8'h00};
    reg_setxy[9]  = {1'b1, 8'd161};
    reg_setxy[10] = {1'b0, 8'h2c};
end

// ========== 状态机初始值 ==========
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
end

// ========== 输出赋值 ==========
assign cs = cs_r;
assign dc = dc_r;
assign scl = scl_r;
assign sda = sda_r;
assign rst = rst_r;

// ========== 时钟分频 ==========
always @(posedge clk_27m) begin
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

                    // 区域1：播放模式图标
                    if(y_cnt >= 5 && y_cnt <= 20 && x_cnt >= 34 && x_cnt <= 97) begin
                        if(bofangmoshi[y_cnt-5][ (x_cnt-34)]) begin
                            show_pixel = 1'b1;
                            pixel_color = COLOR_RED;
                        end
                    end
                    // 区域2：状态图标
                    else if(y_cnt >= 30 && y_cnt <= 45 && x_cnt >= 65 && x_cnt <= 128) begin
                        if(zhuangtai[y_cnt-30][ (x_cnt-65)]) begin
                            show_pixel = 1'b1;
                            pixel_color = COLOR_GREEN;
                        end
                    end
                    // 区域3：播放/暂停控制
                    else if(y_cnt >= 30 && y_cnt <= 45 && x_cnt >= 33 && x_cnt <= 64) begin
                        if(play_pause == 1'b0) begin
                            if(kongzhi[y_cnt-30][ (x_cnt-33)+15]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_GREEN;
                            end
                        end else begin
                            if(kongzhi[y_cnt-30][ (x_cnt-33)+79]) begin
                                show_pixel = 1'b1;
                                pixel_color = COLOR_GREEN;
                            end
                        end
                    end
                    // 区域4：音量图标
                    else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 65 && x_cnt <= 128) begin
                        if(yinliang[y_cnt-47][ (x_cnt-65)]) begin
                            show_pixel = 1'b1;
                            pixel_color = COLOR_GREEN;
                        end
                    end
                    // 区域5：音量数字
                    else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 49 && x_cnt <= 64) begin
                        case(volume)
                            3'd0: if(ling[y_cnt-47][(x_cnt-49)]) begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            3'd1: if(yi[y_cnt-47][(x_cnt-49)])   begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            3'd2: if(er[y_cnt-47][(x_cnt-49)])   begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            3'd3: if(san[y_cnt-47][(x_cnt-49)])  begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            3'd4: if(si[y_cnt-47][(x_cnt-49)])   begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            default: show_pixel = 1'b0;
                        endcase
                    end
                    else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 0 && x_cnt <= 1) begin
                        if(ling[y_cnt-47][ (x_cnt)]) show_pixel = 1'b1;
                    end
                    else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 2 && x_cnt <= 3) begin
                        if(yi[y_cnt-47][ (x_cnt-2)]) show_pixel = 1'b1;
                    end
                    else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 4 && x_cnt <= 5) begin
                        if(er[y_cnt-47][ (x_cnt-4)]) show_pixel = 1'b1;
                    end
                    else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 6 && x_cnt <= 7) begin
                        if(san[y_cnt-47][ (x_cnt-6)]) show_pixel = 1'b1;
                    end
                    else if(y_cnt >= 47 && y_cnt <= 62 && x_cnt >= 8 && x_cnt <= 9) begin
                        if(si[y_cnt-47][ (x_cnt-8)]) show_pixel = 1'b1;
                    end
                    // 区域6：歌名显示
                    else if(y_cnt >= 64 && y_cnt <= 79 && x_cnt >= 65 && x_cnt <= 128) begin
                        if(gequ[y_cnt-64][ (x_cnt-65)]) begin
                            show_pixel = 1'b1;
                            pixel_color = COLOR_GREEN;
                        end
                    end
                    // 区域7：歌曲选择
                    else if(y_cnt >= 64 && y_cnt <= 79 && x_cnt >= 1 && x_cnt <= 64) begin
                        case(music_select)
                            2'b01: if(qingtian[y_cnt-64][ (x_cnt-1)]) begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            2'b10: if(xiaoxx[y_cnt-64][ (x_cnt-1)])   begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            2'b11: if(laohu[y_cnt-64][ (x_cnt-1)])    begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            2'b00: if(xiangdd[y_cnt-64][ (x_cnt-1)])  begin show_pixel = 1'b1; pixel_color = COLOR_GREEN; end
                            default: show_pixel = 1'b0;
                        endcase
                    end
                    else if(y_cnt >= 81 && y_cnt <= 92 && x_cnt >= 0 && x_cnt <= 1) begin
                        if(qingtian[y_cnt-81][ (x_cnt)]) show_pixel = 1'b1;
                    end
                    else if(y_cnt >= 81 && y_cnt <= 92 && x_cnt >= 2 && x_cnt <= 3) begin
                        if(xiaoxx[y_cnt-81][ (x_cnt-2)]) show_pixel = 1'b1;
                    end
                    else if(y_cnt >= 81 && y_cnt <= 92 && x_cnt >= 4 && x_cnt <= 5) begin
                        if(laohu[y_cnt-81][ (x_cnt-4)]) show_pixel = 1'b1;
                    end
                    else if(y_cnt >= 81 && y_cnt <= 92 && x_cnt >= 6 && x_cnt <= 7) begin
                        if(xiangdd[y_cnt-81][ (x_cnt-6)]) show_pixel = 1'b1;
                    end
                    // 区域8：控制栏
                    else if(y_cnt >= 107 && y_cnt <= 122 && x_cnt >= 1 && x_cnt <= 128) begin
                        if(kongzhi[y_cnt-107][ (x_cnt-1)]) begin
                            show_pixel = 1'b1;
                            pixel_color = COLOR_BLACK;
                        end
                    end
                    // 区域9：音量进度条
                    else if(y_cnt >= 124 && y_cnt <= 139 && x_cnt >= 1 && x_cnt <= 128) begin
                        if(yljj[y_cnt-124][ (x_cnt-1)]) begin
                            show_pixel = 1'b1;
                            pixel_color = COLOR_BLACK;
                        end
                    end
                    // 区域10：返回按钮
                    else if(y_cnt >= 141 && y_cnt <= 156 && x_cnt >= 1 && x_cnt <= 128) begin
                        if(fanhui[y_cnt-141][ (x_cnt-1)]) begin
                            show_pixel = 1'b1;
                            pixel_color = COLOR_RED;
                        end
                    end

                    // 发送数据
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
                            data_reg <= {1'b1, COLOR_RED[7:0]};
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