// ============================================================================
// Módulo: RAM do Tilemap — "mapa" do fundo (usa altsyncram, Cyclone V)
// ----------------------------------------------------------------------------
// Tilemap: 40 colunas x 30 linhas = 1200 posições.
// Cada posição guarda 8 bits, embora atualmente apenas os 2 LSB sejam usados
// para selecionar um dos 4 tiles disponíveis.
// ============================================================================

module tilemap_ram (
    input  wire        clk,

    // ---- Porta A — leitura/escrita reservada para uso futuro / HPS ----
    input  wire [10:0] addr_a,
    input  wire [7:0]  data_a,
    input  wire        wren_a,
    output wire [7:0]  q_a,

    // ---- Porta B — leitura usada pelo motor de background ----
    input  wire [10:0] addr_b,
    output wire [7:0]  q_b
);

    // =========================================================================
    // Instância do megafunction altsyncram
    // =========================================================================
    altsyncram tilemap_altsyncram (
        .address_a       (addr_a),
        .address_b       (addr_b),
        .clock0          (clk),
        .data_a          (data_a),
        .data_b          (8'b0),
        .wren_a          (wren_a),
        .wren_b          (1'b0),
        .q_a             (q_a),
        .q_b             (q_b),
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

    // =========================================================================
    // Parâmetros do altsyncram
    // =========================================================================
    defparam
        tilemap_altsyncram.address_reg_b =
            "CLOCK0",

        tilemap_altsyncram.clock_enable_input_a =
            "BYPASS",

        tilemap_altsyncram.clock_enable_input_b =
            "BYPASS",

        tilemap_altsyncram.clock_enable_output_a =
            "BYPASS",

        tilemap_altsyncram.clock_enable_output_b =
            "BYPASS",

        tilemap_altsyncram.indata_reg_b =
            "CLOCK0",

        // Arquivo com o conteúdo inicial do tilemap
        tilemap_altsyncram.init_file =
            "data/tilemap.mif",

        // FPGA da DE1-SoC
        tilemap_altsyncram.intended_device_family =
            "Cyclone V",

        tilemap_altsyncram.lpm_type =
            "altsyncram",

        // 40 x 30 = 1200 posições
        tilemap_altsyncram.numwords_a =
            1200,

        tilemap_altsyncram.numwords_b =
            1200,

        // Duas portas independentes
        tilemap_altsyncram.operation_mode =
            "BIDIR_DUAL_PORT",

        tilemap_altsyncram.outdata_aclr_a =
            "NONE",

        tilemap_altsyncram.outdata_aclr_b =
            "NONE",

        // Saída registrada no clock
        tilemap_altsyncram.outdata_reg_a =
            "UNREGISTERED",

        tilemap_altsyncram.outdata_reg_b =
            "UNREGISTERED",

        // Conteúdo inicial definido pelo .mif
        tilemap_altsyncram.power_up_uninitialized =
            "FALSE",

        tilemap_altsyncram.read_during_write_mode_mixed_ports =
            "DONT_CARE",

        tilemap_altsyncram.read_during_write_mode_port_a =
            "DONT_CARE",

        tilemap_altsyncram.read_during_write_mode_port_b =
            "DONT_CARE",

        // Endereço: 11 bits → 2048 posições possíveis
        tilemap_altsyncram.widthad_a =
            11,

        tilemap_altsyncram.widthad_b =
            11,

        // Dado: 8 bits por posição
        tilemap_altsyncram.width_a =
            8,

        tilemap_altsyncram.width_b =
            8,

        tilemap_altsyncram.width_byteena_a =
            1,

        tilemap_altsyncram.width_byteena_b =
            1,

        tilemap_altsyncram.wrcontrol_wraddress_reg_b =
            "CLOCK0";

endmodule