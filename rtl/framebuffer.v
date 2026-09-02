//memória de vídeo 320×240 pixels, 8 bits por pixel (RRRGGGBB).
//porta A: write (usada pelo rasterizer)
//porta B: read (usada pelo controlador vga)
//suporta clocks independentes nas duas portas.
module framebuffer (
    // porta A — write
    input  wire        clk_w,          // clock de escrita (ex: 50 MHz)
    input  wire [16:0] write_addr,     // endereço de escrita (0 a 76799)
    input  wire [7:0]  write_data,     // dado a ser escrito (RRRGGGBB)
    input  wire        write_enable,   // habilitação de escrita

    // porta B — read
    input  wire        clk_r,          // clock de leitura (ex: 25 MHz)
    input  wire [16:0] read_addr,      // endereço de leitura (0 a 76799)
    output reg  [7:0]  read_data       // dado lido (RRRGGGBB)
);

    // declaração da memória: 76800 palavras de 8 bits
    // 320 * 240 = 76800
    reg [7:0] mem [0:76799];

    // porta A — write síncrona
    always @(posedge clk_w) begin
        if (write_enable)
            mem[write_addr] <= write_data;
    end

    // porta B — read síncrona (1 ciclo de latência)
    always @(posedge clk_r) begin
        read_data <= mem[read_addr];
    end

endmodule
