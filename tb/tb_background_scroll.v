`timescale 1ns/1ps

module tb_background_scroll;

    reg clk;
    reg reset;

    // Coordenadas lógicas (320x240)
    reg [8:0] pixel_x;
    reg [7:0] pixel_y;
    
    // Controle de Scroll
    reg [8:0] scroll_x_in;
    reg [7:0] scroll_y_in;

    // Saídas dos motores
    wire [7:0] bg_color;
    
    // Sinais fictícios para rasterizador e sprite
    wire [7:0] fb_color = 8'd0;
    wire [7:0] sprite_color = 8'd0;
    wire sprite_hit = 1'b0;

    // Saída final do compositor
    wire [7:0] final_color;

    // Instancia o Background Engine
    background_engine bg_inst (
        .clk(clk),
        .reset(reset),
        .enable(1'b1),
        .auto_scroll(1'b0),
        .scroll_x_in(scroll_x_in),
        .scroll_y_in(scroll_y_in),
        .pixel_x(pixel_x),
        .pixel_y(pixel_y),
        .bg_color(bg_color)
    );

    // Instancia o Compositor
    compositor comp_inst (
        .clk(clk),
        .reset(reset),
        .bg_color(bg_color),
        .fb_color(fb_color),
        .sprite_color(sprite_color),
        .sprite_hit(sprite_hit),
        .final_color(final_color)
    );

    // Gerador de clock
    always #20 clk = ~clk; // 25 MHz (40ns period)

    integer x, y, frame;
    integer file;

    initial begin
        clk = 0;
        reset = 1;
        pixel_x = 0;
        pixel_y = 0;
        scroll_x_in = 0;
        scroll_y_in = 0;

        #100;
        reset = 0;
        #100;

        // Renderiza Frame 0 (sem scroll)
        $display("Renderizando Frame 0 (Scroll X=0, Y=0)...");
        scroll_x_in = 0;
        scroll_y_in = 0;
        render_frame("frame_scroll_0_0.ppm");

        // Renderiza Frame 1 (scroll horizontal)
        $display("Renderizando Frame 1 (Scroll X=15, Y=0)...");
        scroll_x_in = 15;
        scroll_y_in = 0;
        render_frame("frame_scroll_15_0.ppm");

        // Renderiza Frame 2 (scroll vertical)
        $display("Renderizando Frame 2 (Scroll X=0, Y=15)...");
        scroll_x_in = 0;
        scroll_y_in = 15;
        render_frame("frame_scroll_0_15.ppm");

        $display("Simulação concluída!");
        $finish;
    end

    // Task para renderizar um quadro completo de 320x240
    task render_frame(input [8*256:1] filename);
        begin
            file = $fopen(filename, "w");
            $fwrite(file, "P3\n320 240\n255\n"); // Header do PPM

            for (y = 0; y < 240; y = y + 1) begin
                for (x = 0; x < 320; x = x + 1) begin
                    // Atualiza a posição e espera o pipeline processar
                    // Nota: o Compositor tem atraso de 3 ciclos.
                    // Para o teste simples, vamos alimentar a coordenada e
                    // esperar 4 ciclos para garantir que a cor estabilizou,
                    // já que no mundo real a VGA é um pipeline contínuo.
                    
                    pixel_x = x;
                    pixel_y = y;
                    
                    // Espera 3 clocks do pipeline completo
                    @(posedge clk);
                    @(posedge clk);
                    @(posedge clk);
                    
                    // Lemos a cor RGB332 gerada pela Paleta e extraímos
                    // R, G e B escalados para 0-255.
                    $fwrite(file, "%0d %0d %0d ", 
                        {final_color[7:5], 5'd0},
                        {final_color[4:2], 5'd0},
                        {final_color[1:0], 6'd0}
                    );
                end
                $fwrite(file, "\n");
            end
            $fclose(file);
        end
    endtask

endmodule
