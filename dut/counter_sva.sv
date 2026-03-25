module counter2b_sva (
    input       clk,
    input       rst,
    input       set,
    input       cen,
    input       blk,
    input [1:0] cnt
);

    // Default clocking for assertions
    default clocking @(posedge clk);
    endclocking

    // Property: Reset behavior
    // When rst is asserted, the counter must become 0 in the next cycle.
    property p_reset;
        rst |=> (cnt == 2'b00);
    endproperty
    assert_reset: assert property (p_reset);

    // Property: Set behavior
    // When set is asserted (and rst is not), the counter must become 3 in the next cycle.
    property p_set;
        (!rst && set) |=> (cnt == 2'b11);
    endproperty
    assert_set: assert property (p_set);

    // Property: Counting behavior (active low cen)
    // When cen is low (and rst/set are not asserted), the counter must increment.
    property p_count;
        (!rst && !set && !cen) |=> (cnt == ($past(cnt) + 1'b1));
    endproperty
    assert_count: assert property (p_count);

    // Property: Holding behavior
    // When cen is high (and rst/set are not asserted), the counter must hold its value.
    property p_hold;
        (!rst && !set && cen) |=> (cnt == $past(cnt));
    endproperty
    assert_hold: assert property (p_hold);

    // Property: Blink output
    // blk should follow clk (combinational property)
    // Note: Since SVA usually checks at clock edges, checking a combinational 
    // assignment like blk=clk requires care. In formal, we can simple assert it.
    assert_blk: assert property (blk == clk);

    // Coverage items
    cover_full_count: cover property (cnt == 2'b11);
    cover_overflow:   cover property (cnt == 2'b00 && $past(cnt) == 2'b11 && !cen);

endmodule
