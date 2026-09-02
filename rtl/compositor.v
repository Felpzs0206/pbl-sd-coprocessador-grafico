module compositor (
    input wire clk,
    input wire reset,

    input wire [7:0] bg_color,
    input wire [7:0] fb_color,

    input wire [7:0] sprite_color,
    input wire sprite_hit,

    output reg [7:0] final_color
);

    localparam COLOR_TRANSPARENT = 8'h00;

    // ============================================================
    // COMPOSIÇÃO
    //
    // Os três caminhos já chegam alinhados:
    //
    // Background  = 1 ciclo
    // Framebuffer  = 1 ciclo
    // Sprite       = 1 ciclo
    //
    // NÃO adicionar outro registrador aqui.
    // ============================================================

    wire [7:0] composed_idx;

    assign composed_idx =
        (sprite_hit && (sprite_color != COLOR_TRANSPARENT)) ?
            sprite_color :

        (fb_color != COLOR_TRANSPARENT) ?
            fb_color :

            bg_color;


    // ============================================================
    // PALETA
    //
    // A paleta adiciona 1 ciclo.
    // ============================================================

    reg [7:0] palette_ram [0:255];

    initial begin
        $readmemh("data/palette.hex", palette_ram);
    end


    always @(posedge clk) begin

        if (reset)
            final_color <= 8'h00;

        else
            final_color <= palette_ram[composed_idx];

    end

endmodule