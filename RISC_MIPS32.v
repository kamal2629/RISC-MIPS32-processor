module pipe_MIPS32(clock1 , clock2);
    input clock1 , clock2;              // two phase clock
    /* a subset of pipeline RSIC processor(MIPS32) which have five stages
    1. IF stage(instruction fetch stage)
    2. ID stage (instruction decode stage)
    3. EX stage (execution stage)
    4. MEM stage (memory stage)
    5. WB stage (Write back stage)
    There are 4 latches in between stages and registers created 
    will be created in this latches
    a) latch between IF stage and ID stage : IF_ID
    b) latch between ID stage and EX stage : ID_EX
    c) latch between EX stage and MEM stage : EX_MEM
    d) latch between MEM stage and WB stage : MEM_WB 
    register created are 
    >> PC(program counter) -- point to current instruction
    >> NPC(Next program counter) -- point to next instruction
    >> IR(Instruction register ) -- contains the instruction which is to be executed
    >> A and B register contains the data read from register bank(register bank has  two read ports and one write port)
    >> Imm(immediate value ) -- contains direct value rather than register in register bank
    >> type(type of instruction) -- (register - register type) or (register - memory type) or (load or store type instruction)
    >> cond(condition)-- check if there is branch or jump instruction so that if there is branch the loaded instruction in pipe should be discarded
    >> ALUout(Arithmetic logic unit out) -- output of any arithmetic operation stored in this register
    >> LMD -(load memory data) -- write data to memory
    IF_ID_IR means in latch between IF and ID stage the latch IF_ID contains register IR and ID_EX also have IR register
    because to pass the IR value of current instruction is to be passed to IF to ID to EX stage because in pipeline there are also
    other instruction which also have different value for same register for next instruction . So to prevent of data lost or overwritten
    we took latch and have same register  in different stages.
    */

    reg [31:0] PC , IF_ID_IR , IF_ID_NPC ;
    reg [31:0] ID_EX_IR , ID_EX_NPC , ID_EX_A , ID_EX_B , ID_EX_Imm;
    reg [2:0] ID_EX_type , EX_MEM_type , MEM_WB_type;
    reg [31:0] EX_MEM_IR , EX_MEM_ALUout , EX_MEM_B;
    reg        EX_MEM_cond;
    reg [31:0] MEM_WB_IR , MEM_WB_ALUout , MEM_WB_LMD;


    /*A register bank created which contains 32 registers (each of 32 bits in size)
    A memory created having 1024 memory locations (each memory location of 32 bits size) 
    */
    reg [31:0] Reg [0:31];        // Register bank (32 X 32)
    reg [31:0] Mem [0:1023] ;      // Memory (1024 X32)

    parameter ADD = 6'b000000 , SUB = 6'b000001 , AND = 6'b000010 , OR = 6'b000011 , SLT = 6'b000100 , MUL = 6'b000101 , HLT = 6'b111111 , LW = 6'b001000 ;
    parameter SW = 6'b001001 , ADDI = 6'b001010 , SUBI = 6'b001011 , SLTI = 6'b001100 , BNEQZ = 6'b001101 , BEQZ = 6'b001110;
    parameter RR_ALU = 3'b000 , RM_ALU = 3'b001 , LOAD = 3'b010 , STORE = 3'b011 , BRANCH = 3'b100 , HALT = 3'b101;
    
    reg HALTED;               // Set after HLT instruction is completed (in WB stage)

    reg TAKEN_BRANCH ;             // required to disable instruction after branch


    // Instruction Fetch stage(IF stage)

    always@(posedge clock1)
    begin
        if(HALTED == 0)
        begin
            if(((EX_MEM_IR[31:26] == BEQZ) && (EX_MEM_cond == 1)) || ((EX_MEM_IR[31:26] == BNEQZ) && (EX_MEM_cond == 0)))
            begin
                IF_ID_IR <= #2 Mem[EX_MEM_ALUout];
                TAKEN_BRANCH <= #2 1'b1;
                IF_ID_NPC <= #2 EX_MEM_ALUout + 1;
                PC <= #2 EX_MEM_ALUout + 1;
            end

            else
            begin
                IF_ID_IR <= #2 Mem[PC];
                IF_ID_NPC <= #2 PC + 1;
                PC <= #2 PC + 1;
            end
        end
    end


    // ID stage (Intsruction decode stage)

    always @(posedge clock2)
    begin
        if(HALTED == 0)
        begin
            if (IF_ID_IR[25:21] == 5'b00000) ID_EX_A <= 0;
            else ID_EX_A <= #2 Reg[IF_ID_IR[25:21]];               // source register rs

            if (IF_ID_IR[20:16] == 5'b00000) ID_EX_B <= 0;
            else ID_EX_B <= #2 Reg[IF_ID_IR[20:16]];               // source register rt      


            ID_EX_NPC <= #2 IF_ID_NPC;
            ID_EX_IR <= #2 IF_ID_IR;
            ID_EX_Imm <= #2 {{16{IF_ID_IR[15]}} , {IF_ID_IR[15:0]}};             // to extend 16 bit data to 32 bit(signed extension)


            case (IF_ID_IR[31:26])
                ADD , SUB , MUL , AND ,OR , SLT :    ID_EX_type <= #2 RR_ALU;
                ADDI ,SUBI ,SLTI:                    ID_EX_type <= #2 RM_ALU;
                LW :                                 ID_EX_type <= #2 LOAD;
                SW:                                  ID_EX_type <= #2 STORE;
                BNEQZ , BEQZ:                        ID_EX_type <= #2 BRANCH;
                HLT:                                 ID_EX_type <= #2 HALT;
                default:                             ID_EX_type <= #2 HALT;

            endcase
        end

        
    end



    // EX stage (Execution stage)
    always @(posedge clock1)
    begin
        if(HALTED == 0)
        begin
            EX_MEM_type <= #2 ID_EX_type ;
            EX_MEM_IR <= #2 ID_EX_IR;
            TAKEN_BRANCH <= #2 1'b0;

            case(ID_EX_type)
                RR_ALU : begin
                            case(ID_EX_IR[31:26])         //opcode
                                ADD : EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_B;
                                SUB : EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_B;
                                AND : EX_MEM_ALUout <= #2 ID_EX_A & ID_EX_B;
                                OR  : EX_MEM_ALUout <= #2 ID_EX_A | ID_EX_B;
                                SLT : EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_B;
                                MUL : EX_MEM_ALUout <= #2 ID_EX_A * ID_EX_B;
                                default : EX_MEM_ALUout <= #2 32'hxxxxx;

                            endcase
                         end
                
                RM_ALU : begin
                            case(ID_EX_IR[31:26])    //opcode
                                ADDI : EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_Imm;
                                SUBI : EX_MEM_ALUout <= #2 ID_EX_A - ID_EX_Imm;
                                SLTI : EX_MEM_ALUout <= #2 ID_EX_A < ID_EX_Imm;
                                default : EX_MEM_ALUout <= #2 32'hxxxxx;

                            endcase
                         end
                

                LOAD , STORE : begin
                                    EX_MEM_ALUout <= #2 ID_EX_A + ID_EX_Imm;
                                    EX_MEM_B <= #2 ID_EX_B; 

                               end

                BRANCH : begin
                            EX_MEM_ALUout <= #2 ID_EX_NPC + ID_EX_Imm;
                            EX_MEM_cond <= #2 (ID_EX_A == 0);
                         end
            endcase

        end
    end


    // MEM(memory stage)

    always @(posedge clock2)
    begin
        if(HALTED == 0)
        begin
           MEM_WB_type <= #2 EX_MEM_type; 
           MEM_WB_IR <=  #2 EX_MEM_IR;

           case(EX_MEM_type)
                RR_ALU , RM_ALU : MEM_WB_ALUout <= #2 EX_MEM_ALUout;

                LOAD : MEM_WB_LMD <= #2 Mem[EX_MEM_ALUout];

                STORE : begin
                            if(TAKEN_BRANCH == 0)              //disbale write
                                Mem[EX_MEM_ALUout] <= #2 EX_MEM_B;
                        end

           endcase
        end
    end


    // WB stage (Write stage)

    always @(posedge clock1)
    begin
       if(TAKEN_BRANCH == 0)     // disable write if branch taken
       begin
           case(MEM_WB_type)
                RR_ALU :   Reg[MEM_WB_IR[15:11]]  <=  #2 MEM_WB_ALUout;   // rd

                RM_ALU :   Reg[MEM_WB_IR[20:16]]  <=  #2 MEM_WB_ALUout;   // rt;

                LOAD :     Reg[MEM_WB_IR[20:16]]  <=  #2 MEM_WB_LMD;    //rt

                HALT :     HALTED <= #2 1'b1;

           endcase
       end
    end
    
    

endmodule