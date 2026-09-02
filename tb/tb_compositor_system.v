// ============================================================================
// Testbench: tb_compositor_system
// Descrição: Simula o sistema completo (rasterizer + bg_engine + arbiter + 
//            framebuffer + sprite_engine + sprite_tile_rom + compositor).
//            Aguarda os motores desenharem no framebuffer e então varre 
//            as coordenadas X/Y para extrair a imagem combinada final,
//            exportando-a como arquivo PPM.
// ============================================================================
`timescale 1ns / 1ps

module tb_compositor_system;

    // Sinais de clock e reset
    reg clk_50;
    reg clk_25;
    reg reset;
    reg start_rast;
    reg rast_enable_clear;

    wire [16:0] rast_write_addr;
    wire [7:0]  rast_write_data;
    wire        rast_write_enable;
    wire        rast_done;
    reg         rast_tipo;
    reg [7:0]   rast_cor_p;
    reg [8:0]   rx0, rx1, rx2;
    reg [7:0]   ry0, ry1, ry2;

    // Fios de varredura para extração da imagem
    reg  [8:0] scan_x;
    reg  [7:0] scan_y;
    wire [16:0] fb_read_addr;
    wire [7:0]  fb_read_data;

    // Fios do Sprite Engine e Compositor
    wire [10:0] spr_tile_addr;
    wire [7:0]  spr_tile_data;
    wire [7:0]  spr_color;
    wire        spr_hit;
    wire [7:0]  final_color;

    // Registradores para configuração dos sprites
    reg [31:0] sprite_attr;
    reg        sprite_wr;
    reg [4:0]  sprite_id;

    // =========================================================================
    // Clocks
    // =========================================================================
    initial begin
        clk_50 = 0;
        clk_25 = 0;
    end
    always #10 clk_50 = ~clk_50;
    always #20 clk_25 = ~clk_25;

    // =========================================================================
    // Conversor de Coordenadas
    // =========================================================================
    coord_to_addr conv_leitura (
        .x(scan_x),
        .y(scan_y),
        .addr(fb_read_addr)
    );

    // =========================================================================
    // Motores de Escrita (50 MHz)
    // =========================================================================
    rasterizer rast_inst (
        .clk(clk_50),
        .reset(reset),
        .start(start_rast),
        .enable_clear(rast_enable_clear),
        .tipo_forma(rast_tipo),
        .cor_preenchimento(rast_cor_p),
        .cor_fundo(8'd0),                   // Limpa com Preto Transparente
        .x0(rx0), .y0(ry0),
        .x1(rx1), .y1(ry1),
        .x2(rx2), .y2(ry2),
        .write_addr(rast_write_addr),
        .write_data(rast_write_data),
        .write_enable(rast_write_enable),
        .done(rast_done)
    );

    wire [7:0] bg_color;
    background_engine bg_inst (
        .clk(clk_25),
        .reset(reset),
        .enable(1'b1),
        .auto_scroll(1'b0),                 // Sem scroll no TB
        .cor_tile_a(8'b101_101_10),
        .cor_tile_b(8'b101_101_10),
        .scroll_x_in(9'd0),
        .scroll_y_in(8'd0),
        .pixel_x(scan_x),                   // Coordenadas simuladas
        .pixel_y(scan_y),
        .bg_color(bg_color)
    );

    framebuffer fb_inst (
        .clk_w(clk_50),
        .write_addr(rast_write_addr),
        .write_data(rast_write_data),
        .write_enable(rast_write_enable),
        .clk_r(clk_25),
        .read_addr(fb_read_addr),
        .read_data(fb_read_data)
    );

    // =========================================================================
    // Avaliação e Composição (25 MHz)
    // =========================================================================
    sprite_engine spr_inst (
        .clk(clk_25),
        .reset(reset),
        .pixel_x(scan_x),
        .pixel_y(scan_y),
        .sprite_attr(sprite_attr),
        .wr_sprite(sprite_wr),
        .sprite_id(sprite_id),
        .tile_addr(spr_tile_addr),
        .tile_data(spr_tile_data),
        .sprite_color(spr_color),
        .sprite_hit_out(spr_hit)
    );

    sprite_tile_rom spr_rom_inst (
        .clk(clk_25),
        .addr(spr_tile_addr),
        .data(spr_tile_data)
    );

    // Delay Pipeline
    reg [7:0] fb_color_d1;
    reg [7:0] spr_color_d1;
    reg       spr_hit_d1;

    always @(posedge clk_25) begin
        fb_color_d1  <= fb_read_data;
        spr_color_d1 <= spr_color;
        spr_hit_d1   <= spr_hit;
    end

    compositor comp_inst (
        .bg_color(bg_color),
        .fb_color(fb_color_d1),
        .sprite_color(spr_color_d1),
        .sprite_hit(spr_hit_d1),
        .final_color(final_color)
    );

    // =========================================================================
    // Procedimento de Teste
    // =========================================================================
    integer ppm_file;
    integer out_x, out_y, spr_i;
    reg [8:0] calc_x;
    reg [7:0] r, g, b;

    initial begin
        // Inicialização
        clk_50 = 0;
        clk_25 = 0;
        reset = 1;
        start_rast = 0;
        rast_enable_clear = 0;
        sprite_wr = 0;
        scan_x = 0;
        scan_y = 0;
        #100;
        reset = 0;
        #100;

        // 1. Configura Sprites...
        $display("Configurando Sprites...");
        sprite_id = 5'd0;
        // Cavaleiro (Knight)
        sprite_attr = {1'b1, 2'b10, 1'b0, 1'b0, 1'b0, 9'd150, 1'b0, 8'd0, 8'd180};
        sprite_wr = 1;
        #40;
        
        // Sprites 1 ao 20: Chão de Grama
        for (spr_i = 1; spr_i <= 20; spr_i = spr_i + 1) begin
            sprite_id = spr_i[4:0];
            calc_x = (spr_i - 1) * 16;
            sprite_attr = {1'b1, 2'b01, 1'b0, 1'b0, 1'b0, calc_x, 1'b0, 8'd4, 8'd196};
            sprite_wr = 1;
            #40;
        end
        sprite_wr = 0;

        // 2. Limpa o Framebuffer com Preto Transparente
        $display("Limpando Framebuffer com Preto (Transparente)...");
        rast_enable_clear = 1'b1;
        rast_tipo = 1'b1;
        rx0 = 9'd0; ry0 = 8'd0;
        rx1 = 9'd1; ry1 = 8'd1; // Tamanho 1x1 para evitar underflow
        rast_cor_p = 8'd0;      // Cor transparente para evitar lixo
        start_rast = 1;
        #40;
        start_rast = 0;
        wait(rast_done == 1);
        #40;

        // 3. Dispara o rasterizer
        rast_enable_clear = 1'b0; // Pula o CLEAR agora!
        $display("=== Desenhando Forma 1 (Sol) ===");
        rast_tipo = 1'b1; // Retângulo
        rast_cor_p = 8'b111_111_00; // Amarelo
        rx0 = 9'd250; ry0 = 8'd20; // x, y
        rx1 = 9'd30;  ry1 = 8'd30; // w, h
        rx2 = 9'd0;   ry2 = 8'd0;
        start_rast = 1;
        #40;
        start_rast = 0;
        wait(rast_done == 1);
        #40;

        // Forma 2: Montanha (Triângulo)
        $display("=== Desenhando Forma 2 (Montanha) ===");
        rast_tipo = 1'b0; // Triângulo
        rast_cor_p = 8'b111_000_00; // Vermelho
        rx0 = 9'd100; ry0 = 8'd40;
        rx1 = 9'd150; ry1 = 8'd100;
        rx2 = 9'd50;  ry2 = 8'd100;
        start_rast = 1;
        #40;
        start_rast = 0;
        wait(rast_done == 1);
        #40;

        // Forma 3: Nuvem ou Outro Retângulo
        $display("=== Desenhando Forma 3 (Nuvem) ===");
        rast_tipo = 1'b1; // Retângulo
        rast_cor_p = 8'b111_111_11; // Branco
        rx0 = 9'd50; ry0 = 8'd20; // x, y
        rx1 = 9'd60; ry1 = 8'd15; // w, h
        start_rast = 1;
        #40;
        start_rast = 0;
        wait(rast_done == 1);
        #40;

        $display("Rasterizador concluiu todas as formas.");

        $display("Motores concluíram. Extraindo imagem...");

        // 5. Varredura da tela e exportação PPM
        ppm_file = $fopen("compositor_output.ppm", "w");
        if (ppm_file == 0) begin
            $display("ERRO: Nao foi possivel criar o arquivo PPM.");
            $finish;
        end

        $fwrite(ppm_file, "P3\n320 240\n255\n");

        for (out_y = 0; out_y < 240; out_y = out_y + 1) begin
            for (out_x = 0; out_x < 320; out_x = out_x + 1) begin
                // Atualiza as coordenadas (simula o vga_driver avançando os pixels)
                scan_x = out_x;
                scan_y = out_y;

                // O sistema tem um pipeline de leitura:
                // Ciclo 1: scan_x/y atualizam. O coord_to_addr é combinacional.
                //          O sprite_engine (Estágio 1) avalia colisões combinacionalmente.
                // Ciclo 2 (borda de subida de clk_25):
                //          Framebuffer lê o dado da RAM.
                //          sprite_tile_rom lê o dado do tile.
                //          sprite_engine propaga o sinal de hit.
                // Ciclo 3 (após a borda, dados propagados):
                //          O compositor combina as cores puramente combinacionalmente.
                //
                // Precisamos esperar 2 ciclos completos de 25 MHz para ter a cor válida na saída.
                
                #40; // 1 ciclo de clk_25
                #40; // +1 ciclo de clk_25 (latência da RAM)
                
                // Agora "final_color" deve ser válida
                if (out_x == 0 && out_y == 0) begin
                    $display("DEBUG (0,0): bg_color=%b, fb_color_d1=%b, spr_color_d1=%b, final_color=%b", 
                             bg_color, fb_color_d1, spr_color_d1, final_color);
                end

                r = {final_color[7:5], final_color[7:5], final_color[7:6]};
                g = {final_color[4:2], final_color[4:2], final_color[4:3]};
                b = {final_color[1:0], final_color[1:0], final_color[1:0], final_color[1:0]};

                $fwrite(ppm_file, "%0d %0d %0d\n", r, g, b);
            end
        end

        $fclose(ppm_file);
        $display("=== Sucesso! Imagem salva em compositor_output.ppm ===");
        $finish;
    end

endmodule
