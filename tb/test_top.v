module test_top (
 input wire CLOCK_50,
 input wire [3:0] KEY,
 input wire [9:0] SW,
 output wire VGA_HS,VGA_VS,
 output wire [7:0] VGA_R,VGA_G,VGA_B,
 output wire VGA_SYNC_N,VGA_CLK,VGA_BLANK_N
);

 // ============================================================
 // CLOCK 50 MHz -> 25 MHz
 // ============================================================

 reg clk_25mhz = 1'b0;

 always @(posedge CLOCK_50)
     clk_25mhz <= ~clk_25mhz;

 wire reset = ~KEY[0];


 // ============================================================
 // VGA
 // ============================================================

 wire [9:0] next_x_vga;
 wire [9:0] next_y_vga;
 wire        vga_is_active;

 // ----------------------------------------------------------
 // LATÊNCIA DO PIPELINE DE IMAGEM (versão simples e estável)
 //
 // bg / fb / sprite  → 1 ciclo
 // compositor (paleta) → +1 ciclo
 // TOTAL ≈ 2 ciclos
 //
 // Estratégia estável:
 // - Coordenadas = posição atual (sem look-ahead complexo)
 // - Os primeiros LEFT_BLANK pixels lógicos de cada linha
 //   são forçados a preto para esconder o lixo do pipeline
 // - O restante da imagem fica alinhado e sem a faixa ciano
 // ----------------------------------------------------------
 localparam LEFT_BLANK_LOGICAL = 2;  // pixels lógicos a esconder na esquerda

 // Coordenada lógica atual (pixel doubling 640→320)
 wire [8:0] x_logico = next_x_vga[9:1];
 wire [7:0] y_logico = next_y_vga[9:1];

 // Conta quantos pixels lógicos já saíram nesta linha ativa
 reg [8:0] col_in_line;
 always @(posedge clk_25mhz) begin
     if (reset || !vga_is_active)
         col_in_line <= 9'd0;
     else if (next_x_vga[0] == 1'b1)      // sobe a cada 2 clocks
         col_in_line <= col_in_line + 1'b1;
 end

 wire left_blank = vga_is_active && (col_in_line < LEFT_BLANK_LOGICAL);

 // Flag de pipeline (mantida para possível uso futuro)
 reg [1:0] active_pipe;
 always @(posedge clk_25mhz) begin
     if (reset)
         active_pipe <= 2'b00;
     else
         active_pipe <= {active_pipe[0], vga_is_active};
 end
 wire pipe_valid = active_pipe[1];


 // ============================================================
 // UNIDADE DE CONTROLE
 // ============================================================

 wire rast_start;
 wire rast_enable_clear;
 wire rast_tipo;
 wire rast_done;

 wire [7:0] rast_cor_p;

 wire sprite_mirror_h;
 wire sprite_mirror_v;

 wire [8:0] rx0;
 wire [8:0] rx1;
 wire [8:0] rx2;

 wire [7:0] ry0;
 wire [7:0] ry1;
 wire [7:0] ry2;

 wire control_busy;
 wire scene_done;


 // ============================================================
 // CONTROL UNIT
 // ============================================================

 control_unit_32 control(
  .clk(CLOCK_50),
  .reset(reset),
  .rast_done(rast_done),
  .SW(SW),

  .rast_start(rast_start),
  .rast_enable_clear(rast_enable_clear),
  .rast_tipo(rast_tipo),
  .rast_cor_p(rast_cor_p),

  .rx0(rx0),
  .rx1(rx1),
  .rx2(rx2),

  .ry0(ry0),
  .ry1(ry1),
  .ry2(ry2),

  .busy(control_busy),
  .scene_done(scene_done),

  .sprite_mirror_h(sprite_mirror_h),
  .sprite_mirror_v(sprite_mirror_v)
 );


 // ============================================================
 // RASTERIZADOR
 // ============================================================

 wire [16:0] rast_write_addr;
 wire [7:0] rast_write_data;
 wire rast_write_enable;


 rasterizer raster_inst(
  .clk(CLOCK_50),
  .reset(reset),

  .start(rast_start),
  .enable_clear(rast_enable_clear),

  .tipo_forma(rast_tipo),
  .cor_preenchimento(rast_cor_p),
  .cor_fundo(8'h00),

  .x0(rx0),
  .y0(ry0),

  .x1(rx1),
  .y1(ry1),

  .x2(rx2),
  .y2(ry2),

  .write_addr(rast_write_addr),
  .write_data(rast_write_data),
  .write_enable(rast_write_enable),

  .done(rast_done)
 );


 // ============================================================
 // MOVIMENTO DO PERSONAGEM
 //
 // KEY[1] = esquerda
 // KEY[2] = direita
 // ============================================================

 reg [19:0] move_counter;
 reg [8:0] player_x;


 always @(posedge clk_25mhz) begin

  if(reset) begin

   move_counter <= 20'd0;
   player_x <= 9'd150;

  end

  else if(move_counter == 20'd749999) begin

   move_counter <= 20'd0;

   // Esquerda
   if(!KEY[1] && KEY[2] && player_x > 9'd0)
       player_x <= player_x - 1'b1;

   // Direita
   else if(!KEY[2] && KEY[1] && player_x < 9'd304)
       player_x <= player_x + 1'b1;

  end

  else begin

   move_counter <= move_counter + 1'b1;

  end

 end


 // ============================================================
 // MOVIMENTO DO BACKGROUND
 //
 // O cenário se move no sentido contrário ao personagem.
 //
 // personagem -> background <-
 // personagem <- background ->
 // ============================================================

 reg [8:0] background_x;
 reg [7:0] background_y;


 always @(posedge clk_25mhz) begin

  if(reset) begin

   background_x <= 9'd0;
   background_y <= 8'd0;

  end

  else if(move_counter == 20'd749999) begin

   // ----------------------------------------------------------
   // Personagem andando para a direita
   // Background anda para a esquerda
   // ----------------------------------------------------------

   if(!KEY[2] && KEY[1]) begin

    if(background_x == 9'd319)
        background_x <= 9'd0;
    else
        background_x <= background_x + 1'b1;

   end

   // ----------------------------------------------------------
   // Personagem andando para a esquerda
   // Background anda para a direita
   // ----------------------------------------------------------

   else if(!KEY[1] && KEY[2]) begin

    if(background_x == 9'd0)
        background_x <= 9'd319;
    else
        background_x <= background_x - 1'b1;

   end


   // ----------------------------------------------------------
   // Personagem andando para CIMA
   // SW[2]
   //
   // Background anda para BAIXO
   // ----------------------------------------------------------

   if(SW[2] && !SW[3]) begin

       if(background_y == 8'd239)
           background_y <= 8'd0;
       else
           background_y <= background_y + 1'b1;

   end

   // ----------------------------------------------------------
   // Personagem andando para BAIXO
   // SW[3]
   //
   // Background anda para CIMA
   // ----------------------------------------------------------

   else if(!SW[2] && SW[3]) begin

       if(background_y == 8'd0)
           background_y <= 8'd239;
       else
           background_y <= background_y - 1'b1;

   end

  end

 end


 // ============================================================
 // ATRIBUTOS DOS SPRITES
 // ============================================================

 reg [31:0] sprite_attr_reg;
 reg [31:0] sprite_attr_reg_2;

 always @(posedge clk_25mhz) begin

  if(reset) begin
      sprite_attr_reg <= 32'd0;
      sprite_attr_reg_2 <= 32'd0;
  end else begin
      // Sprite 1 (Original controlado pelo jogador)
      sprite_attr_reg <= {
          1'b1,
          2'b10,
          sprite_mirror_h,
          sprite_mirror_v,
          1'b0,
          player_x,
          1'b0,
          8'd0,
          8'd168
      };

      // Sprite 2 (Fixo na tela usando o mesmo Tile ID 0)
      sprite_attr_reg_2 <= {
          1'b1,              // Ativo = 1
          2'b10,             // Palette info
          1'b0,              // mirror_h
          1'b0,              // mirror_v
          1'b0,              // padding
          9'd200,            // Posição X (Fixo em 200)
          1'b0,              // padding
          8'd0,              // Tile ID (0 = mesmo desenho do Sprite 1)
          8'd168             // Posição Y 
      };
  end

 end


 // ============================================================
 // MOTORES DOS SPRITES
 // ============================================================

 // --- Fios do Sprite 1 ---
 wire [10:0] spr_tile_addr;
 wire [7:0] spr_tile_data;
 wire [7:0] spr_color;
 wire spr_hit;

 wire sprite_wr = ~reset;
 wire [4:0] sprite_id = 5'd0;

 // --- Fios do Sprite 2 ---
 wire [10:0] spr_tile_addr_2;
 wire [7:0] spr_tile_data_2;
 wire [7:0] spr_color_2;
 wire spr_hit_2;
 wire [4:0] sprite_id_2 = 5'd1;


 // Instância do Sprite Engine 1
 sprite_engine sprite_inst(
  .clk(clk_25mhz),
  .reset(reset),

  .pixel_x(x_logico),
  .pixel_y(y_logico),

  .sprite_attr(sprite_attr_reg),
  .wr_sprite(sprite_wr),
  .sprite_id(sprite_id),

  .tile_addr(spr_tile_addr),
  .tile_data(spr_tile_data),

  .sprite_color(spr_color),
  .sprite_hit_out(spr_hit)
 );

 // Instância do Sprite Engine 2
 sprite_engine sprite_inst_2(
  .clk(clk_25mhz),
  .reset(reset),

  .pixel_x(x_logico),
  .pixel_y(y_logico),

  .sprite_attr(sprite_attr_reg_2),
  .wr_sprite(sprite_wr),
  .sprite_id(sprite_id_2),

  .tile_addr(spr_tile_addr_2),
  .tile_data(spr_tile_data_2),

  .sprite_color(spr_color_2),
  .sprite_hit_out(spr_hit_2)
 );


 // ============================================================
 // SPRITE TILE ROM (DUPLICADAS PARA LER AO MESMO TEMPO)
 // ============================================================

 // ROM para o Sprite 1
 sprite_tile_rom spr_rom_inst(
  .clk(clk_25mhz),
  .addr(spr_tile_addr),
  .data(spr_tile_data)
 );

 // ROM separada para o Sprite 2
 sprite_tile_rom spr_rom_inst_2(
  .clk(clk_25mhz),
  .addr(spr_tile_addr_2),
  .data(spr_tile_data_2)
 );


 // ============================================================
 // BACKGROUND
 // ============================================================

 wire [7:0] bg_color;


 background_engine bg_inst(
  .clk(clk_25mhz),
  .reset(reset),

  .enable(1'b1),

  .auto_scroll(1'b0),

  .scroll_x_in(background_x),
  .scroll_y_in(background_y),

  .pixel_x(x_logico),
  .pixel_y(y_logico),

  .bg_color(bg_color)
 );


 // ============================================================
 // FRAMEBUFFER
 // ============================================================

 wire [16:0] read_address;
 wire [7:0] fb_read_data;


 coord_to_addr conv_leitura(
  .x(x_logico),
  .y(y_logico),
  .addr(read_address)
 );


 framebuffer fb_inst(
  .clk_w(CLOCK_50),

  .write_addr(rast_write_addr),
  .write_data(rast_write_data),
  .write_enable(rast_write_enable),

  .clk_r(clk_25mhz),

  .read_addr(read_address),
  .read_data(fb_read_data)
 );


 // ============================================================
 // COMBINAÇÃO DOS SPRITES E COMPOSIÇÃO FINAL
 // ============================================================

 wire [7:0] final_color;

 // --- NOVO: Máscara do Framebuffer via Switch 9 ---
 // Se SW[9] for 1, repassa os dados do framebuffer normalmente.
 // Se SW[9] for 0, passa a cor transparente (8'h00), "apagando" o rasterizador.
 wire [7:0] fb_color_to_compositor = SW[9] ? fb_read_data : 8'h00;

 // Lógica que previne a sobreposição com pixel transparente 
 // Confirma o hit SOMENTE se a cor não for transparente (8'h00)
 wire valid_hit_1 = spr_hit && (spr_color != 8'h00);
 wire valid_hit_2 = spr_hit_2 && (spr_color_2 != 8'h00);

 wire combined_spr_hit = valid_hit_1 | valid_hit_2;

 // Se o Sprite 1 tiver um hit válido e opaco, ele ganha.
 // Caso contrário, a cor do Sprite 2 passa.
 wire [7:0] combined_spr_color = valid_hit_1 ? spr_color : spr_color_2;


 compositor comp_inst(
  .clk(clk_25mhz),
  .reset(reset),

  .bg_color(bg_color),
  .fb_color(fb_color_to_compositor), // <--- O Framebuffer agora passa pela máscara

  .sprite_color(combined_spr_color),
  .sprite_hit(combined_spr_hit),

  .final_color(final_color)
 );


 // ============================================================
 // VGA DRIVER
 // ============================================================

 // Força preto nos primeiros pixels da linha (esconde o
 // artefato de latência da primeira coluna) e deixa o
 // restante da imagem normal.
 wire [7:0] color_to_vga = left_blank ? 8'h00 : final_color;

 vga_driver vga_inst(
  .clock(clk_25mhz),
  .reset(reset),

  .color_in(color_to_vga),

  .next_x(next_x_vga),
  .next_y(next_y_vga),
  .is_active(vga_is_active),

  .hsync(VGA_HS),
  .vsync(VGA_VS),

  .red(VGA_R),
  .green(VGA_G),
  .blue(VGA_B),

  .sync(VGA_SYNC_N),
  .clk(VGA_CLK),
  .blank(VGA_BLANK_N)
 );

endmodule