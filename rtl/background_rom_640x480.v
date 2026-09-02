module background_rom_640x480 (
    input  wire        clk,
    input  wire [18:0] addr,
    output wire [7:0]  data
);

    altsyncram rom (
        .address_a(addr),
        .clock0(clk),
        .data_a(8'd0),
        .wren_a(1'b0),
        .q_a(data),
        .aclr0(1'b0),
        .addressstall_a(1'b0),
        .clocken0(1'b1),
        .rden_a(1'b1)
    );

    defparam
        rom.init_file = "data/forest_background_640x480.mif",
        rom.intended_device_family = "Cyclone V",
        rom.lpm_type = "altsyncram",

        rom.operation_mode = "ROM",

        rom.numwords_a = 307200,
        rom.widthad_a = 19,
        rom.width_a = 8,

        rom.outdata_aclr_a = "NONE",
        rom.outdata_reg_a = "UNREGISTERED",

        rom.power_up_uninitialized = "FALSE";

endmodule
