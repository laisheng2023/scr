`timescale 1ns / 1ps

module test_zhuyemian(
    input  clk_27m,
    output cs,
    output dc,
    output scl,
    output sda,
    output rst
);
    zhuyemian u_zhuyemian(
        .clk_27m(clk_27m),
        .cs(cs),
        .dc(dc),
        .scl(scl),
        .sda(sda),
        .rst(rst)
    );
endmodule