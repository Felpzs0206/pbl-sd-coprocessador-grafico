module instruction_rom_32(
    input  wire        clk,
    input  wire [4:0]  addr,
    output reg  [31:0] data
);

    reg [31:0] rom [0:31];

    initial begin
        $readmemh("data/game_program.hex", rom);
    end

    always @(posedge clk) begin
        data <= rom[addr];
    end

endmodule

