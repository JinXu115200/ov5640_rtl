module vga_ctrl 
(
	input	wire			vga_clk		,
	input	wire			sys_rst_n	,
	input	wire 	[15:0]	pix_data	,

	output	wire			address		,
	output	wire			pix_data_req,
	output	wire	[10:0]	pix_x		,
	output	wire	[10:0]	pix_y		,
	output	wire			rgb_valid	,
	output	wire	[7:0]	vga_red		,
	output	wire	[7:0]	vga_green	,
	output	wire	[7:0]	vga_blue	,
	output	reg				hsync		,
	output	reg				vsync		,
	output	wire			vga_sync	,
	output	wire			vga_blank	,
	output	wire			vga_clock	
);

reg	[10:0]	H_Cont;
reg	[10:0]	V_Cont;
////////////////////////////////////////////////////////////
//	Horizontal	Parameter
parameter	H_FRONT	=	16;
parameter	H_SYNC	=	96;
parameter	H_BACK	=	48;
parameter	H_ACT	=	640;
parameter	H_BLANK	=	H_FRONT+H_SYNC+H_BACK;
parameter	H_TOTAL	=	H_FRONT+H_SYNC+H_BACK+H_ACT;
////////////////////////////////////////////////////////////
//	Vertical Parameter
parameter	V_FRONT	=	10;
parameter	V_SYNC	=	2;
parameter	V_BACK	=	33;
parameter	V_ACT	=	480;
parameter	V_BLANK	=	V_FRONT+V_SYNC+V_BACK;
parameter	V_TOTAL	=	V_FRONT+V_SYNC+V_BACK+V_ACT;
////////////////////////////////////////////////////////////
assign	vga_sync	 =	1'b1;			//	This pin is unused.
assign	vga_blank	 =	~((H_Cont<H_BLANK)||(V_Cont<V_BLANK));
assign	vga_clock	 =	~vga_clk;
assign	vga_red		 =	(rgb_valid == 1'b1) ? {pix_data [15:11], 3'b000} : 8'b0 ;
assign	vga_green	 =	(rgb_valid == 1'b1) ? {pix_data [10:5], 2'b00}   : 8'b0 ;
assign	vga_blue	 =	(rgb_valid == 1'b1) ? {pix_data [4:0], 3'b000}   : 8'b0 ;
assign	address		 =	pix_y*H_ACT+pix_x;
assign	rgb_valid	 =	((H_Cont>=H_BLANK && H_Cont<H_TOTAL)&&(V_Cont>=V_BLANK && V_Cont<V_TOTAL));
assign  pix_data_req =	((H_Cont>=H_BLANK -1'b1 && H_Cont<H_TOTAL - 1'b1)&&(V_Cont>=V_BLANK && V_Cont<V_TOTAL));
assign	pix_x	     =	(H_Cont>=H_BLANK)	?	H_Cont-H_BLANK	:	11'h0	;
assign	pix_y	     =	(V_Cont>=V_BLANK)	?	V_Cont-V_BLANK	:	11'h0	;

//	Horizontal Generator: Refer to the pixel clock
always@(posedge vga_clk or negedge sys_rst_n)
begin
	if(!sys_rst_n)
	begin
		H_Cont		<=	0;
		hsync		<=	1;
	end
	else
	begin
		if(H_Cont<H_TOTAL)
		H_Cont	<=	H_Cont+1'b1;
		else
		H_Cont	<=	0;
		//	Horizontal Sync
		if(H_Cont==H_FRONT-1)			//	Front porch end
		hsync	<=	1'b0;
		if(H_Cont==H_FRONT+H_SYNC-1)	//	Sync pulse end
		hsync	<=	1'b1;
	end
end

//	Vertical Generator: Refer to the horizontal sync
always@(posedge hsync or negedge sys_rst_n)
begin
	if(!sys_rst_n)
	begin
		V_Cont		<=	0;
		vsync		<=	1;
	end
	else
	begin
		if(V_Cont<V_TOTAL)
		V_Cont	<=	V_Cont+1'b1;
		else
		V_Cont	<=	0;
		//	Vertical Sync
		if(V_Cont==V_FRONT-1)			//	Front porch end
		vsync	<=	1'b0;
		if(V_Cont==V_FRONT+V_SYNC-1)	//	Sync pulse end
		vsync	<=	1'b1;
	end
end

endmodule