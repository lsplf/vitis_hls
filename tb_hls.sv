`timescale  1ns / 1ps

module tb_hls_accl;

    timeunit 1ns;
    timeprecision 1ps;

    parameter PERIOD = 10;
    parameter HSIZE = 128;
    parameter VSIZE = 128;
    parameter HBLANK = 64;
    parameter VBLANK = 4;


    reg   dvld_i        ; 
    reg   [127:0] data_i;
    reg   [31:0]  vsize ;
    reg   [31:0]  hsize ;
    reg   clk           ;
    reg   rst           ;
    reg   ap_start      ;

    // sobel_accel Outputs
    wire  [127:0]  sx_data_o ;
    wire  [127:0]  sy_data_o ;

    wire  sx_dvld_o          ;
    wire  ap_done            ;
    wire  sy_dvld_o          ;
    wire  ap_ready           ;
    wire  ap_idle            ;

    // TB variables

    reg     [31 : 0]    hcnt = 0;
    reg     [31 : 0]    vcnt = 0;

    logic [7:0] img[HSIZE*VSIZE];
    integer i = 0;
    integer j = 0;
    integer img_fp = 0;
    integer sx_fp = 0;
    integer sy_fp = 0;
    logic  [127:0]  sx_col_data;
    logic  [127:0]  sy_col_data;

    parameter PIX_CYCLE = 16;
    wire sobel_ready;

    sobel_accel  u_sobel_accel (
        .img_inp_TDATA           ( data_i                ),
        .rows                    ( vsize                 ),
        .cols                    ( hsize                 ),
        .ap_clk                  ( clk                   ),
        .ap_rst_n                ( ~rst                  ),
        .img_inp_TVALID          ( dvld_i                ),
        .img_inp_TREADY          ( sobel_ready           ),
        .ap_start                ( ap_start              ),

        .img_out1_TDATA          ( sx_data_o             ),
        .img_out2_TDATA          ( sy_data_o             ),
        .img_out1_TVALID         ( sx_dvld_o             ),
        .img_out1_TREADY         ( 1'b1                  ),
        .ap_done                 ( ap_done               ),
        .img_out2_TVALID         ( sy_dvld_o             ),
        .img_out2_TREADY         ( 1'b1                  ),
        .ap_ready                ( ap_ready              ),
        .ap_idle                 ( ap_idle               )
    );

    wire dvld_o = sx_dvld_o & sy_dvld_o;

    reg [11:0] hcnt_o, vcnt_o;
    always @(posedge clk) begin
        if(rst) begin
            hcnt_o <= 0;
        end
        else if(dvld_o && hcnt_o == HSIZE/PIX_CYCLE - 1) begin
            hcnt_o <= 0;
        end
        else if(dvld_o) begin
            hcnt_o <= hcnt_o + 1;
        end
    end

    always @(posedge clk) begin
        if(rst) begin
            vcnt_o <= 0;
        end
        else if(dvld_o && hcnt_o == HSIZE/PIX_CYCLE - 1 && vcnt_o == VSIZE - 1) begin
            vcnt_o <= 0;
        end
        else if(dvld_o && hcnt_o == HSIZE/PIX_CYCLE - 1 ) begin
            vcnt_o <= vcnt_o + 1;
        end
    end

    wire feof_o = (dvld_o && hcnt_o == HSIZE/PIX_CYCLE - 1 && vcnt_o == VSIZE - 1)? 1'b1 : 1'b0;

    initial begin
        img_fp = $fopen("D:/Proj/VIVADO/ip_proj/hls_accl/src/sobel_img.txt", "r");
        for(i = 0; i < VSIZE; i=i+1) begin
            for(j = 0; j < HSIZE; j = j + 1) begin
                $fscanf(img_fp, "%d", img[i*HSIZE + j]); 
            end
        end
    end

    always @(posedge clk)
    begin
        if(rst) begin
            hcnt <= 0;
        end
        else if(sobel_ready == 1'b1 && hcnt == HSIZE / PIX_CYCLE - 1) begin
            hcnt <= 0;
        end
        else if(sobel_ready == 1'b1 && hcnt < HSIZE / PIX_CYCLE - 1) begin
            hcnt <= hcnt + 1; 
        end
    end

    always @(posedge clk)
    begin
        if(rst) begin
            vcnt <= 0;
        end
        else if(sobel_ready == 1'b1 && hcnt == HSIZE / PIX_CYCLE - 1 && vcnt == VSIZE - 1) begin
            vcnt <= 0;
        end
        else if(sobel_ready == 1'b1 && hcnt == HSIZE / PIX_CYCLE - 1) begin
            vcnt <= vcnt + 1; 
        end
    end

    always @(posedge clk) 
    begin
        if(rst) begin
            data_i <= 0;
            dvld_i <= 1'b0;
        end    
        else if(sobel_ready == 1'b1 && hcnt <= HSIZE / PIX_CYCLE - 1 && vcnt <= VSIZE - 1) begin
            dvld_i <= 1'b1;
            data_i <= { img[vcnt * HSIZE + hcnt*PIX_CYCLE + 15],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 14],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 13],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 12],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 11],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 10],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 9],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 8],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 7],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 6],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 5],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 4],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 3],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 2],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 1],
                        img[vcnt * HSIZE + hcnt*PIX_CYCLE + 0]};
        end
        else begin
            data_i <= 0;
            dvld_i <= 1'b0;
        end
    end

    //monitor task
    task monitor();
        begin
            sx_fp = $fopen("D:/Proj/VIVADO/ip_proj/hls_accl/src/sx.txt", "w");
            sy_fp = $fopen("D:/Proj/VIVADO/ip_proj/hls_accl/src/sy.txt", "w");
            while(1) begin
                @(posedge clk);
                if((dvld_o == 1'b1) && (feof_o == 1'b0)) begin
                    sx_col_data = sx_data_o;
                    sy_col_data = sy_data_o;
                    for(integer m = 0; m < PIX_CYCLE; m=m+1) begin
                        $fwrite(sx_fp, "%d\n", $signed(sx_col_data[(m+1)*8 - 1 -: 8]));
                        $fwrite(sy_fp, "%d\n", $signed(sy_col_data[(m+1)*8 - 1 -: 8]));
                    end
                    
                end
                else if((dvld_o == 1'b1) && (feof_o == 1'b1)) begin
                    sx_col_data = sx_data_o;
                    sy_col_data = sy_data_o;
                    for(integer m = 0; m < PIX_CYCLE; m=m+1) begin
                        $fwrite(sx_fp, "%d\n", $signed(sx_col_data[(m+1)*8 - 1 -: 8]));
                        $fwrite(sy_fp, "%d\n", $signed(sy_col_data[(m+1)*8 - 1 -: 8]));
                    end
                    $fclose(sx_fp);
                    $fclose(sy_fp);
                    @(posedge clk);
                    $finish;
                end
                else;         
            end
        end
    endtask

    // main task
    task main;
        begin

            // clock and reset initializtion
            vsize = VSIZE;
            hsize = HSIZE;
            dvld_i = 1'b0;
            data_i = 0;
            ap_start = 1'b0;
            clk = 1'b0;
            rst  =  1;
            repeat(200) @(posedge clk);
            rst  =  0;
            ap_start = 1'b1;
            fork 
                // monitior the output of dut
                monitor();
            join
        end
    endtask

    // clock generation
    always #(PERIOD/2) clk = ~clk;

    // TB entry
    initial begin
        main();
    end

endmodule