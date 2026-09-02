module tile_patterns_rom (
    input  wire        clk,

    // ---- Porta A — usada pelo motor de background ----
    input  wire [7:0]  tile_id_a,
    input  wire [2:0]  row_a,
    input  wire [2:0]  col_a,
    output wire [7:0]  pixel_a, // Agora retorna 8-bits direto!

    // ---- Porta B — reservada para o futuro motor de sprites ----
    input  wire [7:0]  tile_id_b,
    input  wire [2:0]  row_b,
    input  wire [2:0]  col_b,
    output wire [7:0]  pixel_b
);

    // Endereço de 14 bits (Tile ID + Linha + Coluna)
    // Suporta 256 tiles x 8 linhas x 8 colunas = 16384 bytes
    wire [13:0] addr_a = {tile_id_a, row_a, col_a};
    wire [13:0] addr_b = {tile_id_b, row_b, col_b};

    altsyncram tile_patterns_altsyncram (
        .address_a       (addr_a),
        .address_b       (addr_b),
        .clock0          (clk),
        .data_a          (8'b0),
        .data_b          (8'b0),
        .wren_a          (1'b0),
        .wren_b          (1'b0),
        .q_a             (pixel_a), // O dado já é o pixel final de 8 bits
        .q_b             (pixel_b),
        .aclr0           (1'b0),
        .aclr1           (1'b0),
        .addressstall_a  (1'b0),
        .addressstall_b  (1'b0),
        .byteena_a       (1'b1),
        .byteena_b       (1'b1),
        .clock1          (1'b1),
        .clocken0        (1'b1),
        .clocken1        (1'b1),
        .clocken2        (1'b1),
        .clocken3        (1'b1),
        .eccstatus       (),
        .rden_a          (1'b1),
        .rden_b          (1'b1)
    );

    defparam
        tile_patterns_altsyncram.address_reg_b = "CLOCK0",
        tile_patterns_altsyncram.clock_enable_input_a = "BYPASS",
        tile_patterns_altsyncram.clock_enable_input_b = "BYPASS",
        tile_patterns_altsyncram.clock_enable_output_a = "BYPASS",
        tile_patterns_altsyncram.clock_enable_output_b = "BYPASS",
        tile_patterns_altsyncram.indata_reg_b = "CLOCK0",
        tile_patterns_altsyncram.init_file = "data/tile_patterns.mif",
        tile_patterns_altsyncram.intended_device_family = "Cyclone V",
        tile_patterns_altsyncram.lpm_type = "altsyncram",
        tile_patterns_altsyncram.numwords_a = 16384,
        tile_patterns_altsyncram.numwords_b = 16384,
        tile_patterns_altsyncram.operation_mode = "BIDIR_DUAL_PORT",
        tile_patterns_altsyncram.outdata_aclr_a = "NONE",
        tile_patterns_altsyncram.outdata_aclr_b = "NONE",
        tile_patterns_altsyncram.outdata_reg_a = "UNREGISTERED",
        tile_patterns_altsyncram.outdata_reg_b = "UNREGISTERED",
        tile_patterns_altsyncram.power_up_uninitialized = "FALSE",
        tile_patterns_altsyncram.read_during_write_mode_mixed_ports = "DONT_CARE",
        tile_patterns_altsyncram.read_during_write_mode_port_a = "DONT_CARE",
        tile_patterns_altsyncram.read_during_write_mode_port_b = "DONT_CARE",
        tile_patterns_altsyncram.widthad_a = 14,
        tile_patterns_altsyncram.widthad_b = 14,
        tile_patterns_altsyncram.width_a = 8,
        tile_patterns_altsyncram.width_b = 8,
        tile_patterns_altsyncram.width_byteena_a = 1,
        tile_patterns_altsyncram.width_byteena_b = 1,
        tile_patterns_altsyncram.wrcontrol_wraddress_reg_b = "CLOCK0";

endmodule
