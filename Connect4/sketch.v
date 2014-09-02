module sketch(
		CLOCK_50,						//	On Board 50 MHz
		LEDG,
		LEDR,
		KEY,							//	Push Button[3:0]
		SW,								//	DPDT Switch[17:0]
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK,						//	VGA BLANK
		VGA_SYNC,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input	[3:0]	KEY;					//	Button[3:0]
	input	[17:0]	SW;						//	Switches[0:0]
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK;				//	VGA BLANK
	output			VGA_SYNC;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	output [6:0] LEDG;
	output [17:0] LEDR;
	
	reg [17:0] LEDR_;
	assign LEDR = LEDR_;
	reg [6:0] LEDG_;
	assign LEDG = LEDG_;

	// Create the color, x, y and writeEn wires that are inputs to the controller.

	wire [2:0] colour, colourIn;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	wire rEnable,lEnable, dropEnable;
	wire resetn;
	
	//assign xIn = SW[7:0];

	//assign yIn = SW[14:8];

	//assign colourIn = SW[17:15];

	assign resetn = KEY[0];
	assign rEnable = KEY[1];
	assign lEnable = KEY[2];
	assign dropEnable = KEY[3];

	//Reg
	reg writeEn_,writeEn2_;
	reg [7:0]x_,x_next,x_prev=0,xIn,x_prev2=0,xIn2; //x_ is the iterated value to be drawn; xIn is the top left coordinate
	reg [6:0]y_,y_next,y_prev=0,yIn, y_prev2=0,yIn2;
	reg [2:0] colour_;
	wire [2:0]q_sig,q_sig_grid,q_sig_Gameover,q_sig_player1,q_sig_player2,q_sig_redDiskWin;
	assign writeEn = writeEn_ | writeEn2_;
	assign x = x_;
	assign y = y_;
	assign colour = colour_;
	
	player1	player1_inst (
	.address ( count ),
	.clock ( CLOCK_50 ),
	.q ( q_sig_player1 )
	);
	
	player2	player2_inst (
	.address ( count ),
	.clock ( CLOCK_50 ),
	.q ( q_sig_player2 )
	);

	redDiskWin	redDiskWin_inst (
	.address ( count ),
	.clock ( CLOCK_50 ),
	.q ( q_sig_redDiskWin )
	);
	
	redDiskModule	redDiskModule_inst (
		.address (count+1),
		.clock ( CLOCK_50  ),
		.q ( q_sig )
	);
	
	Grid	Grid_inst (
	.address ( count ),
	.clock ( CLOCK_50 ),
	.q ( q_sig_grid )
	);
	
	Gameover	Gameover_inst (
	.address ( count ),
	.clock ( CLOCK_50 ),
	.q ( q_sig_Gameover )
	);

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.

	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
			.colour(colour),
			.x(x),
			.y(y),
			.plot(writeEn),
			// Signals for the DAC to drive the monitor.
			.VGA_R(VGA_R),
			.VGA_G(VGA_G),
			.VGA_B(VGA_B),
			.VGA_HS(VGA_HS),
			.VGA_VS(VGA_VS),
			.VGA_BLANK(VGA_BLANK),
			.VGA_SYNC(VGA_SYNC),
			.VGA_CLK(VGA_CLK));
		defparam VGA.RESOLUTION = "160x120";
		defparam VGA.MONOCHROME = "FALSE";
		defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
		defparam VGA.BACKGROUND_IMAGE = "Grid.mif";

	// Put your code here. Your code should produce signals x,y,color and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.

	//parameter rightLimit = 130, leftLimit = 4;
	reg [3:0]Yp = Reset,Yn, Yg,Yh;
	reg drawDone,resetDone,eraseDone,waitDone,DoneD, DoneS, prevState, donePlayer, doneDrawWin;

	//FSM to draw next or erase
	//module fsm1(input Yp,input resetDone,input waitDone,input DoneD, input  ,output reg DoneS)

	parameter Idle = 0, Draw = 1, Reset = 2, Erase = 3, RIGHT = 4, LEFT = 5, WAIT=6, Drop=7, ultReset=8, drawPlayer = 9;

	always@(*) begin
		case(Yp)
			ultReset: begin
				LEDR_[0] = 1;
				LEDR_[1] = 1;
				//DRAW GRID FROM ROM
				writeEn_ = 1;
				if(resetDone == 1)
					Yn = Reset;
				else Yn = ultReset;
			end
			
			Reset: begin
				DoneS=0;
				writeEn_ = 1;
				//set default x and y values
				Yn = drawPlayer;
			end
			
			drawPlayer: begin
				if(donePlayer == 1)
					Yn = Draw;
				else 
					Yn = drawPlayer;
			end

			Idle: begin
				writeEn_ = 0;
				if(resetn && !rEnable && (xIn != 133) ) begin 
					Yn = RIGHT; end
				else if(resetn && !dropEnable) begin
					Yn = Drop; end
				else if(resetn && !lEnable && (x_prev != 7)) begin
					LEDR_[0] = 0;
					LEDR_[1] = 1;
					Yn = LEFT; end
				else begin
					Yn = Idle; end
			end
			
			RIGHT: begin
				LEDR_[0] = 1;
				LEDR_[1] = 0;
				//set xIn for Right
				Yn = WAIT;
			end	

			LEFT: begin
				LEDR_[0] = 0;
				LEDR_[1] = 1;
				//set xIn for Left
				Yn = WAIT;
			end

			Erase: begin
				writeEn_= 1;
				if(eraseDone==1)
					Yn = Draw;
				else Yn = Erase;
			end

			Draw: begin
				writeEn_ = 1;
				if(drawDone==1) begin
						//set x and y prev
						Yn = Idle;
				end
				else Yn = Draw;
			end

			WAIT: begin
				if(waitDone == 1)
					Yn = Erase;
				else 
					Yn = WAIT;
			end
			
			Drop: begin
				DoneS=1;
				if(DoneD==1) //NEEDS TO BE CHANGED TO "DoneG"
					Yn=Reset;
				else
					Yn=Drop;
			end
		endcase
	end //end always FSM

	//reset

	always@(posedge CLOCK_50 or negedge resetn) begin
		if(resetn==0) 
			Yp <= ultReset;//ultReset;
		else 
			Yp <= Yn;
	end
	
	///////////second fsm///////////

	reg WIN = 0;
	reg [2:0] xt,yt;
	reg [41:0] dropped=42'b0, colorn=42'b0,addr=42'b0;
	reg [6:0] Ymin1=102,Ymin2=102,Ymin3=102,Ymin4=102,Ymin5=102,Ymin6=102,Ymin7=102;
	parameter IDLE2=0 ,DROP2=1, DoneDrop=2, WAIT2=3,  Draw2 = 4, Erase2 = 5, Check4 = 6, Gameover = 7, assignVal = 8, Verify = 9, drawWin = 10;

	always@(*) begin
		case(Yg)
			IDLE2: begin
				LEDR_[8:5] = 4'b0000;
				writeEn2_ = 0;
					if(DoneS==1)
					begin
							DoneD=0;
							Yh=DROP2;
					end
					else 
						Yh = IDLE2;
			end

			DROP2: begin
				if(xIn == 7)
					yIn2=Ymin1;
				else if(xIn == 28) 
					yIn2=Ymin2;
				else if(xIn == 49)
					yIn2=Ymin3;
				else if(xIn == 70)
					yIn2=Ymin4;
				else if(xIn == 91)
					yIn2=Ymin5;
				else if(xIn == 112)
					yIn2=Ymin6;
				else if(xIn == 133)
					yIn2=Ymin7;

				Yh=Erase2;
			end

			Erase2: begin
				writeEn2_ = 1;
				if(eraseDone==1)
					Yh = Draw2;
				else 
					Yh = Erase2;
			end	

			Draw2: begin
				if(drawDone==1) begin
					Yh=WAIT2;
				end
				else 
					Yh = Draw2;
			end		

			WAIT2: begin
				if(waitDone == 1)
					Yh = DoneDrop;
				else 
					Yh = WAIT2;
			end

			DoneDrop: begin
				writeEn2_ = 0;
//				if(DoneG == 1 && DoneS ==0) NEEDS TO BE UNCOMMMENTED WHEN IMPLEMENTING GAME FSM
					Yh=assignVal;
//				else 
//					Yh=DoneDrop;
			end
			
			assignVal: begin
				Yh=Check4;
			end
			
			Check4: begin
				Yh = Verify;
			end
			
			Verify: begin
				if(WIN==1) begin
					DoneD = 0;
					Yh=drawWin;
				end
				else begin
					DoneD = 1;
					Yh=IDLE2;
				end
			end
			
			drawWin: begin
				if(doneDrawWin==1)
					Yh = Gameover;
				else 
					Yh = drawWin;
			end
				
			Gameover: begin
				writeEn2_ = 1;
				LEDR_[8:5] = 4'b1111;
				Yh=Gameover; //Stay
			end

			default: Yh = IDLE2;		
		endcase
	end //end of fsm2

	//Reset for fsm2
	always@(posedge CLOCK_50 or negedge resetn) begin
		if(resetn==0) 
			Yg <= IDLE2;
		else 
			Yg <= Yh;
	end

	reg [25:0] count, count_next;
	//Arithmetic
	always@(*) begin
		if(Yp == ultReset) begin
			count_next = count + 1;
			x_next = count - 160*y;
			y_next = count/160;
		end
		
		else if(Yp == drawPlayer) begin
			count_next = count + 1; // up to 1190
			x_next = 151 + count%10;
			y_next = count/10;
		end
		
		else if(Yp == Draw) begin
			count_next = count+1;
			x_next = xIn + count%15;
			y_next = yIn + count/15;
		end
		
		else if(Yp == Erase) begin
			count_next = count+1;
			x_next = x_prev + count%15;
			y_next = y_prev + count/15;
		end
		
		else if(Yg == Erase2) begin
			count_next = count+1;
			x_next = x_prev + count%15;
			y_next = y_prev + count/15;
		end
		
		else if(Yp == WAIT) begin
			count_next = count+1;
		end

		if(Yg == WAIT2) 
		begin
			count_next = count+1;
		end
		
		else if(Yg == Draw2) begin
			count_next = count+1;
			x_next = xIn + count%15;
			y_next = yIn2 + count/15;
		end
		
		else if(Yg == drawWin) begin
			count_next = count+1;
			x_next = xIn + count%15;
			y_next = yIn2 + count/15;
		end
		
		else if(Yg == Gameover) begin
			count_next = count+1;
			x_next = count - 149*y;
			y_next = count/149;
		end
	end //end always
	
	//Datapath to control draw input
   reg changePlayer=1;
	always@(posedge CLOCK_50) begin
		if(Yp == ultReset) begin
			colour_ <= q_sig_grid;
			if(count < 19200) begin 
				resetDone <= 0;
				x_ <= x_next;
				y_ <= y_next;
				count <= count_next;
			end
			else begin
				Ymin1 <= 102;
				Ymin2 <= 102;
				Ymin3 <= 102;
				Ymin4 <= 102;
				Ymin5 <= 102;
				Ymin6 <= 102;
				Ymin7 <= 102;
				dropped <= 42'b0;
				colorn <= 42'b0;
				addr <= 42'b0;
				//x_ <= 0;
				//y_ <= 0;
				resetDone <= 1;
				count <=0;
			end
		end
		
		else if(Yp == Reset) begin
				//set default x and y values for the disk location
				xIn <= 133;
				yIn <= 0;
		end
		
		else if(Yp == drawPlayer) begin
			
			if(changePlayer==1)
				colour_ <=q_sig_player1; 
			else
				colour_ <=q_sig_player2;
				
			if(count < 1190) begin
				donePlayer <= 0;
				x_ <= x_next;
				y_ <= y_next;
				count <= count_next;
			end
			else begin
				colour_ <= 3'b000;
				donePlayer <= 1;
				count <=4; //reset cnt
			end
		end

		else if(Yp == RIGHT) begin
			xIn <= x_prev + 21;
		end

		else if(Yp == LEFT) begin
			xIn <= x_prev - 21;
		end

		else if((Yp == Draw)||(Yg==Draw2)) begin
			if(changePlayer==1)
			 colour_ <=q_sig; 
			else begin
				if(q_sig == 3'b000)
					colour_ <= q_sig; //q_sig2 - if black keep it black;
				else 
					colour_ <= q_sig-3'b011; //q_sig2 - if red make it blue;
			end
			if(count < 225) begin
				drawDone <= 0;
				x_ <= x_next;
				y_ <= y_next;
				count <= count_next;
			end
			else begin
				drawDone <= 1;
				x_prev <= xIn;
				y_prev <= yIn;
				/*x_ <= xIn;
				y_ <= yIn;*/
				count <=0; //reset cnt
			end
		end
		
		else if((Yp == Erase)||(Yg==Erase2)) begin
			colour_ <= 3'b000;
			if(count < 225) begin
				eraseDone <= 0;
				x_ <= x_next;
				y_ <= y_next;
				count <= count_next;
			end

			else begin
				eraseDone <= 1;
				/*x_ <= xIn;
				y_ <= yIn;*/
				count <=0;
			end
		end

		else if((Yp == WAIT)||(Yg==WAIT2))
		begin
			if(count < 25000000) begin
				waitDone <= 0;
				count <= count_next;
			end
			else begin 
				waitDone <= 1;
				count <= 0;
			end
		end
		
		if (Yg == DoneDrop) begin
			changePlayer <= !changePlayer;
			if(xIn == 7 && Ymin1!= 0) begin
				Ymin1 <= Ymin1-17;
				yt<=((Ymin1)/17)-1;
				xt<=0;
			end
			else if(xIn == 28 && Ymin2!= 0) begin
				Ymin2 <= Ymin2-17;
				yt<=((Ymin2)/17)-1;
				xt<=1;
			end
			else if(xIn == 49 && Ymin3!= 0) begin
				Ymin3 <= Ymin3-17;
				yt<=((Ymin3)/17)-1;
				xt<=2;
			end
			else if(xIn == 70 && Ymin4!= 0)begin
				Ymin4 <= Ymin4-17;
				yt<=((Ymin4)/17)-1 ;
				xt<=3;
			end
			else if(xIn == 91 && Ymin5!= 0) begin
				Ymin5 <= Ymin5-17;
				yt<=((Ymin5)/17)-1;
				xt<=4;
			end
			else if(xIn == 112 && Ymin6!= 0) begin
				Ymin6 <= Ymin6-17;
				yt<=((Ymin6)/17)-1;
				xt<=5;
			end
			else if(xIn == 133 && Ymin7!= 0) begin
				Ymin7 <= Ymin7-17;
				yt<=((Ymin7)/17)-1;
				xt<=6;
			end
		end
	
		else if (Yg == Check4) begin
			if(yt < 3 && (dropped[addr+7] == 1 && colorn[addr+7] == changePlayer) && (dropped[addr+14] == 1 && colorn[addr+14] == changePlayer) && (dropped[addr+21] == 1 && colorn[addr+21] == changePlayer) ) //CHECK down
				WIN<=1;
			else if((xt < 4) && (dropped[addr+1] == 1 && colorn[addr+1] == changePlayer) && (dropped[addr+2] == 1 && colorn[addr+2] == changePlayer) && (dropped[addr+3] == 1 && colorn[addr+3] == changePlayer) ) //CHECK side to side
				WIN<=1;
			else if((xt < 5 && xt > 0) && (dropped[addr+1] == 1 && colorn[addr+1] == changePlayer) && (dropped[addr+2] == 1 && colorn[addr+2] == changePlayer) && (dropped[addr-1] == 1 && colorn[addr-1] == changePlayer) )
				WIN<=1;
			else  if((xt < 6 && xt > 1) &&(dropped[addr+1] == 1 && colorn[addr+1] == changePlayer) && (dropped[addr-1] == 1 && colorn[addr-1] == changePlayer) && (dropped[addr-2] == 1 && colorn[addr-2] == changePlayer) )
				WIN<=1;
//			else if((xt > 2) && (dropped[addr-1] == 1 && colorn[addr-1] == changePlayer) && (dropped[addr-2] == 1 && colorn[addr-2] == changePlayer) && (dropped[addr-3] == 1 && colorn[addr-3] == changePlayer) )
//				WIN<=1;  //NOT WORKING FOR SOME REASON
			else if((xt > 2) && (yt < 3) && (dropped[addr+6] == 1 && colorn[addr+6] == changePlayer) && (dropped[addr+12] == 1 && colorn[addr+12] == changePlayer) && (dropped[addr+18] == 1 && colorn[addr+18] == changePlayer) ) //CHECK Diagonal LD to RU
				WIN<=1;
			else if((xt > 1 && xt < 6) && (yt < 4 && yt > 0) && (dropped[addr+6] == 1 && colorn[addr+6] == changePlayer) && (dropped[addr+12] == 1 && colorn[addr+12] == changePlayer) && (dropped[addr-6] == 1 && colorn[addr-6] == changePlayer) ) 
				WIN<=1;
			else if((xt > 0 && xt < 5) && (yt < 5 && yt > 1) && (dropped[addr-6] == 1 && colorn[addr-6] == changePlayer) && (dropped[addr-12] == 1 && colorn[addr-12] == changePlayer) && (dropped[addr+6] == 1 && colorn[addr+6] == changePlayer) ) 
				WIN<=1;
			else if((xt < 4) && (yt > 2) && (dropped[addr-6] == 1 && colorn[addr-6] == changePlayer) && (dropped[addr-12] == 1 && colorn[addr-12] == changePlayer) && (dropped[addr-18] == 1 && colorn[addr-18] == changePlayer) ) 
				WIN<=1;
			else if((xt > 2) && (yt > 2) && (dropped[addr-8] == 1 && colorn[addr-8] == changePlayer) && (dropped[addr-16] == 1 && colorn[addr-16] == changePlayer) && (dropped[addr-24] == 1 && colorn[addr-24] == changePlayer) )  //CHECK Diagonal LU to RD
				WIN<=1;
			else if((xt > 1 && xt < 6) && (yt > 1 && yt < 5) && (dropped[addr-8] == 1 && colorn[addr-8] == changePlayer) && (dropped[addr-16] == 1 && colorn[addr-16] == changePlayer) && (dropped[addr+8] == 1 && colorn[addr+8] == changePlayer) )  
				WIN<=1;
			else if((xt > 0 && xt < 5) && (yt > 0 && yt < 4) && (dropped[addr-8] == 1 && colorn[addr-8] == changePlayer) && (dropped[addr+16] == 1 && colorn[addr+16] == changePlayer) && (dropped[addr+8] == 1 && colorn[addr+8] == changePlayer) )  
				WIN<=1;
			else if((xt < 4) && (yt < 3) && (dropped[addr+8] == 1 && colorn[addr+8] == changePlayer) && (dropped[addr+16] == 1 && colorn[addr+16] == changePlayer) && (dropped[addr+24] == 1 && colorn[addr+24] == changePlayer) )  
				WIN<=1;
			else
				WIN<=0;
		end
		
		else if(Yg == assignVal) begin
			colorn[(yt*7)+xt] <= changePlayer;
			dropped[(yt*7)+xt] <= 1;
			addr <= (yt*7)+xt;
		end
		
		else if(Yg == drawWin) begin
			if(q_sig_redDiskWin == 3'b000 || q_sig_redDiskWin == 3'b111)
				colour_ <= q_sig_redDiskWin; //if black/white keep it black/white;
			else if(changePlayer==0)
				colour_ <= q_sig_redDiskWin;
			else 
				colour_ <= q_sig_redDiskWin-3'b011; //if red make it blue;

			if(count < 225) begin
				doneDrawWin <= 0;
				x_ <= x_next;
				y_ <= y_next;
				count <= count_next;
			end
			else begin
				doneDrawWin <= 1;
				count <=0; //unsure
			end
		end
		
		else if(Yg == Gameover) begin
			
			if(q_sig_Gameover == 3'b000)
				colour_ <= q_sig_Gameover;
			else if(changePlayer == 0)
				colour_ <= q_sig_Gameover + 3'b101;
			else 
				colour_ <= q_sig_Gameover + 3'b010;
				
			if(count < 2260) begin 
				x_ <= x_next;
				y_ <= y_next;
				count <= count_next;
			end
		end
	end //end always
endmodule