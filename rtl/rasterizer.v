// ============================================================================
// Módulo: Rasterizador v2 (Máquina de Estados Sequencial)
// Descrição: Itera sobre os pixels de uma forma (retângulo ou triângulo)
//            e escreve diretamente na memória de vídeo (framebuffer).
//
// FSM: IDLE → CLEAR → DRAW → DONE → IDLE
//   - CLEAR: Preenche todo o framebuffer com a cor de fundo
//   - DRAW:  Itera pela bounding box da forma, testando pertinência
//            e escrevendo pixels válidos na memória
//
// Interface de memória: write_addr, write_data, write_enable
// ============================================================================
module rasterizer (
    input  wire        clk,              // Clock do sistema (ex: 50 MHz)
    input  wire        reset,            // Reset ativo em alto

    // Controle
    input  wire        start,            // Pulso para iniciar a rasterização
    input  wire        enable_clear,     // 1 = faz CLEAR, 0 = pula CLEAR
    input  wire        tipo_forma,       // 1 = Retângulo, 0 = Triângulo
    input  wire [7:0]  cor_preenchimento,// Cor da forma (RRRGGGBB)
    input  wire [7:0]  cor_fundo,        // Cor de fundo (RRRGGGBB)

    // Vértices (Para o retângulo: x0, y0 é a origem; x1, y1 são Largura e Altura)
    input  wire [8:0]  x0, input wire [7:0] y0,
    input  wire [8:0]  x1, input wire [7:0] y1,
    input  wire [8:0]  x2, input wire [7:0] y2,

    // Interface com a Memória (Framebuffer)
    output reg  [16:0] write_addr,       // Endereço de escrita
    output reg  [7:0]  write_data,       // Dado a ser escrito
    output reg         write_enable,     // Habilitação de escrita

    // Status
    output reg         done              // Sinaliza conclusão da rasterização
);

    // =========================================================================
    // Parâmetros da resolução
    // =========================================================================
    localparam SCREEN_WIDTH  = 320;
    localparam SCREEN_HEIGHT = 240;
    localparam TOTAL_PIXELS  = SCREEN_WIDTH * SCREEN_HEIGHT; // 76800

    // =========================================================================
    // Estados da FSM
    // =========================================================================
    localparam STATE_IDLE  = 2'd0;
    localparam STATE_CLEAR = 2'd1;
    localparam STATE_DRAW  = 2'd2;
    localparam STATE_DONE  = 2'd3;

    reg [1:0] state;

    // =========================================================================
    // Contadores internos
    // =========================================================================
    // Contador linear para CLEAR (0 a 76799)
    reg [16:0] clear_counter;

    // Contadores de iteração para DRAW
    reg [8:0] iter_x;   // Coordenada X atual (0 a 319)
    reg [7:0] iter_y;   // Coordenada Y atual (0 a 239)

    // Limites da bounding box para DRAW
    reg [8:0] draw_x_start, draw_x_end;
    reg [7:0] draw_y_start, draw_y_end;

    // =========================================================================
    // Conversão de coordenadas (iter_x, iter_y) → endereço linear
    // Usa a mesma lógica de coord_to_addr: addr = y*320 + x = (y<<8)+(y<<6)+x
    // =========================================================================
    wire [16:0] iter_addr = ({1'b0, iter_y, 8'b0} + {3'b0, iter_y, 6'b0}) + {8'b0, iter_x};

    // =========================================================================
    // Lógica de teste de pertinência ao RETÂNGULO
    // Para retângulo: todos os pixels dentro da bounding box pertencem à forma
    // (a bounding box É o retângulo), então não precisamos de teste adicional
    // =========================================================================
    wire dentro_do_retangulo = 1'b1; // Bounding box = retângulo

    // =========================================================================
    // Lógica de teste de pertinência ao TRIÂNGULO (Equações de Borda)
    // Reutiliza a lógica combinacional original, substituindo pixel_x/pixel_y
    // pelos contadores internos iter_x/iter_y
    // =========================================================================

    // Converter coordenadas para signed com bits extras para evitar overflow
    wire signed [10:0] px = $signed({2'b00, iter_x});
    wire signed [9:0]  py = $signed({2'b00, iter_y});

    wire signed [10:0] sx0 = $signed({2'b00, x0}); wire signed [9:0] sy0 = $signed({2'b00, y0});
    wire signed [10:0] sx1 = $signed({2'b00, x1}); wire signed [9:0] sy1 = $signed({2'b00, y1});
    wire signed [10:0] sx2 = $signed({2'b00, x2}); wire signed [9:0] sy2 = $signed({2'b00, y2});

    // Vetores das arestas (Destino - Origem)
    wire signed [10:0] dx01 = sx1 - sx0; wire signed [9:0] dy01 = sy1 - sy0;
    wire signed [10:0] dx12 = sx2 - sx1; wire signed [9:0] dy12 = sy2 - sy1;
    wire signed [10:0] dx20 = sx0 - sx2; wire signed [9:0] dy20 = sy0 - sy2;

    // Distância do pixel atual a cada vértice
    wire signed [10:0] dxp0 = px - sx0;  wire signed [9:0] dyp0 = py - sy0;
    wire signed [10:0] dxp1 = px - sx1;  wire signed [9:0] dyp1 = py - sy1;
    wire signed [10:0] dxp2 = px - sx2;  wire signed [9:0] dyp2 = py - sy2;

    // Produto Vetorial (Cross Product) de cada borda
    wire signed [21:0] E0 = (dxp0 * dy01) - (dyp0 * dx01);
    wire signed [21:0] E1 = (dxp1 * dy12) - (dyp1 * dx12);
    wire signed [21:0] E2 = (dxp2 * dy20) - (dyp2 * dx20);

    // Pixel pertence ao triângulo se todas as bordas têm o mesmo sinal
    wire dentro_do_triangulo = ((E0 >= 0) && (E1 >= 0) && (E2 >= 0)) ||
                               ((E0 <= 0) && (E1 <= 0) && (E2 <= 0));

    // Seleção da forma
    wire pixel_pertence = (tipo_forma == 1'b1) ? dentro_do_retangulo : dentro_do_triangulo;

    // =========================================================================
    // Cálculo da Bounding Box do Triângulo
    // =========================================================================
    // Funções min/max para 3 valores (sintetizáveis como muxes)
    wire [8:0] min_x_tri = (x0 < x1) ? ((x0 < x2) ? x0 : x2) : ((x1 < x2) ? x1 : x2);
    wire [8:0] max_x_tri = (x0 > x1) ? ((x0 > x2) ? x0 : x2) : ((x1 > x2) ? x1 : x2);
    wire [7:0] min_y_tri = (y0 < y1) ? ((y0 < y2) ? y0 : y2) : ((y1 < y2) ? y1 : y2);
    wire [7:0] max_y_tri = (y0 > y1) ? ((y0 > y2) ? y0 : y2) : ((y1 > y2) ? y1 : y2);

    // =========================================================================
    // Máquina de Estados Principal
    // =========================================================================
    always @(posedge clk) begin
        if (reset) begin
            state        <= STATE_IDLE;
            write_enable <= 1'b0;
            done         <= 1'b0;
            clear_counter <= 17'd0;
            iter_x       <= 9'd0;
            iter_y       <= 8'd0;
        end
        else begin
            case (state)
                // =============================================================
                // IDLE: Aguarda o sinal de start
                // =============================================================
                STATE_IDLE: begin
                    write_enable <= 1'b0;
                    done         <= 1'b0;
                    if (start) begin
                        if (enable_clear) begin
                            state         <= STATE_CLEAR;
                            clear_counter <= 17'd0;
                        end else begin
                            state <= STATE_DRAW;
                            if (tipo_forma == 1'b1) begin
                                iter_x <= x0;
                                iter_y <= y0;
                                draw_x_start <= x0;
                                draw_x_end   <= (x1 == 0) ? x0 : (x0 + x1 - 9'd1);
                                draw_y_start <= y0;
                                draw_y_end   <= (y1 == 0) ? y0 : (y0 + y1 - 8'd1);
                            end else begin
                                iter_x <= min_x_tri;
                                iter_y <= min_y_tri;
                                draw_x_start <= min_x_tri; draw_x_end <= max_x_tri;
                                draw_y_start <= min_y_tri; draw_y_end <= max_y_tri;
                            end
                        end
                    end
                end

                // =============================================================
                // CLEAR: Preenche todo o framebuffer com a cor de fundo
                // Escreve 1 pixel por ciclo de clock
                // 76800 ciclos @ 50MHz = ~1.5ms (bem dentro do tempo de 1 frame)
                // =============================================================
                STATE_CLEAR: begin
                    write_addr   <= clear_counter;
                    write_data   <= cor_fundo;
                    write_enable <= 1'b1;

                    if (clear_counter == TOTAL_PIXELS - 1) begin
                        state         <= STATE_DRAW;
                        write_enable  <= 1'b0;

                        // Calcular limites da bounding box baseado no tipo de forma
                        if (tipo_forma == 1'b1) begin
                            // Retângulo: x0,y0 = origem; x1,y1 = largura,altura
                            draw_x_start <= x0;
                            draw_x_end   <= x0 + x1 - 9'd1;
                            draw_y_start <= y0;
                            draw_y_end   <= y0 + y1 - 8'd1;
                            iter_x       <= x0;
                            iter_y       <= y0;
                        end
                        else begin
                            // Triângulo: bounding box dos 3 vértices
                            draw_x_start <= min_x_tri;
                            draw_x_end   <= max_x_tri;
                            draw_y_start <= min_y_tri;
                            draw_y_end   <= max_y_tri;
                            iter_x       <= min_x_tri;
                            iter_y       <= min_y_tri;
                        end
                    end
                    else begin
                        clear_counter <= clear_counter + 17'd1;
                    end
                end

                // =============================================================
                // DRAW: Itera pela bounding box, testando cada pixel
                // Escreve apenas se o pixel pertence à forma
                // =============================================================
                STATE_DRAW: begin
                    // Endereço do pixel atual
                    write_addr   <= iter_addr;
                    write_data   <= cor_preenchimento;
                    write_enable <= pixel_pertence;

                    // Avançar para o próximo pixel
                    if (iter_x == draw_x_end) begin
                        // Fim da linha — volta ao início X, avança Y
                        if (iter_y == draw_y_end) begin
                            // Fim da bounding box — rasterização concluída
                            state        <= STATE_DONE;
                            write_enable <= 1'b0;
                        end
                        else begin
                            iter_x <= draw_x_start;
                            iter_y <= iter_y + 8'd1;
                        end
                    end
                    else begin
                        iter_x <= iter_x + 9'd1;
                    end
                end

                // =============================================================
                // DONE: Sinaliza conclusão e retorna ao IDLE
                // =============================================================
                STATE_DONE: begin
                    write_enable <= 1'b0;
                    done         <= 1'b1;
                    state        <= STATE_IDLE;
                end

                default: begin
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule