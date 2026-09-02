// ============================================================================
// Módulo: Conversor de Coordenadas (2D → Endereço Linear)
// Descrição: Converte coordenadas (x, y) em um endereço de memória linear.
//            Fórmula: addr = y * 320 + x
//            Otimização: 320 = 256 + 64 = (y << 8) + (y << 6) // ?? kkk
//            Não consome DSP blocks — usa apenas deslocamento de bits.
// ============================================================================
module coord_to_addr (
    input  wire [8:0]  x,      // Coordenada X (0 a 319)
    input  wire [7:0]  y,      // Coordenada Y (0 a 239)
    output wire [16:0] addr    // Endereço linear (0 a 76799)
);

    // y * 320 = y * 256 + y * 64 = (y << 8) + (y << 6)
    // Expandimos y para 17 bits antes do shift para evitar truncamento
    wire [16:0] y_shift_8 = {1'b0, y, 8'b0};         // y << 8 (y * 256)
    wire [16:0] y_shift_6 = {3'b0, y, 6'b0};         // y << 6 (y * 64)
    wire [16:0] x_ext     = {8'b0, x};                // x estendido para 17 bits

    assign addr = y_shift_8 + y_shift_6 + x_ext;

endmodule
