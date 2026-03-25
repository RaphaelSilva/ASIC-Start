module counter2b(clk, rst, set, cen, blk, cnt, dp7);
// Sinais de Controle
    input       clk;        // relógio do sistema (clock)
    input       rst;        // ajusta contador de 2 bits para zero (b00)
    input       set;        // ajusta contador de 2 bits para três (b11)
    input       cen;        // captura de dados (clock enable)   
    output      blk;        // saída de relógio (blink)
 
// Sinais de Dados 
    output reg [1:0] cnt;   // contador de 2 bits
    output     [6:0] dp7;   // saída para display de 7 segmentos
 
// Descrição da arquitetura
    assign blk = clk;       // redireciona entrada clk para a saída blk
    // Bloco de controle do contador de 2 bits
    always@(posedge clk) begin
        if(rst)
            cnt <= 2'b00;   // ajusta todos os bits do contador para '0'
        else if(set)
            cnt <= 2'b11;   // ajusta todos os bits do contador para '1'
        else if (!cen)
            cnt <= cnt+1;   // incrementa contador cnt em um
    end
	
endmodule:counter2b