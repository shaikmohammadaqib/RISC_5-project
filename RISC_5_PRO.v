//“Designed a 32-bit 5-stage pipelined RISC-V processor in Verilog supporting R, I, Load/Store, 
//and Branch instructions with control unit, ALU, and memory integration.”
//

//Here we starting our work from the accumiltion of instructions in the instruction memory,based on the models of R,I,B,S.
//we are extracting the data for manupulation,here our most wanted thing is the data which we need to use for computations.
//in R-type it is in the rs1,rs2 address,in I,BS it is immediate type hence we only observing what we need in the code.
//what is useful for our further calculations.

// Supports basic R, I, Load/Store, Branch instructions
// Has 5 pipeline stages (IF, ID, EX, MEM, WB)
// Has control unit + ALU + register file + data memory
// Executes small instruction sequences correctly

module pipeline_riscv(input clk1,clk2);

// ================= IF STAGE =================
reg [31:0] pc; // programe counter for instructions showing
reg [31:0] instr_mem [0:255]; //instruction memeory
reg [31:0] regs [0:31];
reg [31:0] data_mem [0:255];
integer i;  //declarations outside loop for verilog

// 2  initial block and keeep something in memory
initial begin
    
    pc = 0;

    
    for (i = 0; i < 32; i = i + 1)
        regs[i] = 0;

    for (i = 0; i < 256; i = i + 1)
        data_mem[i] = 0;
end

//Fetch instruction using PC(IF stage)
wire [31:0] instruction = instr_mem[pc[9:2]]; //instruction fetching here we are using 256 adress so used pc[9:2]

always @(posedge clk1)
    pc <= pc + 4;//as we using 32 bit word so 8_bit 4 bytes comes in picture thats why next address is at +4

// IF/ID pipeline register
reg [31:0] IF_ID_instr; //to store next stage instructions
always @(posedge clk1)
    IF_ID_instr <= instruction;


// ================= ID STAGE =================

// Instruction fields
wire [6:0] opcode = IF_ID_instr[6:0]; //for R-type
wire [4:0] rs1 = IF_ID_instr[19:15];
wire [4:0] rs2 = IF_ID_instr[24:20];
wire [4:0] rd  = IF_ID_instr[11:7];
wire [2:0] funct3 = IF_ID_instr[14:12];
wire [6:0] funct7 = IF_ID_instr[31:25];

// Immediate generation
wire [31:0] imm_i = {{20{IF_ID_instr[31]}}, IF_ID_instr[31:20]}; //for I-type
wire [31:0] imm_s = {{20{IF_ID_instr[31]}}, IF_ID_instr[31:25], IF_ID_instr[11:7]};//for S-type
wire [31:0] imm_b = {{19{IF_ID_instr[31]}}, IF_ID_instr[31], IF_ID_instr[7],
                     IF_ID_instr[30:25], IF_ID_instr[11:8], 1'b0};// for B-type

// Register file
//reg [31:0] regs [0:31];at first initialized
wire [31:0] reg_data1 = regs[rs1];//outputs of register file
wire [31:0] reg_data2 = regs[rs2];

// Control signals
reg reg_write, alu_src, branch; 
reg mem_write, mem_read, mem_to_reg;
reg [2:0] alu_ctrl;     //reg_write enables writing result to register        //alu_ctrl selects the ALU operation (add, sub)
                        //alu_src selects register vs immediate input to ALU  //branch decides PC jump
                        //mem_write enables writing data into memory (store)
                        //mem_read enables reading data from memory (load).
                        //mem_to_reg enables to give control signal to mux at WB stage
// Control Unit
always @(*) begin
    // default values (VERY IMPORTANT) //intiations for our signals
    reg_write = 0; alu_src = 0; branch = 0;
    mem_write = 0; mem_read = 0; mem_to_reg = 0;
    alu_ctrl  = 3'b000;

    case(opcode)

        // R-TYPE
        7'b0110011: begin
            reg_write = 1; 
            case({funct7, funct3}) //funs are helpful in deciding what operation we are doing and its sub type clearly
                {7'b0000000,3'b000}: alu_ctrl = 3'b000; // ADD
                {7'b0100000,3'b000}: alu_ctrl = 3'b001; // SUB
                {7'b0000000,3'b111}: alu_ctrl = 3'b010; // AND
                {7'b0000000,3'b110}: alu_ctrl = 3'b011; // OR
            endcase
        end

        // I-TYPE
        7'b0010011: begin
            reg_write = 1;
            alu_src   = 1;
            case(funct3)
                3'b000: alu_ctrl = 3'b000; // ADDI
                3'b111: alu_ctrl = 3'b010; // ANDI
                3'b110: alu_ctrl = 3'b011; // ORI
            endcase
        end
                         //reg_write enables writing result to register        //alu_ctrl selects the ALU operation (add, sub)
                        //alu_src selects register vs immediate input to ALU  //branch decides PC jump
                        //mem_write enables writing data into memory (store)
                        //mem_read enables reading data from memory (load).
                        //mem_to_reg enables to give control signal to mux at WB stage
        // LOAD
        7'b0000011: begin
            reg_write = 1;
            alu_src   = 1;
            mem_read  = 1;
            mem_to_reg = 1;
            alu_ctrl  = 3'b000;
        end

        // STORE
        7'b0100011: begin
            alu_src   = 1;
            mem_write = 1;
            alu_ctrl  = 3'b000;
        end

        // BRANCH
        7'b1100011: begin
            branch   = 1;
            alu_ctrl = 3'b001; // SUB (compare)
        end
    endcase
end

// Select immediate
reg [31:0] imm;
always @(*) begin
    case(opcode)
        7'b0010011, 7'b0000011: imm = imm_i;
        7'b0100011: imm = imm_s;
        7'b1100011: imm = imm_b;
        default:    imm = 0;
    endcase
end

// ================= ID/EX =================
reg [31:0] ID_EX_A, ID_EX_B, ID_EX_imm; //storing values of register file for EX stge
reg [4:0]  ID_EX_rd;                    //it runs s it is tilll dat memory alocation
reg [2:0]  ID_EX_alu_ctrl;              //extend of alu_ctrl
reg ID_EX_reg_write, ID_EX_alu_src;
reg ID_EX_mem_write, ID_EX_mem_read, ID_EX_mem_to_reg; // extensions of reg_write = 0; alu_src = 0; branch = 0;
                                                       // mem_write = 0; mem_read = 0; mem_to_reg = 0;
                                                       //alu_ctrl  = 3'b000;

always @(posedge clk2) begin
    ID_EX_A <= reg_data1; //this are registers so values hold after clock cycle
    ID_EX_B <= reg_data2;
    ID_EX_imm <= imm;
    ID_EX_rd <= rd;

    ID_EX_alu_ctrl <= alu_ctrl;
    ID_EX_reg_write <= reg_write;
    ID_EX_alu_src <= alu_src;
    ID_EX_mem_write <= mem_write;
    ID_EX_mem_read <= mem_read;
    ID_EX_mem_to_reg <= mem_to_reg;
end


// ================= EX =================
wire [31:0] alu_in2 = (ID_EX_alu_src) ? ID_EX_imm : ID_EX_B; //// at input B the data may comes from input B or immideate value

reg [31:0] alu_result; //output of alu
always @(*) begin
    case(ID_EX_alu_ctrl)
        3'b000: alu_result = ID_EX_A + alu_in2;
        3'b001: alu_result = ID_EX_A - alu_in2;
        3'b010: alu_result = ID_EX_A & alu_in2;
        3'b011: alu_result = ID_EX_A | alu_in2;
        default: alu_result = 0;
    endcase
end


// ================= EX/MEM =================
reg [31:0] EX_MEM_result, EX_MEM_B;
reg [4:0] EX_MEM_rd;
reg EX_MEM_reg_write, EX_MEM_mem_write, EX_MEM_mem_read, EX_MEM_mem_to_reg; // extensions of above stage values

always @(posedge clk1) begin
    EX_MEM_result <= alu_result;
    EX_MEM_B <= ID_EX_B;
    EX_MEM_rd <= ID_EX_rd;

    EX_MEM_reg_write <= ID_EX_reg_write;
    EX_MEM_mem_write <= ID_EX_mem_write;
    EX_MEM_mem_read  <= ID_EX_mem_read;
    EX_MEM_mem_to_reg <= ID_EX_mem_to_reg;
end


// ================= MEM =================
//reg [31:0] data_mem [0:255]; // data memory initialized at top
reg [31:0] mem_out; //to store the output of memeory before mux comes in play

// =================STORE=================
always @(posedge clk2) begin
    if (EX_MEM_mem_write) begin //when enable to write in register
        data_mem[EX_MEM_result[9:2]] <= EX_MEM_B; //here B input is writing in the register
        $display("MEM WRITE: addr=%d data=%d", EX_MEM_result[9:2], EX_MEM_B);//observing what value is written here
    end
end                                                                     //in store operatio only value is stored in memory

// ==================LOAD===================
always @(*) begin
    if (EX_MEM_mem_read) //enables to load from memeory
        mem_out = data_mem[EX_MEM_result[9:2]]; //here we are loading from aluout or data memeory based on control signal
    else                                        //EX_MEM_mem_read this decides which value to be stored
        mem_out = EX_MEM_result;
end


// ================= MEM/WB =================
reg [31:0] MEM_WB_result;
reg [31:0] MEM_WB_mem_out;   // registers for memeory WB interface
reg [4:0] MEM_WB_rd;
reg MEM_WB_reg_write;
reg MEM_WB_mem_to_reg;    

always @(posedge clk1) begin
     MEM_WB_mem_out <= mem_out;       //  memory output stored
    MEM_WB_result  <= EX_MEM_result; //  ALU result stored
    MEM_WB_rd <= EX_MEM_rd;
    MEM_WB_reg_write <= EX_MEM_reg_write;
    MEM_WB_mem_to_reg <= EX_MEM_mem_to_reg;
end


// ================= WB =================
wire [31:0] wb_data;  //data return in to gesister file

assign wb_data = (MEM_WB_mem_to_reg) ? MEM_WB_mem_out : MEM_WB_result; //based on the control signal MEM_WB_mem_to_reg
                                                                       
always @(posedge clk1) begin                                            //which value to be written in register
    if (MEM_WB_reg_write && MEM_WB_rd != 0)
        regs[MEM_WB_rd] <= wb_data;  //here data is stored at rd(destination register place)
end

endmodule