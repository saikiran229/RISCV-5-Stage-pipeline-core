`timescale 1ns / 1ps


// 1. Core Definitions & Opcodes

typedef enum logic [6:0] {
    OP_RTYPE = 7'b0110011,
    OP_ITYPE = 7'b0010011,
    OP_LOAD  = 7'b0000011,
    OP_STORE = 7'b0100011,
    OP_BRANCH= 7'b1100011
} opcode_t;


// 2. Interactive Memories (IMEM & DMEM)

module InstructionMemory (
    input  logic [31:0] pc,
    output logic [31:0] instruction
);
    logic [31:0] memory [0:255];
    
    // INTERACTIVE ELEMENT: Loads your custom program!
    initial begin
        $readmemh("program.mem", memory);
    end

    // Word-aligned read (pc / 4)
    assign instruction = memory[pc[9:2]];
endmodule


// REPLACED: Data Memory (Removed initial block)

module DataMemory (
    input  logic        clk,
    input  logic        mem_write,
    input  logic        mem_read,
    input  logic [31:0] addr,
    input  logic [31:0] write_data,
    output logic [31:0] read_data
);
    logic [31:0] memory [0:255];

    assign read_data = (mem_read) ? memory[addr[9:2]] : 32'b0;

    always_ff @(posedge clk) begin
        if (mem_write)
            memory[addr[9:2]] <= write_data;
    end
endmodule


// REPLACED: Register File (Removed initial block)

module RegFile (
    input  logic        clk,
    input  logic        we,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [31:0] wd,
    output logic [31:0] rd1,
    output logic [31:0] rd2
);
    logic [31:0] registers [31:0];

    // Internal Forwarding: Write in first half of cycle, read in second
    // Note: rs1/rs2 == 0 ensures register x0 is ALWAYS hardwired to 0.
    assign rd1 = (rs1 == 0) ? 32'b0 : ((rs1 == rd && we) ? wd : registers[rs1]);
    assign rd2 = (rs2 == 0) ? 32'b0 : ((rs2 == rd && we) ? wd : registers[rs2]);

    always_ff @(posedge clk) begin
        if (we && rd != 0)
            registers[rd] <= wd;
    end
endmodule
module ALU (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [3:0]  alu_ctrl,
    output logic [31:0] result,
    output logic        zero
);
    always_comb begin
        case (alu_ctrl)
            4'b0000: result = a + b;       // ADD
            4'b1000: result = a - b;       // SUB
            default: result = a + b;       // Default ADD (for mem addresses)
        endcase
        zero = (result == 32'b0);
    end
endmodule


// 4. Upgraded Top Level RISC-V Core

module RISCV_Core (
    input logic clk,
    input logic rst
);
    // -- Stage IF --
    logic [31:0] pc, next_pc, instruction;
    logic pc_src; // Branch decision
    logic [31:0] branch_target;

    InstructionMemory imem (.pc(pc), .instruction(instruction));
    
    assign next_pc = pc_src ? branch_target : (pc + 4);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) pc <= 32'b0;
        else     pc <= next_pc;
    end

    // -- IF/ID Pipeline Register --
    logic [31:0] if_id_pc, if_id_inst;
    always_ff @(posedge clk) begin
        if (rst || pc_src) begin // Flush on branch
            if_id_pc <= 32'b0;
            if_id_inst <= 32'b0; // NOP
        end else begin
            if_id_pc <= pc;
            if_id_inst <= instruction;
        end
    end

    // -- Stage ID --
    logic [31:0] reg_rd1, reg_rd2, imm_ext;
    logic [4:0]  rs1, rs2, rd;
    logic [6:0]  opcode;
    
    assign opcode = if_id_inst[6:0];
    assign rs1 = if_id_inst[19:15];
    assign rs2 = if_id_inst[24:20];
    assign rd  = if_id_inst[11:7];
    
    // Immediate Generation (I-type, S-type, B-type simplified)
    always_comb begin
        if (opcode == OP_STORE) imm_ext = {{20{if_id_inst[31]}}, if_id_inst[31:25], if_id_inst[11:7]}; // S-Type
        else if (opcode == OP_BRANCH) imm_ext = {{20{if_id_inst[31]}}, if_id_inst[7], if_id_inst[30:25], if_id_inst[11:8], 1'b0}; // B-Type
        else imm_ext = {{20{if_id_inst[31]}}, if_id_inst[31:20]}; // I-Type
    end

    // Write-back signals
    logic reg_write_wb; 
    logic [31:0] wb_data;
    logic [4:0]  wb_rd;
    
    RegFile rf (
        .clk(clk), .we(reg_write_wb), .rs1(rs1), .rs2(rs2), 
        .rd(wb_rd), .wd(wb_data), .rd1(reg_rd1), .rd2(reg_rd2)
    );

    // -- ID/EX Pipeline Register --
    logic [31:0] id_ex_rd1, id_ex_rd2, id_ex_imm, id_ex_pc;
    logic [4:0]  id_ex_rd;
    logic [6:0]  id_ex_opcode;
    
    always_ff @(posedge clk) begin
        if (rst || pc_src) begin // Flush on branch
            id_ex_rd1 <= 32'b0; id_ex_rd2 <= 32'b0; id_ex_imm <= 32'b0;
            id_ex_rd <= 5'b0; id_ex_opcode <= 7'b0; id_ex_pc <= 32'b0;
        end else begin
            id_ex_rd1 <= reg_rd1; id_ex_rd2 <= reg_rd2; id_ex_imm <= imm_ext;
            id_ex_rd <= rd; id_ex_opcode <= opcode; id_ex_pc <= if_id_pc;
        end
    end

    // -- Stage EX --
    logic [31:0] alu_in_b, alu_result;
    logic alu_zero;

    // ALUSrc Mux: Select between Register 2 or Immediate
    assign alu_in_b = (id_ex_opcode == OP_ITYPE || id_ex_opcode == OP_LOAD || id_ex_opcode == OP_STORE) ? id_ex_imm : id_ex_rd2;

    ALU alu_inst (
        .a(id_ex_rd1), .b(alu_in_b), 
        .alu_ctrl((id_ex_opcode == OP_BRANCH) ? 4'b1000 : 4'b0000), // SUB for branch compare, else ADD
        .result(alu_result), .zero(alu_zero)
    );

    // Branch Target Calculation
    assign branch_target = id_ex_pc + id_ex_imm;
    assign pc_src = (id_ex_opcode == OP_BRANCH) & alu_zero;

    // -- EX/MEM Pipeline Register --
    logic [31:0] ex_mem_alu_result, ex_mem_rd2;
    logic [4:0]  ex_mem_rd;
    logic [6:0]  ex_mem_opcode;

    always_ff @(posedge clk) begin
        if (rst) begin
            ex_mem_alu_result <= 32'b0; ex_mem_rd2 <= 32'b0;
            ex_mem_rd <= 5'b0; ex_mem_opcode <= 7'b0;
        end else begin
            ex_mem_alu_result <= alu_result;
            ex_mem_rd2 <= id_ex_rd2;
            ex_mem_rd <= id_ex_rd;
            ex_mem_opcode <= id_ex_opcode;
        end
    end

    // -- Stage MEM --
    logic [31:0] mem_read_data;
    logic mem_write, mem_read;
    
    assign mem_write = (ex_mem_opcode == OP_STORE);
    assign mem_read  = (ex_mem_opcode == OP_LOAD);

    DataMemory dmem (
        .clk(clk), .mem_write(mem_write), .mem_read(mem_read),
        .addr(ex_mem_alu_result), .write_data(ex_mem_rd2), .read_data(mem_read_data)
    );

    // -- MEM/WB Pipeline Register --
    logic [31:0] mem_wb_alu_result, mem_wb_mem_data;
    logic [4:0]  mem_wb_rd;
    logic [6:0]  mem_wb_opcode;

    always_ff @(posedge clk) begin
        if (rst) begin
            mem_wb_alu_result <= 32'b0; mem_wb_mem_data <= 32'b0;
            mem_wb_rd <= 5'b0; mem_wb_opcode <= 7'b0;
        end else begin
            mem_wb_alu_result <= ex_mem_alu_result;
            mem_wb_mem_data <= mem_read_data;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_opcode <= ex_mem_opcode;
        end
    end

    // -- Stage WB --
    assign reg_write_wb = (mem_wb_opcode == OP_RTYPE || mem_wb_opcode == OP_ITYPE || mem_wb_opcode == OP_LOAD);
    assign wb_data = (mem_wb_opcode == OP_LOAD) ? mem_wb_mem_data : mem_wb_alu_result;
    assign wb_rd = mem_wb_rd;

endmodule
