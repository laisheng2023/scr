`timescale 1ns / 1ps

module top(
    input clk_27m,
    input rst_n,           // 新增：复位信号（低有效）
    output [3:0] col,
    input [3:0] row,
    input light_do, 
    output beep,
    output cs,
    output dc,
    output scl,
    output sda,
    output rst
);

    wire play_pause;
    wire [1:0] music_select;
    wire [2:0] volume; 
    // 内部复位：外部复位或模块禁用时复位
    wire internal_rst = ~rst_n;
    
    // 屏幕复位输出：当模块被禁用时，屏幕也复位
    assign rst = rst_n;
    
    play_music u_play_music(
        .clk_27m(clk_27m),
        .col(col),
        .row(rst_n ? row : 4'b1111),  // 复位时禁用键盘
        .beep(beep),
        .light_do(light_do), 
        .play_pause(play_pause),
        .music_select_out(music_select),
        .volume_out(volume) 
    );
    
    bofangmoshi u_bofangmoshi(
        .clk_27m(clk_27m),
        .cs(cs),
        .dc(dc),
        .scl(scl),
        .sda(sda),
        .rst(),  // 内部不输出rst
        .music_select(music_select),
        .play_pause(play_pause),
        .volume(volume)
    );

endmodule