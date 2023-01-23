module ov5640_vga_640x480
(
    input   wire        sys_clk         , //系统时钟
    input   wire        sys_rst_n       , //系统复位，低电平有效
	input	wire		sw_1			,
    //摄像头接口    
    input   wire        ov5640_pclk     , //摄像头数据像素时钟
    input   wire        ov5640_vsync    , //摄像头场同步信号
    input   wire        ov5640_href     , //摄像头行同步信号
    input   wire [7:0]  ov5640_data     , //摄像头数据
    output  wire        ov5640_rst_n    , //摄像头复位信号，低电平有效
    output  wire        ov5640_pwdn     , //摄像头时钟选择信号, 1:使用摄像头自带的晶振
	output	wire		ov5640_xclk		, //
    output  wire        sccb_scl        , //摄像头SCCB_SCL线
    inout   wire        sccb_sda        , //摄像头SCCB_SDA线
	
    //SDRAM接口 
    output wire         sdram_clk       , //SDRAM 时钟
    output wire         sdram_cke       , //SDRAM 时钟使能
    output wire         sdram_cs_n      , //SDRAM 片选
    output wire         sdram_ras_n     , //SDRAM 行有效
    output wire         sdram_cas_n     , //SDRAM 列有效
    output wire         sdram_we_n      , //SDRAM 写有效
    output wire [1:0]   sdram_ba        , //SDRAM Bank地址
    output wire [1:0]   sdram_dqm       , //SDRAM 数据掩码
    output wire [12:0]  sdram_addr      , //SDRAM 地址
    inout  wire [15:0]  sdram_dq        , //SDRAM 数据
    //VGA接口
    output wire [7:0]	vga_red		    ,
    output wire [7:0]	vga_green	    ,
    output wire [7:0]	vga_blue	    ,
	output wire			hsync		    ,
	output wire			vsync		    ,
	output wire			vga_blank	    ,
	output wire         vga_sync        ,
	output wire         vga_clock   	
	
			
	
);

////
//\* Parameter and Internal Signal \//
////

//parameter define
parameter H_PIXEL = 24'd640 ; //水平方向像素个数,用于设置SDRAM缓存大小
parameter V_PIXEL = 24'd480 ; //垂直方向像素个数,用于设置SDRAM缓存大小
parameter	CNT_6MS  = 20'd300_000;
parameter	CNT_2MS  = 18'd100_000;
parameter	CNT_21MS = 22'd1_050_000;



//wire define
wire		clk_50m			;
wire        clk_100m        ; //100MHz时钟,SDRAM操作时钟
wire        clk_100m_shift  ; //100MHz时钟,SDRAM相位偏移时钟
wire        clk_25m         ; //25MHz时钟,提供给vga驱动时钟
wire        cfg_done        ; //摄像头初始化完成
wire        wr_en           ; //sdram写使能
wire [23:0] wr_data         ; //sdram写数据
wire        rd_en           ; //sdram读使能
wire [23:0] rd_data         ; //sdram读数据
wire        sdram_init_done ; //SDRAM初始化完成
wire        sys_init_done   ; //系统初始化完成(SDRAM初始化+摄像头初始化)
wire		locked			;
//wire		ov5640_pclk		;
wire		power_done		;
wire		clk_24m			;

//reg	define
reg [19:0]	cnt_6ms;
reg	[17:0]	cnt_2ms;
reg	[21:0]	cnt_21ms;

//cnt_6ms
always@(posedge sys_clk or negedge sys_rst_n)
	if (sys_rst_n == 1'b0)
		cnt_6ms <= 19'd0;
	else if (ov5640_pwdn == 1'b1 && sw_1 == 1'b1)
		cnt_6ms <= cnt_6ms + 1'b1;
	else
		cnt_6ms <= cnt_6ms;

assign ov5640_pwdn = (sys_rst_n== 1'b1 && cnt_6ms <= CNT_6MS)? 1'b1 : 1'b0;

//cnt_2ms
always@(posedge sys_clk or negedge sys_rst_n)
	if (sys_rst_n == 1'b0)
		cnt_2ms <= 17'd0;
	else if (ov5640_pwdn == 1'b0 && ov5640_rst_n == 1'b0)
		cnt_2ms <= cnt_2ms + 1'b1;
	else	
		cnt_2ms <= cnt_2ms;
		
assign ov5640_rst_n = (cnt_2ms >= CNT_2MS && sys_rst_n == 1'b1) ? 1'b1 : 1'b0;

//cnt_21ms
always@(posedge sys_clk or  negedge sys_rst_n)
	if (sys_rst_n == 1'b0)
		cnt_21ms <= 21'd0;
	else if (ov5640_rst_n == 1'b1 && power_done == 1'b0)
		cnt_21ms <= cnt_21ms + 1'b1;
	else
		cnt_21ms <= cnt_21ms;
		
assign power_done = (cnt_21ms >= CNT_21MS && sys_rst_n == 1'b1) ? 1'b1 : 1'b0;

//
////
//\* Main Code \//
////

//rst_n:复位信号(sys_rst_n & locked)
assign rst_n = (sys_rst_n & locked);

//sys_init_done:系统初始化完成(SDRAM初始化+摄像头初始化)
assign sys_init_done = sdram_init_done & cfg_done;

assign ov5640_xclk = clk_25m;
 
//assign ov5640_pclk = clk_56m;

//------------- clk_gen_inst -------------
clk_gen clk_gen_inst
(
    .areset		(~sys_rst_n),
	.inclk0     (sys_clk ),
    .c0         (clk_25m ),
	.c1			(clk_50m),
    .c2         (clk_100m),
    .c3         (clk_100m_shift ),
	.locked		(locked)
);

clk_gen_24Mhz	clk_gen_24Mhz_inst (
	.areset (ov5640_pwdn),
	.inclk0 ( sys_clk ),
	.c0 ( clk_24m )
	);

//------------- ov5640_top_inst -------------
ov5640_top ov5640_top_inst(

    .sys_clk            (clk_25m 	   ), 	  //系统时钟
    .sys_rst_n          (power_done	   ), 	  //复位信号
    .sys_init_done      (sys_init_done ), 	  //系统初始化完成(SDRAM + 摄像头)

    .ov5640_pclk        (ov5640_pclk ),      //摄像头像素时钟
    .ov5640_href        (ov5640_href ),      //摄像头行同步信号
    .ov5640_vsync       (ov5640_vsync ),     //摄像头场同步信号
    .ov5640_data        (ov5640_data ),      //摄像头图像数据

    .cfg_done           (cfg_done     ),      //寄存器配置完成
    .sccb_scl           (sccb_scl     ),      //SCL
    .sccb_sda           (sccb_sda     ),      //SDA
    .ov5640_wr_en       (wr_en 	      ),      //图像数据有效使能信号
    .ov5640_data_out    (wr_data      )      //图像数据
	
	//.ov5640_pwdn		(ov5640_pwdn  ),
	//.ov5640_xclk		(ov5640_xclk  ),
	//.ov5640_rst_n     (ov5640_rst_n )
	
);

//------------- sdram_top_inst -------------
sdram_top sdram_top_inst(
    .sys_clk            (clk_100m ), //sdram 控制器参考时钟
    .clk_out            (clk_100m_shift ), //用于输出的相位偏移时钟
    .sys_rst_n          (rst_n ), //系统复位
    //用户写端口
    .wr_fifo_wr_clk     (ov5640_pclk ), //写端口FIFO: 写时钟
    .wr_fifo_wr_req     (wr_en ), //写端口FIFO: 写使能
    .wr_fifo_wr_data    (wr_data ), //写端口FIFO: 写数据
    .sdram_wr_b_addr    (24'd0 ), //写SDRAM的起始地址
    .sdram_wr_e_addr    (H_PIXEL*V_PIXEL), //写SDRAM的结束地址
    .wr_burst_len       (10'd512 ), //写SDRAM时的数据突发长度
    .wr_rst             (~rst_n ), //写端口复位: 复位写地址,清空写FIFO
    //用户读端口
    .rd_fifo_rd_clk     (clk_25m ), //读端口FIFO: 读时钟
    .rd_fifo_rd_req     (rd_en ), //读端口FIFO: 读使能
    .rd_fifo_rd_data    (rd_data ), //读端口FIFO: 读数据
    .sdram_rd_b_addr    (24'd0 ), //读SDRAM的起始地址
    .sdram_rd_e_addr    (H_PIXEL*V_PIXEL), //读SDRAM的结束地址
    .rd_burst_len       (10'd512 ), //从SDRAM中读数据时的突发长度
    .rd_rst             (~rst_n ), //读端口复位: 复位读地址,清空读FIFO
    //用户控制端口
    .read_valid         (1'b1 ), //SDRAM 读使能
    .pingpang_en        (1'b1 ), //SDRAM 乒乓操作使能
    .init_end           (sdram_init_done), //SDRAM 初始化完成标志
    //SDRAM 芯片接口
    .sdram_clk          (sdram_clk ), //SDRAM 芯片时钟
    .sdram_cke          (sdram_cke ), //SDRAM 时钟有效
    .sdram_cs_n         (sdram_cs_n ), //SDRAM 片选
    .sdram_ras_n        (sdram_ras_n ), //SDRAM 行有效
    .sdram_cas_n        (sdram_cas_n ), //SDRAM 列有效
    .sdram_we_n         (sdram_we_n ), //SDRAM 写有效
    .sdram_ba           (sdram_ba ), //SDRAM Bank地址
    .sdram_addr         (sdram_addr ), //SDRAM 行/列地址
    .sdram_dq           (sdram_dq  ), //SDRAM 数据
    .sdram_dqm          (sdram_dqm ) //SDRAM 数据掩码
);

//------------- vga_ctrl_inst -------------
vga_ctrl vga_ctrl_inst
(
	.vga_clk		(clk_25m),
	.sys_rst_n		(rst_n),
	.pix_data		(rd_data),
	
	.address		(),
	.pix_x			(),
	.pix_y			(),
	.rgb_valid		(),
	.pix_data_req	(rd_en),
	.vga_red		(vga_red	 ),
	.vga_green		(vga_green	 ),
	.vga_blue		(vga_blue	 ),
	.hsync			(hsync		 ),
	.vsync			(vsync		 ),
	.vga_sync		(vga_sync	 ),
	.vga_blank		(vga_blank	 ),
	.vga_clock	    (vga_clock	 )
);



endmodule