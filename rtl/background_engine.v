module background_engine (
    input wire clk,
    input wire reset,
    input wire enable,
    input wire auto_scroll,

    input wire [8:0] scroll_x_in,
    input wire [7:0] scroll_y_in,

    input wire [8:0] pixel_x,
    input wire [7:0] pixel_y,

    output wire [7:0] bg_color
);

    localparam W = 320;
    localparam H = 240;


    // ============================================================
    // SCROLL
    // ============================================================

    reg [8:0] scroll_x_reg;
    reg [7:0] scroll_y_reg;

    reg frame_edge_d;

    wire frame_edge;

    assign frame_edge =
        (pixel_x == 9'd319) &&
        (pixel_y == 8'd239);


    always @(posedge clk) begin

        if (reset) begin

            scroll_x_reg <= 9'd0;
            scroll_y_reg <= 8'd0;
            frame_edge_d <= 1'b0;

        end

        else begin

            frame_edge_d <= frame_edge;

            if (frame_edge && !frame_edge_d) begin

                if (auto_scroll) begin

                    if (scroll_x_in < scroll_x_reg) begin

                        if (scroll_x_reg == 9'd0)
                            scroll_x_reg <= 9'd319;
                        else
                            scroll_x_reg <= scroll_x_reg - 1'b1;

                    end

                    else if (scroll_x_in > scroll_x_reg) begin

                        if (scroll_x_reg == 9'd319)
                            scroll_x_reg <= 9'd0;
                        else
                            scroll_x_reg <= scroll_x_reg + 1'b1;

                    end

                end

                else begin
                    scroll_x_reg <= scroll_x_in;
                end

                scroll_y_reg <= scroll_y_in;

            end

        end

    end


    // ============================================================
    // COORDENADAS COM SCROLL
    // ============================================================

    wire [9:0] sx_sum;
    wire [8:0] sx;

    wire [8:0] sy_sum;
    wire [7:0] sy;


    assign sx_sum =
        {1'b0, pixel_x} +
        {1'b0, scroll_x_reg};


    assign sx =
        (sx_sum >= 10'd320) ?
        (sx_sum - 10'd320) :
        sx_sum[8:0];


    assign sy_sum =
        {1'b0, pixel_y} +
        {1'b0, scroll_y_reg};


    assign sy =
        (sy_sum >= 9'd240) ?
        (sy_sum - 9'd240) :
        sy_sum[7:0];


    // ============================================================
    // TILE
    // ============================================================

    wire [5:0] tile_x;
    wire [4:0] tile_y;

    wire [2:0] col_in_tile;
    wire [2:0] row_in_tile;


    assign tile_x = sx[8:3];
    assign tile_y = sy[7:3];

    assign col_in_tile = sx[2:0];
    assign row_in_tile = sy[2:0];


    // ============================================================
    // ENDEREÇO DO TILEMAP
    //
    // tile_y * 40 + tile_x
    //
    // 40 = 32 + 8
    // ============================================================

    wire [10:0] tilemap_addr;


    assign tilemap_addr =
        {1'b0, tile_y, 5'b00000} +
        {3'b000, tile_y, 3'b000} +
        {5'b00000, tile_x};


    // ============================================================
    // PIPELINE DE 1 CICLO
    //
    // A tilemap_ram possui:
    //
    // address_reg_b = CLOCK0
    //
    // Portanto o tile_id que sair da RAM corresponde ao endereço
    // registrado neste mesmo estágio.
    //
    // row/col são registrados junto.
    // ============================================================

    reg [2:0] row_d1;
    reg [2:0] col_d1;
    reg enable_d1;


    always @(posedge clk) begin

        if (reset) begin

            row_d1    <= 3'd0;
            col_d1    <= 3'd0;
            enable_d1 <= 1'b0;

        end

        else begin

            row_d1    <= row_in_tile;
            col_d1    <= col_in_tile;
            enable_d1 <= enable;

        end

    end


    // ============================================================
    // TILEMAP
    // ============================================================

    wire [7:0] tile_id_lido;


    tilemap_ram tilemap_inst (

        .clk(clk),

        .addr_a(11'd0),
        .data_a(8'd0),
        .wren_a(1'b0),
        .q_a(),

        .addr_b(tilemap_addr),
        .q_b(tile_id_lido)

    );


    // ============================================================
    // ROM DOS PADRÕES
    //
    // A porta A está UNREGISTERED.
    //
    // Portanto não criar row_d2 / col_d2.
    // ============================================================

    wire [7:0] pixel_final_color;


    tile_patterns_rom pattern_inst (

        .clk(clk),

        .tile_id_a(tile_id_lido),
        .row_a(row_d1),
        .col_a(col_d1),

        .pixel_a(pixel_final_color),

        .tile_id_b(8'd0),
        .row_b(3'd0),
        .col_b(3'd0),

        .pixel_b()

    );


    // ============================================================
    // SAÍDA
    // ============================================================

    assign bg_color =
        enable_d1 ?
        pixel_final_color :
        8'h00;


endmodule