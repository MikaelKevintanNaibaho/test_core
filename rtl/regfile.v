/***************************************************************/
// Register file
//
// * 32 x 32-bit registers
// * two asynchronous read ports
// * one synchronous write ports
/***************************************************************/

module regfile(
    input clk,
    
    // write port
    input           write_en,
    input [4:0]     write_addr,
    input [31:0]    write_data,

    // read port 1
    input [4:0]     read_addr1,
    output [31:0]   read_data1,

    // read port 2
    input [4:0]     read_addr2,
    output [31:0]   read_data2

);
    reg [31:0] registers[31:0];
    
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            registers[i] = 32'b0;
        end
    end

    // synchronous write port
    always @(posedge clk) begin
        if (write_en && write_addr != 5'b0) begin
            registers[write_addr] <= write_data;
        end
    end

    // asynchronous read ports
    // register 0 is hardwired to zero
    assign read_data1 = (read_addr1 == 5'b0) ? 32'b0 : registers[read_addr1];
    assign read_data2 = (read_addr2 == 5'b0) ? 32'b0 : registers[read_addr2];

endmodule
