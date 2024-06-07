module MPQ(clk,rst,data_valid,data,cmd_valid,cmd,index,value,busy,RAM_valid,RAM_A,RAM_D,done);
input clk;
input rst;
input data_valid;
input [7:0] data;
input cmd_valid;
input [2:0] cmd;
input [7:0] index;
input [7:0] value;
output reg busy;
output reg RAM_valid;
output reg[7:0]RAM_A;
output reg [7:0]RAM_D;
output reg done;

reg [7:0] values [0:31];
reg [3:0] state;
reg [7:0] p_idx_set [0:31];

integer idx = 0;
integer parent_index = 0;
integer output_index = 0;
integer max_index = 0;
integer p_idx = 0;
integer temp_cmd;
integer op_index;
integer op_value;

// 定義狀態
parameter INPUT_DATA = 4'b0000;
parameter COMPARE_LEFT_CHILD = 4'b0001;
parameter COMPARE_RIGHT_CHILD = 4'b0010;
parameter SWAP = 4'b0011;
parameter GET_COMMAND = 4'b0100;
parameter BUFFER = 4'b0101;
parameter CHECK_ROOT = 4'b0110;
parameter WAIT_COMMAND = 4'b0111;
parameter WRITE = 4'b1000;
parameter BUFFER_COMMAND = 4'b1010;
parameter DONE = 4'b1001;
parameter UPDATE_VALUE = 4'b1011;

always @ (posedge clk) begin
	if(rst) begin
        state <= INPUT_DATA;
		RAM_valid <= 0;
		done <= 0;
		busy <= 1;
    end else begin // rst == 0
        case(state) 
            INPUT_DATA: begin
				if(data_valid) begin
					values[idx] <= data;
					idx <= idx + 1;				
				end else begin  //   data_valid == 0          							
					state <= COMPARE_LEFT_CHILD;
					parent_index <= (idx-1)/2;
					idx <= idx - 1;
				end
            end		
            COMPARE_LEFT_CHILD: begin			
				if((2*(parent_index)+1) <= idx  && values[parent_index] < values[2*(parent_index) +1]) begin
					max_index <= 2*(parent_index) +1;				
				end else begin
					max_index <= parent_index;
				end
				state <= COMPARE_RIGHT_CHILD;						

            end
			COMPARE_RIGHT_CHILD: begin
				if((2*(parent_index)+2) <= idx  && values[max_index] < values[2*(parent_index) +2]) begin
					max_index <= 2*(parent_index) + 2;				
				end
				state <= SWAP;
			end
			SWAP: begin
				values[parent_index] <= values[max_index];
				values[max_index] <= values[parent_index];
				
				p_idx_set[p_idx] <= parent_index; // 紀錄當前 subtree root
				p_idx <= p_idx + 1;
				parent_index <= max_index; // 往下處理 subtree
				max_index <= parent_index;
				state <= BUFFER;
			end
			BUFFER: begin
				if(parent_index == max_index) begin // 不需往下trase
					// $display("CASE BUFFER if...");
					parent_index <= p_idx_set[0]; // 回溯
					p_idx <= 0;
					state <= CHECK_ROOT;	
				end else begin // parent_index != max_index, 需往下trase
					// $display("CASE BUFFER else...");
					state <= COMPARE_LEFT_CHILD;	
				end				
			end
			CHECK_ROOT: begin
				if(parent_index != 0) begin // not root
					parent_index <= parent_index - 1;
					state <= COMPARE_LEFT_CHILD;
				end else begin // parent_index == 0, root
					state <= GET_COMMAND;
					busy <= 0;
				end		
			end						
			GET_COMMAND: begin
				temp_cmd <= cmd;
				busy <= 1;
				if(cmd_valid) begin
					case(cmd)
						0: begin
							state <= BUFFER_COMMAND;
						end
						1: begin // Extract Max
							state <= BUFFER_COMMAND;						
						end
						2: begin // Increase_Value
							op_index <= index - 1;
							op_value <= value;
							state <= BUFFER_COMMAND;
						end
						3: begin // Insert_Data							
							op_index <= idx + 1;
							op_value <= value;
							state <= BUFFER_COMMAND;
						end
						4: begin								
							state <= BUFFER_COMMAND;												
						end																			
					endcase
				end
			end				
			BUFFER_COMMAND: begin				
				case(temp_cmd)
					0: begin
						busy <= 0;
						state <= GET_COMMAND;
					end
					1: begin // Extract Max
						idx <= idx - 1;
						values[0] <= values[idx];
						parent_index <= 0;
						state <= COMPARE_LEFT_CHILD;
					end
					2: begin // Increase_Value						
						values[op_index] <= op_value;
						state <= UPDATE_VALUE;							
					end
					3: begin // Insert_Data						
						values[op_index] <= op_value;
						idx <= idx + 1;
						state <= UPDATE_VALUE;							
					end
					4: begin // write
						busy <= 0;
						state <= WRITE;
					end
				endcase				
			end
			UPDATE_VALUE: begin
				if(values[(op_index-1)/2] < values[op_index]) begin
					values[(op_index-1)/2] <= values[op_index];
					values[op_index] <= values[(op_index-1)/2];
					op_index <= (op_index-1)/2;
					if((op_index-1)/2 != 0) begin // not root
						state <= UPDATE_VALUE;
					end else begin // is root
						state <= GET_COMMAND;
						busy <= 0;					
					end					
				end	else begin
					state <= GET_COMMAND;
					busy <= 0;	
				end				
			end
			WRITE: begin
				RAM_valid <= 1;
				busy <= 1;
				RAM_A <= output_index;
				RAM_D <= values[output_index];

				output_index <= output_index + 1;
				if(output_index == idx) begin
					state <= DONE;
				end
			end
			DONE: begin
				done <= 1;
				RAM_valid <= 0;
				busy <= 0;
			end
			
		endcase
    end	
end
endmodule