module MIPS32_ADDI_testbench1;
    reg clock1 , clock2;
    integer k;

    pipe_MIPS32  mips(clock1 , clock2);

    initial
    begin
       clock1 = 1'b0;
       clock2 = 1'b0;
       repeat(20)
            begin
                // two phase clock 

                #5 clock1 = 1 ;
                #5 clock1 = 0 ;
                #5 clock2 = 1;
                #5 clock2 = 0;
                
            end 
    end

    initial
    begin
        for(k = 0 ; k < 31 ; k = k +1)
        begin
           mips.Reg[k] = k;  
        end

        mips.Mem[0] = 32'h2801000a;   // ADDI R1,R0,10
        mips.Mem[1] = 32'h28020014;   // ADDI R2,R0,20
        mips.Mem[2] = 32'h28030019;  // ADDI R3,R0,25
        mips.Mem[3] = 32'h0ce77800;  // OR R7,R7,R7         -- dummy instruction
        mips.Mem[4] = 32'h0ce77800;  // OR R7,R7,R7         -- dummy instruction
        mips.Mem[5] = 32'h00222000;  // ADD R4,R1,R2
        mips.Mem[6] = 32'h0ce77800;  // OR R7,R7,R7         -- dummy instruction
        mips.Mem[7] = 32'h00832800;  // ADD R5,R4,R3   
        mips.Mem[8] = 32'hfc000000;

        mips.HALTED = 1'b0;
        mips.PC = 1'b0;
        mips.TAKEN_BRANCH = 1'b0; 

        #280
        for(k = 0 ; k < 6 ; k = k+1)
        begin
            $display("R%1d - %2d",k,mips.Reg[k]);
        end      

    end

    initial
    begin
        $dumpfilefile("pipe_MIPS32.vcd");
        $dumpvars(0,MIPS32_ADDI_testbench1);
        #300 $finish;
    end

endmodule