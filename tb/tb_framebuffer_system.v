// ============================================================================
// Testbench: tb_framebuffer_system
// Descrição: Simula o sistema rasterizer + mem_arbiter + framebuffer
//            sem o VGA. Após a rasterização, exporta o conteúdo do
//            framebuffer como imagem PPM para visualização no PC.
//
// ============================================================================
`timescale 1ns / 1ps

module tb_framebuffer_system;

    // Sinais do testbench
    reg        clk_50;
    reg        reset;
    reg        start;
    reg        tipo_forma;
    reg [7:0]  cor_preenchimento;
    reg [7:0]  cor_fundo;
    reg [8:0]  x0, x1, x2;
    reg [7:0]  y0, y1, y2;

    // Saídas do rasterizer
    wire [16:0] rast_write_addr;
    wire [7:0]  rast_write_data;
    wire        rast_write_enable;
    wire        rast_done;

    // Saídas do arbitrador
    wire [16:0] fb_write_addr;
    wire [7:0]  fb_write_data;
    wire        fb_write_enable;

    // Clock de 50 MHz (período = 20 ns)
    initial clk_50 = 0;
    always #10 clk_50 = ~clk_50;

    // Instância do Rasterizador
    rasterizer rast_inst (
        .clk(clk_50),
        .reset(reset),
        .start(start),
        .tipo_forma(tipo_forma),
        .cor_preenchimento(cor_preenchimento),
        .cor_fundo(cor_fundo),
        .x0(x0), .y0(y0),
        .x1(x1), .y1(y1),
        .x2(x2), .y2(y2),
        .write_addr(rast_write_addr),
        .write_data(rast_write_data),
        .write_enable(rast_write_enable),
        .done(rast_done)
    );

    // Instância do Arbitrador
    mem_arbiter arb_inst (
        .clk(clk_50),
        .ch0_addr(rast_write_addr),
        .ch0_data(rast_write_data),
        .ch0_we(rast_write_enable),
        .mem_addr(fb_write_addr),
        .mem_data(fb_write_data),
        .mem_we(fb_write_enable)
    );

    // Instância do Framebuffer
    // Para leitura no testbench, usamos a porta B com o mesmo clock
    reg  [16:0] tb_read_addr;
    wire [7:0]  tb_read_data;

    framebuffer fb_inst (
        .clk_w(clk_50),
        .write_addr(fb_write_addr),
        .write_data(fb_write_data),
        .write_enable(fb_write_enable),
        .clk_r(clk_50),
        .read_addr(tb_read_addr),
        .read_data(tb_read_data)
    );

    // Variáveis para exportação da imagem
    integer ppm_file;
    integer i;
    reg [7:0] pixel_val;
    reg [7:0] r, g, b;

    // Sequência de Teste
    initial begin
        // --- Inicialização ---
        reset            = 1;
        start            = 0;
        tipo_forma       = 0;          // 0 = Triângulo
        cor_preenchimento = 8'b000_111_00; // Verde
        cor_fundo        = 8'b000_000_11; // Azul

        // Vértices do triângulo (mesmos do test_top)
        x0 = 9'd160; y0 = 8'd50;      // Topo
        x1 = 9'd210; y1 = 8'd150;     // Inferior direito
        x2 = 9'd110; y2 = 8'd150;     // Inferior esquerdo

        tb_read_addr = 0;

        // --- Reset ---
        #100;
        reset = 0;
        #20;

        // --- Start ---
        $display("=== Iniciando rasterizacao ===");
        $display("Forma: %s", tipo_forma ? "Retangulo" : "Triangulo");
        $display("Cor forma: %b, Cor fundo: %b", cor_preenchimento, cor_fundo);
        start = 1;
        #20;
        start = 0;

        // --- Aguardar conclusão ---
        $display("Aguardando conclusao...");
        wait(rast_done == 1);
        #40; // Espera estabilizar

        $display("=== Rasterizacao concluida! ===");
        $display("Exportando framebuffer para PPM...");

        // --- Exportar framebuffer como PPM ---
        ppm_file = $fopen("framebuffer_output.ppm", "w");
        if (ppm_file == 0) begin
            $display("ERRO: Nao foi possivel criar o arquivo PPM!");
            $finish;
        end

        // Cabeçalho PPM (formato P3 = ASCII)
        $fwrite(ppm_file, "P3\n");
        $fwrite(ppm_file, "320 240\n");
        $fwrite(ppm_file, "255\n");

        // Ler cada pixel do framebuffer e converter RRRGGGBB para RGB 8-bit
        for (i = 0; i < 76800; i = i + 1) begin
            tb_read_addr = i;
            #20; // 1 ciclo para a leitura síncrona
            #20; // +1 ciclo de latência da porta B

            pixel_val = tb_read_data;

            // Converter RRRGGGBB (3-3-2) para RGB (8-8-8)
            // R: bits [7:5] → expandir 3 bits para 8 bits
            // G: bits [4:2] → expandir 3 bits para 8 bits
            // B: bits [1:0] → expandir 2 bits para 8 bits
            r = {pixel_val[7:5], pixel_val[7:5], pixel_val[7:6]};
            g = {pixel_val[4:2], pixel_val[4:2], pixel_val[4:3]};
            b = {pixel_val[1:0], pixel_val[1:0], pixel_val[1:0], pixel_val[1:0]};

            $fwrite(ppm_file, "%0d %0d %0d\n", r, g, b);
        end

        $fclose(ppm_file);
        $display("=== Imagem exportada: framebuffer_output.ppm ===");
        $display("Abra o arquivo com qualquer visualizador de imagem.");

        #100;
        $finish;
    end

    // =========================================================================
    // Monitor de progresso (opcional — mostra o estado da FSM)
    // =========================================================================
    reg [1:0] prev_state;
    initial prev_state = 0;

    always @(posedge clk_50) begin
        if (rast_inst.state != prev_state) begin
            case (rast_inst.state)
                2'd0: $display("[%0t ns] Estado: IDLE", $time);
                2'd1: $display("[%0t ns] Estado: CLEAR", $time);
                2'd2: $display("[%0t ns] Estado: DRAW", $time);
                2'd3: $display("[%0t ns] Estado: DONE", $time);
            endcase
            prev_state <= rast_inst.state;
        end
    end

endmodule
