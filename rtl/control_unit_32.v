
module control_unit_32 (
    input  wire        clk,
    input  wire        reset,
    input  wire        rast_done,
    input  wire [9:0]  SW,

    output reg         rast_start,
    output reg         rast_enable_clear,
    output reg         rast_tipo,
    output reg  [7:0]  rast_cor_p,

    output reg  [8:0]  rx0,
    output reg  [8:0]  rx1,
    output reg  [8:0]  rx2,

    output reg  [7:0]  ry0,
    output reg  [7:0]  ry1,
    output reg  [7:0]  ry2,

    output reg         busy,
    output reg         scene_done,

    // Espelhamento horizontal/vertical do sprite
    output reg         sprite_mirror_h,
    output reg         sprite_mirror_v
);

    // ============================================================
    // Estados da máquina de controle
    // ============================================================

    localparam S_FETCH = 3'd0;
    localparam S_EXEC  = 3'd1;
    localparam S_WAIT  = 3'd2;
    localparam S_HALT  = 3'd3;


    // ============================================================
    // Códigos das instruções
    // ============================================================

    localparam OP_COLOR = 4'h1;
    localparam OP_CLEAR = 4'h2;
    localparam OP_XY    = 4'h3;
    localparam OP_WH    = 4'h4;
    localparam OP_RECT  = 4'h5;
    localparam OP_TRI   = 4'h6;
    localparam OP_T0    = 4'h7;
    localparam OP_T1    = 4'h8;
    localparam OP_T2    = 4'h9;
    localparam OP_MIRROR= 4'hA; // [28]=H, [27]=V
    localparam OP_HALT  = 4'hF;


    // ============================================================
    // Registradores
    // ============================================================

    reg [2:0]  state;
    reg [4:0]  pc;
    reg [31:0] instruction;

    // Retângulo
    reg [8:0]  rect_x;
    reg [7:0]  rect_y;
    reg [8:0]  rect_w;
    reg [7:0]  rect_h;

    // Vértices do triângulo
    reg [8:0]  tx0;
    reg [8:0]  tx1;
    reg [8:0]  tx2;

    reg [7:0]  ty0;
    reg [7:0]  ty1;
    reg [7:0]  ty2;

    // Cor atual
    reg [7:0]  current_color;


    // ============================================================
    // ROM de instruções
    // ============================================================

    wire [31:0] rom_data;

    instruction_rom_32 program_rom (
        .clk  (clk),
        .addr (pc),
        .data (rom_data)
    );


    // ============================================================
    // Opcode da instrução atual
    // ============================================================

    wire [3:0] opcode = instruction[31:28];


    // ============================================================
    // Máquina de estados
    // ============================================================

    always @(posedge clk) begin

        if (reset) begin

            state <= S_FETCH;
            pc <= 5'd0;
            instruction <= 32'd0;

            rect_x <= 9'd0;
            rect_y <= 8'd0;
            rect_w <= 9'd0;
            rect_h <= 8'd0;

            tx0 <= 9'd0;
            tx1 <= 9'd0;
            tx2 <= 9'd0;

            ty0 <= 8'd0;
            ty1 <= 8'd0;
            ty2 <= 8'd0;

            current_color <= 8'd0;

            rast_start <= 1'b0;
            rast_enable_clear <= 1'b0;
            rast_tipo <= 1'b1;
            rast_cor_p <= 8'd0;

            rx0 <= 9'd0;
            rx1 <= 9'd0;
            rx2 <= 9'd0;

            ry0 <= 8'd0;
            ry1 <= 8'd0;
            ry2 <= 8'd0;

            busy <= 1'b0;
            scene_done <= 1'b0;

            sprite_mirror_h <= 1'b0;
            sprite_mirror_v <= 1'b0;

        end

        else begin

            // SW[0] = espelhamento horizontal
            // SW[1] = espelhamento vertical
            // As chaves são lidas continuamente pela Unidade de Controle.
            sprite_mirror_h <= SW[0];
            sprite_mirror_v <= SW[1];

            // rast_start dura apenas um ciclo
            rast_start <= 1'b0;

            case (state)

                // ====================================================
                // FETCH
                // ====================================================

                S_FETCH: begin

                    instruction <= rom_data;

                    pc <= pc + 1'b1;

                    busy <= 1'b1;

                    state <= S_EXEC;

                end


                // ====================================================
                // EXEC
                // ====================================================

                S_EXEC: begin

                    case (opcode)

                        // ------------------------------------------------
                        // Define a cor atual
                        // ------------------------------------------------

                        OP_COLOR: begin

                            current_color <= instruction[7:0];

                            state <= S_FETCH;

                        end


                        // ------------------------------------------------
                        // Define posição X/Y do retângulo
                        // ------------------------------------------------

                        OP_XY: begin

                            rect_x <= instruction[26:18];
                            rect_y <= instruction[17:10];

                            state <= S_FETCH;

                        end


                        // ------------------------------------------------
                        // Define largura/altura do retângulo
                        // ------------------------------------------------

                        OP_WH: begin

                            rect_w <= instruction[26:18];
                            rect_h <= instruction[17:10];

                            state <= S_FETCH;

                        end


                        // ------------------------------------------------
                        // Define vértice 0
                        // ------------------------------------------------

                        OP_T0: begin

                            tx0 <= instruction[26:18];
                            ty0 <= instruction[17:10];

                            state <= S_FETCH;

                        end


                        // ------------------------------------------------
                        // Define vértice 1
                        // ------------------------------------------------

                        OP_T1: begin

                            tx1 <= instruction[26:18];
                            ty1 <= instruction[17:10];

                            state <= S_FETCH;

                        end


                        // ------------------------------------------------
                        // Define vértice 2
                        // ------------------------------------------------

                        OP_T2: begin

                            tx2 <= instruction[26:18];
                            ty2 <= instruction[17:10];

                            state <= S_FETCH;

                        end


                        // ------------------------------------------------
                        // Limpa a tela
                        // ------------------------------------------------

                        OP_CLEAR: begin

                            rast_enable_clear <= 1'b1;
                            rast_tipo <= 1'b1;
                            rast_cor_p <= 8'd0;

                            rx0 <= 9'd0;
                            ry0 <= 8'd0;

                            rx1 <= 9'd1;
                            ry1 <= 8'd1;

                            rx2 <= 9'd0;
                            ry2 <= 8'd0;

                            rast_start <= 1'b1;

                            state <= S_WAIT;

                        end


                        // ------------------------------------------------
                        // Desenha retângulo
                        // ------------------------------------------------

                        OP_RECT: begin

                            rast_enable_clear <= 1'b0;
                            rast_tipo <= 1'b1;

                            rast_cor_p <= current_color;

                            rx0 <= rect_x;
                            ry0 <= rect_y;

                            rx1 <= rect_w;
                            ry1 <= rect_h;

                            rx2 <= 9'd0;
                            ry2 <= 8'd0;

                            rast_start <= 1'b1;

                            state <= S_WAIT;

                        end


                        // ------------------------------------------------
                        // Desenha triângulo
                        // ------------------------------------------------

                        OP_TRI: begin

                            rast_enable_clear <= 1'b0;
                            rast_tipo <= 1'b0;

                            rast_cor_p <= current_color;

                            rx0 <= tx0;
                            ry0 <= ty0;

                            rx1 <= tx1;
                            ry1 <= ty1;

                            rx2 <= tx2;
                            ry2 <= ty2;

                            rast_start <= 1'b1;

                            state <= S_WAIT;

                        end


                        // ------------------------------------------------
                        // Define espelhamento do sprite
                        //
                        // Formato:
                        // bit 28 = espelhamento horizontal
                        // bit 27 = espelhamento vertical
                        // ------------------------------------------------

                        OP_MIRROR: begin

                            // Mantido para compatibilidade com o programa.
                            // O espelhamento é controlado por SW[1:0].
                            state <= S_FETCH;

                        end


                        // ------------------------------------------------
                        // Finaliza programa
                        // ------------------------------------------------

                        OP_HALT: begin

                            busy <= 1'b0;
                            scene_done <= 1'b1;

                            state <= S_HALT;

                        end


                        // ------------------------------------------------
                        // Opcode inválido
                        // ------------------------------------------------

                        default: begin

                            state <= S_FETCH;

                        end

                    endcase

                end


                // ====================================================
                // WAIT
                // ====================================================

                S_WAIT: begin

                    if (rast_done) begin

                        rast_enable_clear <= 1'b0;

                        state <= S_FETCH;

                    end

                end


                // ====================================================
                // HALT
                // ====================================================

                S_HALT: begin

                    busy <= 1'b0;
                    scene_done <= 1'b1;

                end


                // ====================================================
                // Estado inválido
                // ====================================================

                default: begin

                    state <= S_FETCH;

                end

            endcase

        end

    end

endmodule

