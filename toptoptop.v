`timescale 1ns / 1ps

module page_manager(
    input  clk_27m,
    output [3:0] col,
    input  [3:0] row,
    input  light_do, 
    output beep,
    output cs,
    output dc,
    output scl,
    output sda,
    output rst,
    
    // ========== LED输出 ==========
    output [3:0] led_group,
    output [7:0] led_flow
);

    // ========== 页面选择 ==========
    reg [1:0] page_select;
    localparam PAGE_MAIN   = 2'b00;
    localparam PAGE_TOP    = 2'b01;
    localparam PAGE_TOPTOP = 2'b10;
    
    // ========== 键盘扫描 ==========
    reg [1:0] scan_cnt;
    reg [19:0] delay_cnt;
    reg [3:0] row_reg;
    reg [3:0] col_scan;
    reg [3:0] raw_key;
    reg key_detected, key_detected_last;
    
    // ========== 页面切换延迟 ==========
    reg [24:0] switch_delay;
    reg switching;
    reg [1:0] target_page;
    
    // ========== 子模块的col输出 ==========
    wire [3:0] col_top;
    wire [3:0] col_toptop;
    
    // ========== 子模块的屏幕输出 ==========
    wire cs_top, dc_top, scl_top, sda_top;
    wire cs_toptop, dc_toptop, scl_toptop, sda_toptop;
    
    // ========== 蜂鸣器输出 ==========
    wire beep_top, beep_toptop;
    
    // ========== 主页面输出 ==========
    wire cs_main, dc_main, scl_main, sda_main, rst_main;
    
    // ========== LED信号 ==========
    wire [3:0] led_group_toptop;
    wire [7:0] led_flow_toptop;
    
    // ========== 子模块复位 ==========
    wire rst_top_n = (page_select == PAGE_TOP);
    wire rst_toptop_n = (page_select == PAGE_TOPTOP);
    
    // ========== 键盘扫描 ==========
    always @(posedge clk_27m) begin
        delay_cnt <= delay_cnt + 1;
        if(delay_cnt == 20'd270000) begin
            delay_cnt <= 0;
            scan_cnt <= scan_cnt + 1;
            case(scan_cnt)
                2'd0: col_scan <= 4'b1110;
                2'd1: col_scan <= 4'b1101;
                2'd2: col_scan <= 4'b1011;
                2'd3: col_scan <= 4'b0111;
            endcase
        end
    end
    
    // 完整的按键解码
    always @(posedge clk_27m) begin
        row_reg <= row;
        
        case({scan_cnt, row_reg})
            {2'd1, 4'b0111}: raw_key <= 4'b1010;  // A键
            {2'd1, 4'b1011}: raw_key <= 4'b1011;  // B键
            {2'd3, 4'b1110}: raw_key <= 4'b1111;  // F键
            default: raw_key <= 4'b0000;
        endcase
        
        key_detected <= (row_reg != 4'b1111);
    end
    
    // ========== 页面切换（带延迟）==========
    initial begin
        page_select = PAGE_MAIN;
        target_page = PAGE_MAIN;
        switching = 1'b0;
        switch_delay = 25'd0;
    end
    
    always @(posedge clk_27m) begin
        if(switching) begin
            if(switch_delay < 25'd13500000) begin
                switch_delay <= switch_delay + 1;
            end else begin
                page_select <= target_page;
                switching <= 1'b0;
                switch_delay <= 25'd0;
            end
        end
        
        if(key_detected && !key_detected_last && !switching) begin
            if(raw_key == 4'b1111) begin
                if(page_select != PAGE_MAIN) begin
                    target_page <= PAGE_MAIN;
                    switching <= 1'b1;
                end
            end
            else if(page_select == PAGE_MAIN) begin
                case(raw_key)
                    4'b1010: begin
                        target_page <= PAGE_TOP;
                        switching <= 1'b1;
                    end
                    4'b1011: begin
                        target_page <= PAGE_TOPTOP;
                        switching <= 1'b1;
                    end
                    default: ;
                endcase
            end
        end
        key_detected_last <= key_detected;
    end
    
    // ========== 给子模块的row信号 ==========
    reg post_mask;
    reg [24:0] post_mask_cnt;
    
    always @(posedge clk_27m) begin
        if(!switching && (page_select != target_page)) begin
            post_mask <= 1'b1;
            post_mask_cnt <= 25'd0;
        end else if(post_mask) begin
            if(post_mask_cnt < 25'd13500000) begin
                post_mask_cnt <= post_mask_cnt + 1;
            end else begin
                post_mask <= 1'b0;
            end
        end
    end
    
    wire [3:0] row_to_top    = (switching || post_mask) ? 4'b1111 : row;
    wire [3:0] row_to_toptop = (switching || post_mask) ? 4'b1111 : row;
    
    // ========== 实例化 ==========
    zhuyemian u_zhuyemian(
        .clk_27m(clk_27m),
        .cs(cs_main),
        .dc(dc_main),
        .scl(scl_main),
        .sda(sda_main),
        .rst(rst_main)
    );
    
    top u_top(
        .clk_27m(clk_27m),
        .rst_n(rst_top_n),
        .col(col_top),
        .row(row_to_top),
        .beep(beep_top),
        .light_do(light_do), 
        .cs(cs_top),
        .dc(dc_top),
        .scl(scl_top),
        .sda(sda_top),
        .rst()
    );
    
    toptop u_toptop(
        .clk_27m(clk_27m),
        .rst_n(rst_toptop_n),
        .col(col_toptop),
        .row(row_to_toptop),
        .beep(beep_toptop),
        .cs(cs_toptop),
        .dc(dc_toptop),
        .scl(scl_toptop),
        .sda(sda_toptop),
        .rst(),
        .led_group(led_group_toptop),
        .led_flow(led_flow_toptop)
    );
    
    // ========== 输出选择 ==========
    assign col = (page_select == PAGE_MAIN)   ? col_scan   :
                 (page_select == PAGE_TOP)    ? col_top    :
                 (page_select == PAGE_TOPTOP) ? col_toptop : 4'b1111;
    
    assign cs  = (page_select == PAGE_MAIN)   ? cs_main   :
                 (page_select == PAGE_TOP)    ? cs_top    :
                 (page_select == PAGE_TOPTOP) ? cs_toptop : 1'b1;
    assign dc  = (page_select == PAGE_MAIN)   ? dc_main   :
                 (page_select == PAGE_TOP)    ? dc_top    :
                 (page_select == PAGE_TOPTOP) ? dc_toptop : 1'b1;
    assign scl = (page_select == PAGE_MAIN)   ? scl_main  :
                 (page_select == PAGE_TOP)    ? scl_top   :
                 (page_select == PAGE_TOPTOP) ? scl_toptop : 1'b1;
    assign sda = (page_select == PAGE_MAIN)   ? sda_main  :
                 (page_select == PAGE_TOP)    ? sda_top   :
                 (page_select == PAGE_TOPTOP) ? sda_toptop : 1'b1;
    assign rst = (page_select == PAGE_MAIN)   ? rst_main  : 1'b1;
    assign beep = (page_select == PAGE_TOP)    ? beep_top    :
                  (page_select == PAGE_TOPTOP) ? beep_toptop : 1'b0;
    
    // ========== LED输出选择 ==========
    // 只有在弹奏页面（PAGE_TOPTOP）才输出LED效果
    assign led_group = (page_select == PAGE_TOPTOP) ? led_group_toptop : 4'b0000;
    assign led_flow = (page_select == PAGE_TOPTOP) ? led_flow_toptop : 8'b0000_0000;

endmodule