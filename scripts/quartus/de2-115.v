/* wrapper for Altera DE2-115 board

Memory map
0000'0000h main memory (BRAM, 64 KiByte)
0000'FE00h start address of boot loader

CSR
BC0h       UART
BC1h       LEDs
*/


module top (
    input CLOCK_50,
    input UART_RXD,
    output UART_TXD,
    output [17:0] LEDR
);
    localparam integer CLOCK_RATE = 50_000_000;
    localparam integer BAUD_RATE = 115200;

    reg [5:0] reset_counter = 0;
    wire rstn = &reset_counter;
    always @(posedge CLOCK_50) begin
        reset_counter <= reset_counter + !rstn;
    end

    wire        mem_valid;
    wire        mem_write;
    wire  [3:0] mem_wmask;
    wire [31:0] mem_wdata;
    wire        mem_wgrubby;
    wire [31:0] mem_addr;
    wire [31:0] mem_rdata;
    wire        mem_rgrubby = 0;


    wire        IDsValid;
    wire [31:0] IDsRData;
    wire        CounterValid;
    wire [31:0] CounterRData;
    wire        UartValid;
    wire [31:0] UartRData;
    wire        LedsValid;
    wire [31:0] LedsRData;

    wire        irq_software = 0;
    wire        irq_timer = 0;
    wire        irq_external = 0;
    wire        retired;
    wire        csr_read;
    wire [2:0]  csr_modify;
    wire [31:0] csr_wdata;
    wire [11:0] csr_addr;
    wire [31:0] csr_rdata = IDsRData | CounterRData | UartRData;
    wire        csr_valid = IDsValid | CounterValid | UartValid;

    CsrIDs #(
        .BASE_ADDR(12'hFC0),
        .KHZ(CLOCK_RATE/1000)
    ) csr_ids (
        .clk    (clk),
        .rstn   (rstn),

        .read   (csr_read),
        .modify (csr_modify),
        .wdata  (csr_wdata),
        .addr   (csr_addr),
        .rdata  (IDsRData),
        .valid  (IDsValid),

        .AVOID_WARNING()
    );

    CsrCounter counter (
        .clk    (CLOCK_50),
        .rstn   (rstn),

        .read   (csr_read),
        .modify (csr_modify),
        .wdata  (csr_wdata),
        .addr   (csr_addr),
        .rdata  (CounterRData),
        .valid  (CounterValid),

        .retired(retired),

        .AVOID_WARNING()
    );

    CsrUartChar #(
        .BASE_ADDR(12'hBC0),
        .CLOCK_RATE(CLOCK_RATE),
        .BAUD_RATE(BAUD_RATE)
    ) uart (
        .clk    (CLOCK_50),
        .rstn   (rstn),

        .read   (csr_read),
        .modify (csr_modify),
        .wdata  (csr_wdata),
        .addr   (csr_addr),
        .rdata  (UartRData),
        .valid  (UartValid),

        .rx     (UART_RXD),
        .tx     (UART_TXD),

        .AVOID_WARNING()
    );

    CsrPinsOut #(
        .BASE_ADDR(12'hBC1),
        .COUNT(18)
    ) csr_leds (
        .clk    (CLOCK_50),
        .rstn   (rstn),

        .read   (csr_read),
        .modify (csr_modify),
        .wdata  (csr_wdata),
        .addr   (csr_addr),
        .rdata  (LedsRData),
        .valid  (LedsValid),

        .pins   (LEDR),

        .AVOID_WARNING()
    );

    Pipeline #(
        .START_PC       (32'h_0000_fe00)
    ) pipe (
        .clk            (CLOCK_50),
        .rstn           (rstn),

        .irq_software   (irq_software),
        .irq_timer      (irq_timer),
        .irq_external   (irq_external),
        .retired        (retired),

        .csr_read       (csr_read),
        .csr_modify     (csr_modify),
        .csr_wdata      (csr_wdata),
        .csr_addr       (csr_addr),
        .csr_rdata      (csr_rdata),
        .csr_valid      (csr_valid),

        .mem_valid      (mem_valid),
        .mem_write      (mem_write),
        .mem_wmask      (mem_wmask),
        .mem_wdata      (mem_wdata),
        .mem_wgrubby    (mem_wgrubby),
        .mem_addr       (mem_addr),
        .mem_rdata      (mem_rdata),
        .mem_rgrubby    (mem_rgrubby)
    );

    BRAMMemory mem (
        .clk    (CLOCK_50),
        .write  (mem_write),
        .wmask  (mem_wmask),
        .wdata  (mem_wdata),
        .addr   (mem_addr[15:2]),
        .rdata  (mem_rdata)
    );
endmodule


module BRAMMemory (
    input clk, 
    input write,
    input [3:0] wmask,
    input [31:0] wdata,
    input [13:0] addr,
    output reg [31:0] rdata
);
    //reg [31:0] mem [0:'h3fff];
    reg [7:0] mem0 [0:'h3fff];
    reg [7:0] mem1 [0:'h3fff];
    reg [7:0] mem2 [0:'h3fff];
    reg [7:0] mem3 [0:'h3fff];

    initial begin
//        $readmemh("bootloader.hex", mem);
        $readmemh("mem0.hex", mem0);
        $readmemh("mem1.hex", mem1);
        $readmemh("mem2.hex", mem2);
        $readmemh("mem3.hex", mem3);
            // bootloader code is the same as on other platforms, but at the
            // beginning there must be '@3f80' to load the code at the correct
            // start adress
    end

    always @(posedge clk) begin
        //rdata <= mem[addr];
        rdata <= {mem3[addr], mem2[addr], mem1[addr], mem0[addr]};
        if (write) begin
            //if (wmask[0]) mem[addr][7:0] <= wdata[7:0];
            //if (wmask[1]) mem[addr][15:8] <= wdata[15:8];
            //if (wmask[2]) mem[addr][23:16] <= wdata[23:16];
            //if (wmask[3]) mem[addr][31:24] <= wdata[31:24];
            if (wmask[0]) mem0[addr] <= wdata[7:0];
            if (wmask[1]) mem1[addr] <= wdata[15:8];
            if (wmask[2]) mem2[addr] <= wdata[23:16];
            if (wmask[3]) mem3[addr] <= wdata[31:24];
        end
    end
endmodule


// SPDX-License-Identifier: ISC
