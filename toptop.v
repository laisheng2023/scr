`timescale 1ns / 1ps

module toptop(
    input  clk_27m,
    input  rst_n,
    output [3:0] col,
    input  [3:0] row,
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

    wire [3:0] selected_group;
    wire [2:0] selected_note;
    wire group_selected;
    wire note_selected;
    
    assign rst = rst_n;
    
    keyboard_music u_keyboard_music(
        .clk(clk_27m),
        .col(col),
        .row(rst_n ? row : 4'b1111),
        .beep(beep),
        .selected_group(selected_group),
        .selected_note(selected_note),
        .group_selected(group_selected),
        .note_selected(note_selected),
        .volume(),
        .led_group(led_group),
        .led_flow(led_flow)
    );
    
    lcd_driver u_lcd_driver(
        .clk(clk_27m),
        .group(selected_group),
        .note(selected_note),
        .group_valid(group_selected),
        .note_valid(note_selected),
        .cs(cs),
        .dc(dc),
        .scl(scl),
        .sda(sda),
        .rst()
    );

endmodule