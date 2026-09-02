module vga_driver (
    input wire clock,
    input wire reset,

    input wire [7:0] color_in,

    output wire [9:0] next_x,
    output wire [9:0] next_y,

    // Sinal de área ativa (combinacional, alinhado com next_x/next_y)
    // Usado pelo pipeline de imagem para saber quando o pixel é válido.
    output wire is_active,

    output wire hsync,
    output wire vsync,

    output wire [7:0] red,
    output wire [7:0] green,
    output wire [7:0] blue,

    output wire sync,
    output wire clk,
    output wire blank
);

    // ============================================================
    // VGA 640x480 @ ~60 Hz
    // ============================================================

    localparam [9:0] H_ACTIVE = 10'd639;
    localparam [9:0] H_FRONT  = 10'd15;
    localparam [9:0] H_PULSE  = 10'd95;
    localparam [9:0] H_BACK   = 10'd47;

    localparam [9:0] V_ACTIVE = 10'd479;
    localparam [9:0] V_FRONT  = 10'd9;
    localparam [9:0] V_PULSE  = 10'd1;
    localparam [9:0] V_BACK   = 10'd32;


    // ============================================================
    // ESTADOS
    // ============================================================

    localparam [1:0] ACTIVE = 2'd0;
    localparam [1:0] FRONT  = 2'd1;
    localparam [1:0] PULSE  = 2'd2;
    localparam [1:0] BACK   = 2'd3;


    reg [1:0] h_state;
    reg [1:0] v_state;

    reg [9:0] h_counter;
    reg [9:0] v_counter;

    reg hsync_reg;
    reg vsync_reg;

    reg [7:0] red_reg;
    reg [7:0] green_reg;
    reg [7:0] blue_reg;

    reg line_done;


    // ============================================================
    // CONTROLE VGA
    // ============================================================

    always @(posedge clock) begin

        if (reset) begin

            h_counter <= 10'd0;
            v_counter <= 10'd0;

            h_state <= ACTIVE;
            v_state <= ACTIVE;

            hsync_reg <= 1'b1;
            vsync_reg <= 1'b1;

            line_done <= 1'b0;

            red_reg <= 8'd0;
            green_reg <= 8'd0;
            blue_reg <= 8'd0;

        end

        else begin

            // ====================================================
            // HORIZONTAL
            // ====================================================

            case (h_state)

                ACTIVE: begin

                    hsync_reg <= 1'b1;
                    line_done <= 1'b0;

                    if (h_counter == H_ACTIVE) begin
                        h_counter <= 10'd0;
                        h_state <= FRONT;
                    end
                    else begin
                        h_counter <= h_counter + 1'b1;
                    end

                end


                FRONT: begin

                    hsync_reg <= 1'b1;

                    if (h_counter == H_FRONT) begin
                        h_counter <= 10'd0;
                        h_state <= PULSE;
                    end
                    else begin
                        h_counter <= h_counter + 1'b1;
                    end

                end


                PULSE: begin

                    hsync_reg <= 1'b0;

                    if (h_counter == H_PULSE) begin
                        h_counter <= 10'd0;
                        h_state <= BACK;
                    end
                    else begin
                        h_counter <= h_counter + 1'b1;
                    end

                end


                BACK: begin

                    hsync_reg <= 1'b1;

                    if (h_counter == H_BACK) begin
                        h_counter <= 10'd0;
                        h_state <= ACTIVE;
                    end
                    else begin
                        h_counter <= h_counter + 1'b1;
                    end

                    // último ciclo da linha
                    line_done <= (h_counter == H_BACK - 1'b1);

                end

            endcase


            // ====================================================
            // VERTICAL
            // ====================================================

            case (v_state)

                ACTIVE: begin

                    vsync_reg <= 1'b1;

                    if (line_done) begin

                        if (v_counter == V_ACTIVE) begin
                            v_counter <= 10'd0;
                            v_state <= FRONT;
                        end
                        else begin
                            v_counter <= v_counter + 1'b1;
                        end

                    end

                end


                FRONT: begin

                    vsync_reg <= 1'b1;

                    if (line_done) begin

                        if (v_counter == V_FRONT) begin
                            v_counter <= 10'd0;
                            v_state <= PULSE;
                        end
                        else begin
                            v_counter <= v_counter + 1'b1;
                        end

                    end

                end


                PULSE: begin

                    vsync_reg <= 1'b0;

                    if (line_done) begin

                        if (v_counter == V_PULSE) begin
                            v_counter <= 10'd0;
                            v_state <= BACK;
                        end
                        else begin
                            v_counter <= v_counter + 1'b1;
                        end

                    end

                end


                BACK: begin

                    vsync_reg <= 1'b1;

                    if (line_done) begin

                        if (v_counter == V_BACK) begin
                            v_counter <= 10'd0;
                            v_state <= ACTIVE;
                        end
                        else begin
                            v_counter <= v_counter + 1'b1;
                        end

                    end

                end

            endcase


            // ====================================================
            // SAÍDA DE COR
            //
            // color_in corresponde à coordenada fornecida por
            // next_x / next_y.
            // ====================================================

            if ((h_state == ACTIVE) &&
                (v_state == ACTIVE)) begin

                red_reg   <= {color_in[7:5], 5'd0};
                green_reg <= {color_in[4:2], 5'd0};
                blue_reg  <= {color_in[1:0], 6'd0};

            end

            else begin

                red_reg   <= 8'd0;
                green_reg <= 8'd0;
                blue_reg  <= 8'd0;

            end

        end

    end


    // ============================================================
    // COORDENADA PARA O PIPELINE DE IMAGEM
    //
    // next_x / next_y só são válidos na área ativa.
    // Fora dela forçamos 0 (comportamento original).
    // is_active permite ao top saber quando o pixel é visível.
    // ============================================================

    assign next_x =
        (h_state == ACTIVE) ? h_counter : 10'd0;

    assign next_y =
        (v_state == ACTIVE) ? v_counter : 10'd0;

    assign is_active = (h_state == ACTIVE) && (v_state == ACTIVE);


    // ============================================================
    // SAÍDAS VGA
    // ============================================================

    assign hsync = hsync_reg;
    assign vsync = vsync_reg;

    assign red   = red_reg;
    assign green = green_reg;
    assign blue  = blue_reg;

    assign clk = clock;

    assign sync = 1'b0;

    assign blank =
        hsync_reg &
        vsync_reg;

endmodule