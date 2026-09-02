`timescale 1ns/1ps

module tb_render_full;

    reg CLOCK_50;
    reg [3:0] KEY;
    reg [9:0] SW;

    wire VGA_HS, VGA_VS;
    wire [7:0] VGA_R, VGA_G, VGA_B;
    wire VGA_SYNC_N, VGA_CLK, VGA_BLANK_N;

    test_top top_inst (
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK),
        .VGA_BLANK_N(VGA_BLANK_N)
    );

    always #10 CLOCK_50 = ~CLOCK_50; // 50 MHz

    integer file;
    integer pixel_count;

    initial begin
        CLOCK_50 = 0;
        KEY = 4'b1110; // reset = ~KEY[0], então KEY[0]=0 reseta
        SW = 10'd0;
        
        #100;
        KEY = 4'b1111; // Libera o reset
        
        $display("Aguardando o inicio de um novo frame VGA para sincronizar...");
        
        // Espera o VSYNC sinalizar o inicio de um novo frame
        @(negedge VGA_VS);
        @(posedge VGA_VS);
        
        $display("Iniciando captura do Frame VGA (isso pode demorar 1-2 minutos na simulação)...");
        file = $fopen("full_render.ppm", "w");
        $fwrite(file, "P3\n640 480\n255\n");
        
        pixel_count = 0;
    end

    reg active, active_d1;

    // Monitora a saída VGA no clock da VGA (25MHz)
    always @(posedge VGA_CLK) begin
        // O h_state == 0 e v_state == 0 indicam a região ativa real de 640x480.
        // Como o red_reg do VGA tem 1 ciclo de atraso (recebe via <=), 
        // precisamos usar active_d1 para capturar a cor exata no ciclo seguinte.
        active <= (top_inst.vga_inst.h_state == 8'd0 && top_inst.vga_inst.v_state == 8'd0);
        active_d1 <= active;
        
        if (active_d1 && KEY[0] == 1'b1 && pixel_count < (640*480)) begin
            $fwrite(file, "%0d %0d %0d ", VGA_R, VGA_G, VGA_B);
            pixel_count = pixel_count + 1;
            
            // Quebra de linha a cada 640 pixels
            if (pixel_count % 640 == 0) begin
                $fwrite(file, "\n");
                if (pixel_count % (640*48) == 0) begin
                    $display("Progresso: %0d%% concluido...", (pixel_count * 100) / (640*480));
                end
            end
            
            // Termina a simulação quando completar o frame
            if (pixel_count == (640*480)) begin
                $display("Frame capturado com sucesso! Verifique o arquivo full_render.ppm");
                $fclose(file);
                $finish;
            end
        end
    end

endmodule
