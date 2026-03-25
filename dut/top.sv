// Bind assertions to the DUT module
bind counter2b counter2b_sva u_sva (
    .clk(clk),
    .rst(rst),
    .set(set),
    .cen(cen),
    .blk(blk),
    .cnt(cnt)
);
