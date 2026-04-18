`timescale 1s/1s

module tb_pipeline_riscv;

reg clk1, clk2;

// Instantiate DUT
pipeline_riscv uut (
    .clk1(clk1),
    .clk2(clk2)
);

// ================= CLOCK GENERATION =================
initial begin
    clk1 = 0;
    clk2 = 0;
end

// Non-overlapping clocks
always #10 clk1 = ~clk1;

always begin
    #5 clk2 = 1;
    #5 clk2 = 0;
end

// ================= WAVEFORM =================
initial begin
    $dumpfile("pipeline_riscv.vcd");
    $dumpvars(0, tb_pipeline_riscv.uut);
end

// ================= MONITOR =================
initial begin
    $monitor("T=%0t PC=%0d INSTR=%h ALU=%0d x1=%0d x2=%0d x3=%0d",
        $time,
        uut.pc,
        uut.IF_ID_instr,
        uut.alu_result,
        uut.regs[1],
        uut.regs[2],
        uut.regs[3]
    );
end

// ================= TEST PROGRAM =================
initial begin

    // IMPORTANT: continuous indexing (0,1,2,3...)
    
    // ADDI x1, x0, 5
// ADDI x1, x0, 5
uut.instr_mem[0] = 32'b000000000101_00000_000_00001_0010011;

// ADDI x2, x0, 10
uut.instr_mem[1] = 32'b000000001010_00000_000_00010_0010011;

// NOP
uut.instr_mem[2] = 32'b000000000000_00000_000_00000_0010011;

// NOP
uut.instr_mem[3] = 32'b000000000000_00000_000_00000_0010011;

// ADD x3 = x1 + x2
uut.instr_mem[4] = 32'b0000000_00010_00001_000_00011_0110011;

// NOP
uut.instr_mem[5] = 32'b000000000000_00000_000_00000_0010011;

// NOP
uut.instr_mem[6] = 32'b000000000000_00000_000_00000_0010011;

// STORE x3 → MEM[0]
uut.instr_mem[7] = 32'b0000000_00011_00000_010_00000_0100011;

// NOP
uut.instr_mem[8] = 32'b000000000000_00000_000_00000_0010011;

// NOP
uut.instr_mem[9] = 32'b000000000000_00000_000_00000_0010011;

// LOAD x4 ← MEM[0]
uut.instr_mem[10] = 32'b000000000000_00000_010_00100_0000011;

// NOP
uut.instr_mem[11] = 32'b000000000000_00000_000_00000_0010011;

// NOP ⭐ (important)
uut.instr_mem[12] = 32'b000000000000_00000_000_00000_0010011;

// ADD x5 = x3 + x4
uut.instr_mem[13] = 32'b0000000_00100_00011_000_00101_0110011;

// ADD x5 = x3 + x4
uut.instr_mem[12] = 32'b0000000_00100_00011_000_00101_0110011;
    // Run simulation
    #500;

    // Final results
    $display("\n===== FINAL OUTPUT =====");
    $display("x1 = %0d", uut.regs[1]); // expect 5
    $display("x2 = %0d", uut.regs[2]); // expect 10
    $display("x3 = %0d", uut.regs[3]); // expect 15
    $display("x4 = %0d", uut.regs[4]); // expect 15
    $display("x5 = %0d", uut.regs[5]); // expect 30
    $display("MEM[0] = %0d", uut.data_mem[0]); // expect 15

    $finish;
end

endmodule