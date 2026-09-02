/*
 * SPRITE ENGINE - Motor de Sprites com Pipeline
 * ==============================================
 * Gerencia 32 sprites de 16x16 pixels
 * (compostos por 4 tiles de 8x8).
 *
 * Implementa:
 *  - Espelhamento horizontal (H)
 *  - Espelhamento vertical (V)
 *  - Prioridade
 *  - Transparência
 *
 * Arquitetura:
 *  - Estágio 1: cálculo combinacional da cobertura e endereço
 *  - Estágio 2: pipeline de 1 ciclo para casar com a ROM
 *
 * Transparência:
 *  - Cor 8'h00 = transparente
 *
 * Espelhamento:
 *
 * Normal:
 *
 *   Tile 0 | Tile 1
 *   --------+-------
 *   Tile 2 | Tile 3
 *
 * Horizontal:
 *
 *   Tile 1 | Tile 0
 *   --------+-------
 *   Tile 3 | Tile 2
 *
 * Vertical:
 *
 *   Tile 2 | Tile 3
 *   --------+-------
 *   Tile 0 | Tile 1
 *
 * Horizontal + Vertical:
 *
 *   Tile 3 | Tile 2
 *   --------+-------
 *   Tile 1 | Tile 0
 */

module sprite_engine (
    input wire clk,
    input wire reset,

    // ============================================================
    // COORDENADAS DO PIXEL
    // ============================================================

    input wire [8:0] pixel_x,      // 0..319
    input wire [7:0] pixel_y,      // 0..239


    // ============================================================
    // INTERFACE DE ESCRITA DOS ATRIBUTOS
    //
    // sprite_attr:
    //
    // [31]    = enable
    // [30:29] = prioridade
    // [28]    = mirror horizontal
    // [27]    = mirror vertical
    // [26]    = palette
    // [25:17] = posição X
    // [16]    = reservado
    // [15:8]  = tile base
    // [7:0]   = posição Y
    // ============================================================

    input wire [31:0] sprite_attr,
    input wire        wr_sprite,
    input wire [4:0]  sprite_id,


    // ============================================================
    // ROM DOS TILES
    // ============================================================

    output reg [10:0] tile_addr,
    input wire [7:0]  tile_data,


    // ============================================================
    // SAÍDAS
    // ============================================================

    output reg [7:0] sprite_color,
    output reg       sprite_hit_out
);


    // ============================================================
    // DEFINIÇÕES
    // ============================================================

    localparam SPRITE_COUNT  = 32;
    localparam SPRITE_WIDTH  = 16;
    localparam SPRITE_HEIGHT = 16;


    // ============================================================
    // ATRIBUTOS DOS 32 SPRITES
    // ============================================================

    reg [8:0] sprite_x      [0:SPRITE_COUNT-1];
    reg [7:0] sprite_y      [0:SPRITE_COUNT-1];
    reg [7:0] sprite_tile   [0:SPRITE_COUNT-1];

    reg [1:0] sprite_prio   [0:SPRITE_COUNT-1];

    reg       sprite_enable [0:SPRITE_COUNT-1];

    reg       sprite_mirror_h [0:SPRITE_COUNT-1];
    reg       sprite_mirror_v [0:SPRITE_COUNT-1];


    // ============================================================
    // VARIÁVEIS DO ESTÁGIO 1
    // ============================================================

    reg        comb_hit;
    reg [4:0]  comb_hit_id;
    reg [1:0]  comb_hit_prio;
    reg [10:0] comb_tile_addr;


    // ============================================================
    // VARIÁVEIS TEMPORÁRIAS
    // ============================================================

    reg [8:0] rel_x;
    reg [7:0] rel_y;

    // Coordenadas depois do espelhamento
    reg [8:0] mirror_x;
    reg [7:0] mirror_y;

    // Tile dentro do sprite 16x16
    reg [1:0] t_offset;

    // Pixel dentro do tile 8x8
    reg [2:0] t_pixel_x;
    reg [2:0] t_pixel_y;

    integer i;


    // ============================================================
    // ESTÁGIO 2 — REGISTRADORES DE PIPELINE
    // ============================================================

    reg hit_d1;
    reg [1:0] prio_d1;


    // ============================================================
    // ESCRITA DOS ATRIBUTOS DOS SPRITES
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin : reset_sprites

            integer j;

            for (j = 0; j < SPRITE_COUNT; j = j + 1) begin

                sprite_enable[j]   <= 1'b0;

                sprite_x[j]        <= 9'b0;
                sprite_y[j]        <= 8'b0;

                sprite_tile[j]     <= 8'b0;

                sprite_prio[j]     <= 2'b0;

                sprite_mirror_h[j] <= 1'b0;
                sprite_mirror_v[j] <= 1'b0;

            end

        end

        else if (wr_sprite) begin

            sprite_enable[sprite_id]
                <= sprite_attr[31];

            sprite_prio[sprite_id]
                <= sprite_attr[30:29];

            sprite_mirror_h[sprite_id]
                <= sprite_attr[28];

            sprite_mirror_v[sprite_id]
                <= sprite_attr[27];

            sprite_x[sprite_id]
                <= sprite_attr[25:17];

            sprite_tile[sprite_id]
                <= sprite_attr[15:8];

            sprite_y[sprite_id]
                <= sprite_attr[7:0];

        end

    end


    // ============================================================
    // ESTÁGIO 1
    //
    // Procura qual sprite cobre o pixel atual.
    //
    // Primeiro verificamos os limites.
    // Só depois fazemos a subtração.
    // ============================================================

    always @* begin

        comb_hit       = 1'b0;
        comb_hit_id    = 5'b0;
        comb_hit_prio  = 2'b0;
        comb_tile_addr = 11'b0;

        // Valores padrão das variáveis temporárias
        rel_x     = 9'b0;
        rel_y     = 8'b0;

        mirror_x  = 9'b0;
        mirror_y  = 8'b0;

        t_offset  = 2'b0;

        t_pixel_x = 3'b0;
        t_pixel_y = 3'b0;


        // ========================================================
        // VARRE OS 32 SPRITES
        // ========================================================

        for (i = 0; i < SPRITE_COUNT; i = i + 1) begin

            if (sprite_enable[i]) begin

                // =================================================
                // VERIFICA SE O PIXEL ESTÁ DENTRO DO SPRITE
                // =================================================

                if ((pixel_x >= sprite_x[i]) &&
                    (pixel_x < sprite_x[i] + SPRITE_WIDTH) &&
                    (pixel_y >= sprite_y[i]) &&
                    (pixel_y < sprite_y[i] + SPRITE_HEIGHT)) begin


                    // =============================================
                    // COORDENADA RELATIVA NORMAL
                    // =============================================

                    rel_x = pixel_x - sprite_x[i];
                    rel_y = pixel_y - sprite_y[i];


                    // =============================================
                    // ESPELHAMENTO DO SPRITE INTEIRO 16x16
                    //
                    // Horizontal:
                    //   0  -> 15
                    //   1  -> 14
                    //   ...
                    //   15 -> 0
                    //
                    // Vertical:
                    //   0  -> 15
                    //   1  -> 14
                    //   ...
                    //   15 -> 0
                    // =============================================

                    if (sprite_mirror_h[i])
                        mirror_x = 9'd15 - rel_x;
                    else
                        mirror_x = rel_x;


                    if (sprite_mirror_v[i])
                        mirror_y = 8'd15 - rel_y;
                    else
                        mirror_y = rel_y;


                    // =============================================
                    // SELEÇÃO DO TILE
                    //
                    // mirror_x[3]:
                    //   0 = lado esquerdo
                    //   1 = lado direito
                    //
                    // mirror_y[3]:
                    //   0 = parte superior
                    //   1 = parte inferior
                    //
                    // Isso faz o espelhamento dos 4 tiles também.
                    // =============================================

                    t_offset = {
                        mirror_y[3],
                        mirror_x[3]
                    };


                    // =============================================
                    // PIXEL DENTRO DO TILE 8x8
                    // =============================================

                    t_pixel_x = mirror_x[2:0];
                    t_pixel_y = mirror_y[2:0];


                    // =============================================
                    // RESOLUÇÃO DE PRIORIDADE
                    //
                    // Maior prioridade vence.
                    // Em empate, maior ID vence.
                    // =============================================

                    if (!comb_hit ||
                        sprite_prio[i] > comb_hit_prio ||
                        ((sprite_prio[i] == comb_hit_prio) &&
                         (i[4:0] > comb_hit_id))) begin


                        comb_hit      = 1'b1;

                        comb_hit_id   = i[4:0];

                        comb_hit_prio = sprite_prio[i];


                        // =========================================
                        // ENDEREÇO DO PIXEL NA ROM
                        //
                        // Cada sprite possui 4 tiles:
                        //
                        // base + 0 = Tile superior esquerdo
                        // base + 1 = Tile superior direito
                        // base + 2 = Tile inferior esquerdo
                        // base + 3 = Tile inferior direito
                        // =========================================

                        comb_tile_addr = {
                            sprite_tile[i][4:0] +
                            {3'b000, t_offset},

                            t_pixel_y,
                            t_pixel_x
                        };

                    end

                end

            end

        end

    end


    // ============================================================
    // ENDEREÇO DA ROM
    // ============================================================

    always @* begin
        tile_addr = comb_tile_addr;
    end


    // ============================================================
    // ESTÁGIO 2 — PIPELINE
    //
    // A ROM possui 1 ciclo de latência.
    // Portanto, atrasamos o hit em 1 ciclo.
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            hit_d1  <= 1'b0;
            prio_d1 <= 2'b0;

        end

        else begin

            hit_d1  <= comb_hit;
            prio_d1 <= comb_hit_prio;

        end

    end


    // ============================================================
    // SAÍDA DO SPRITE
    // ============================================================

    always @* begin

        sprite_hit_out = hit_d1;

        if (hit_d1)
            sprite_color = tile_data;
        else
            sprite_color = 8'h00;

    end

endmodule

