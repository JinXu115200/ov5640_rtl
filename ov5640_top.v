module  ov5640_top(

    input   wire            sys_clk         ,   //系统时钟
    input   wire            sys_rst_n       ,   //复位信号
    input   wire            sys_init_done   ,   //系统初始化完成(SDRAM + 摄像头)

    input   wire            ov5640_pclk     ,   //摄像头像素时钟
    input   wire            ov5640_href     ,   //摄像头行同步信号
    input   wire            ov5640_vsync    ,   //摄像头场同步信号
    input   wire    [ 7:0]  ov5640_data     ,   //摄像头图像数据

    output  wire            cfg_done        ,   //寄存器配置完成
    output  wire            sccb_scl        ,   //SCL
    inout   wire            sccb_sda        ,   //SDA
    output  wire            ov5640_wr_en    ,   //图像数据有效使能信号
    output  wire    [15:0]  ov5640_data_out ,   //图像数据
	output	wire			ov5640_pwdn		,
	//output	wire		ov5640_xclk		,
	output	wire			ov5640_rst_n	
	
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//
//parameter define
parameter    SLAVE_ADDR =  7'h3c    	  ; // 器件地址(SLAVE_ADDR)
parameter    BIT_CTRL   =  1'b1           ; // 字地址位控制参数(16b/8b)
parameter    CLK_FREQ   =  26'd50_000_000 ; // i2c_dri模块的驱动时钟频率(CLK_FREQ)
parameter    I2C_FREQ   =  18'd250_000    ; // I2C的SCL时钟频率

parameter	CNT_6MS  = 20'd600_000;
parameter	CNT_2MS  = 18'd200_000;
parameter	CNT_21MS = 22'd2_100_000;


//wire  define
wire            cfg_end     ;
wire            cfg_start   ;
wire    [23:0]  cfg_data    ;
wire            cfg_clk     ;
wire			power_done	;



//reg	define
reg [19:0]	cnt_6ms;
reg	[17:0]	cnt_2ms;
reg	[21:0]	cnt_21ms;

//cnt_6ms
always@(posedge sys_clk or negedge sys_rst_n)
	if (sys_rst_n == 1'b0)
		cnt_6ms <= 19'd0;
	else if (ov5640_pwdn == 1'b1)
		cnt_6ms <= cnt_6ms + 1'b1;
	else
		cnt_6ms <= cnt_6ms;

assign ov5640_pwdn = (cnt_6ms <= CNT_6MS)? 1'b1 : 1'b0;

//cnt_2ms
always@(posedge sys_clk or negedge sys_rst_n)
	if (sys_rst_n == 1'b0)
		cnt_2ms <= 17'd0;
	else if (ov5640_pwdn == 1'b0 && ov5640_rst_n == 1'b0)
		cnt_2ms <= cnt_2ms + 1'b1;
	else	
		cnt_2ms <= cnt_2ms;
		
assign ov5640_rst_n = (cnt_2ms >= CNT_2MS) ? 1'b1 : 1'b0;

//cnt_21ms
always@(posedge sys_clk or  negedge sys_rst_n)
	if (sys_rst_n == 1'b0)
		cnt_21ms <= 21'd0;
	else if (ov5640_rst_n == 1'b1 && power_done == 1'b0)
		cnt_21ms <= cnt_21ms + 1'b1;
	else
		cnt_21ms <= cnt_21ms;
		
assign power_done = (cnt_21ms >= CNT_21MS) ? 1'b1 : 1'b0;


//********************************************************************//
//*************************** Instantiation **************************//
//********************************************************************//
//------------- i2c_ctrl_inst -------------
i2c_ctrl
#(
    .DEVICE_ADDR    (SLAVE_ADDR ), //i2c设备器件地址
    .SYS_CLK_FREQ   (CLK_FREQ   ), //i2c_ctrl模块系统时钟频率
    .SCL_FREQ       (I2C_FREQ   )  //i2c的SCL时钟频率
)
i2c_ctrl_inst
(
    .sys_clk     (sys_clk       ),   //输入系统时钟,50MHz
    .sys_rst_n   (power_done    ),   //输入复位信号,低电平有效
    .wr_en       (1'b1          ),   //输入写使能信号
    .rd_en       (              ),   //输入读使能信号
    .i2c_start   (cfg_start     ),   //输入i2c触发信号
    .addr_num    (BIT_CTRL      ),   //输入i2c字节地址字节数
    .byte_addr   (cfg_data[23:8]),   //输入i2c字节地址
    .wr_data     (cfg_data[7:0] ),   //输入i2c设备数据

    .rd_data     (              ),   //输出i2c设备读取数据
    .i2c_end     (cfg_end       ),   //i2c一次读/写操作完成
    .i2c_clk     (cfg_clk       ),   //i2c驱动时钟
    .i2c_scl     (sccb_scl      ),   //输出至i2c设备的串行时钟信号scl
    .i2c_sda     (sccb_sda      )    //输出至i2c设备的串行数据信号sda

);

//------------- ov5640_cfg_inst -------------
ov5640_cfg  ov5640_cfg_inst(

    .sys_clk        (cfg_clk    ),   //系统时钟,由iic模块传入
    .sys_rst_n      (sys_rst_n  ),   //系统复位,低有效
    .cfg_end        (cfg_end    ),   //单个寄存器配置完成
	.power_done	    (power_done ),

    .cfg_start      (cfg_start  ),   //单个寄存器配置触发信号
    .cfg_data       (cfg_data   ),   //ID,REG_ADDR,REG_VAL
    .cfg_done       (cfg_done   )    //寄存器配置完成
);

//------------- ov5640_data_inst -------------
ov5640_data ov5640_data_inst(

    .sys_rst_n          (sys_rst_n & sys_init_done  ),  //复位信号
    .ov5640_pclk        (ov5640_pclk    ),   //摄像头像素时钟
    .ov5640_href        (ov5640_href    ),   //摄像头行同步信号
    .ov5640_vsync       (ov5640_vsync   ),   //摄像头场同步信号
    .ov5640_data        (ov5640_data    ),   //摄像头图像数据

    .ov5640_wr_en       (ov5640_wr_en   ),   //图像数据有效使能信号
    .ov5640_data_out    (ov5640_data_out)    //图像数据

);

endmodule