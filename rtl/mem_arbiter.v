// ============================================================================
// Módulo: Arbitrador de Memória
// Descrição: Controla o acesso à porta de escrita do framebuffer.
//            Possui 2 canais ativos com prioridade fixa:
//              ch0 (rasterizer) > ch1 (background)
//            Preparado para expansão futura (sprites).
//
// Política: Prioridade fixa — Canal 0 sempre tem preferência.
//           Se ch0 e ch1 pedirem escrita no mesmo ciclo, ch0 ganha
//           e o pixel do ch1 é descartado (na prática isso raramente
//           acontece porque o rasterizer só escreve durante CLEAR/DRAW).
// ============================================================================
module mem_arbiter (
    input  wire        clk,

    // Canal 0 — Rasterizador (maior prioridade)
    input  wire [16:0] ch0_addr,
    input  wire [7:0]  ch0_data,
    input  wire        ch0_we,

    // Canal 1 — Background Engine
    input  wire [16:0] ch1_addr,
    input  wire [7:0]  ch1_data,
    input  wire        ch1_we,

    // (Futuro) Canal 2 — Sprites
    // input  wire [16:0] ch2_addr,
    // input  wire [7:0]  ch2_data,
    // input  wire        ch2_we,

    // Saída para o Framebuffer (porta de escrita)
    output reg  [16:0] mem_addr,
    output reg  [7:0]  mem_data,
    output reg         mem_we
);

    // Arbitragem com prioridade fixa
    always @(posedge clk) begin
        if (ch0_we) begin
            mem_addr <= ch0_addr;
            mem_data <= ch0_data;
            mem_we   <= 1'b1;
        end
        else if (ch1_we) begin
            mem_addr <= ch1_addr;
            mem_data <= ch1_data;
            mem_we   <= 1'b1;
        end
        // Futuro: else if (ch2_we) begin ... end
        else begin
            mem_we <= 1'b0;
        end
    end

endmodule
