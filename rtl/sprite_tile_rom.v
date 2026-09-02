// ============================================================================
// Módulo: ROM de Tiles para Sprites — versão com altsyncram (Cyclone V)
// ----------------------------------------------------------------------------
// Memória: 2048 palavras de 8 bits.
// Cada palavra = 1 pixel de cor RRRGGGBB.
// Endereço: {tile_index[4:0], row[2:0], col[2:0]}
//           → 32 tiles de 8x8 pixels, cada pixel com cor própria.
//
// Um sprite 16x16 usa 4 tiles consecutivos (grade 2x2):
//   tile_index+0 = top-left, +1 = top-right,
//   +2 = bottom-left, +3 = bottom-right
// ============================================================================

module sprite_tile_rom (
    input  wire        clk,
    input  wire [10:0] addr,       // 11 bits → 2048 posições
    output wire [7:0]  data        // 8 bits → cor RRRGGGBB
);

    // Saída da memória
    wire [7:0] q_out;

    // =========================================================================
    // Instância do megafunction altsyncram (single-port ROM)
    // =========================================================================
    altsyncram sprite_tiles_altsyncram (
        .address_a       (addr),
        .clock0          (clk),
        .q_a             (q_out),

        // Portas não usadas (single-port read-only)
        .data_a          (8'b0),
        .wren_a          (1'b0),
        .aclr0           (1'b0),
        .aclr1           (1'b0),
        .address_b       (1'b1),
        .addressstall_a  (1'b0),
        .addressstall_b  (1'b0),
        .byteena_a       (1'b1),
        .byteena_b       (1'b1),
        .clock1          (1'b1),
        .clocken0        (1'b1),
        .clocken1        (1'b1),
        .clocken2        (1'b1),
        .clocken3        (1'b1),
        .data_b          (1'b1),
        .eccstatus       (),
        .q_b             (),
        .rden_a          (1'b1),
        .rden_b          (1'b1),
        .wren_b          (1'b0)
    );

    // -------------------------------------------------------------------------
    // Parâmetros do altsyncram
    // -------------------------------------------------------------------------
    defparam
        sprite_tiles_altsyncram.clock_enable_input_a =
            "BYPASS",

        sprite_tiles_altsyncram.clock_enable_output_a =
            "BYPASS",

        // Arquivo com o conteúdo inicial da ROM
        sprite_tiles_altsyncram.init_file =
            "data/sprite_tiles.mif",

        // FPGA da DE1-SoC
        sprite_tiles_altsyncram.intended_device_family =
            "Cyclone V",

        sprite_tiles_altsyncram.lpm_type =
            "altsyncram",

        // 32 tiles × 64 pixels = 2048 posições
        sprite_tiles_altsyncram.numwords_a =
            2048,

        // Porta simples (só leitura)
        sprite_tiles_altsyncram.operation_mode =
            "ROM",

        sprite_tiles_altsyncram.outdata_aclr_a =
            "NONE",

        // Saída registrada no clock (1 ciclo de latência)
        sprite_tiles_altsyncram.outdata_reg_a =
            "CLOCK0",

        // Conteúdo inicial definido pelo .mif
        sprite_tiles_altsyncram.power_up_uninitialized =
            "FALSE",

        // Endereço: 11 bits → 2048 posições
        sprite_tiles_altsyncram.widthad_a =
            11,

        // Dado: 8 bits → cor RRRGGGBB
        sprite_tiles_altsyncram.width_a =
            8,

        sprite_tiles_altsyncram.width_byteena_a =
            1;

    assign data = q_out;

endmodule
