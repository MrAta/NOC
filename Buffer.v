module Buffer(out, remove_finish, add_finish, mark_finish, un_mark_finish, full, empty, in, index, add, remove, mark, un_mark);
  
  /*********** Parameters ************/
    
  parameter addr_w =  8;
  parameter width  = 30;
  parameter size   = (1 << addr_w);
  
  /*********** Output-Input ************/
  
  output reg [width-1:0] out;
  output reg remove_finish, add_finish, mark_finish, un_mark_finish, full, empty;
  
  input [width-1:0] in;
  input [addr_w-1:0] index;
  input add, remove, mark, un_mark;
  
  /*********** Variables ************/
  
  reg [width-1:0]  Q [0:size-1];
  reg marked_flit    [0:size-1];
  reg [addr_w-1:0] wr_ptr, rd_ptr, count;
  
  /*********** Code ************/
  
  initial
  begin
    out = 0;
    wr_ptr = 0;
    rd_ptr = 0;
    count = 0;
    Q[wr_ptr] = 0;
    marked_flit[wr_ptr] = 0;
    full = 0;
    empty = 1;
  end
  
  always @(add)
  begin
    if (add) begin
      if (~full) begin
          Q[wr_ptr] = in;
          marked_flit[wr_ptr] = 0;
          if (size > 1)
            wr_ptr = wr_ptr + 1;
          empty = 0;
          if (count == size-1)
            full = 1;
          else
            count = count + 1;
          add_finish = 1;
        end
    end
    else begin
      add_finish = 0;
    end
  end
  
  always @(remove)
  begin
    if (remove) begin
      if (~empty)
        begin
          out = Q[index];
          if (size > 1)
            delete();
          full = 0;
          if (count > 0)
            count = count - 1;
          if (count == 0)
            empty = 1;
          remove_finish = 1;
        end
    end
    else if (~remove)
      begin
        remove_finish = 0;
      end
  end
  
  always @(mark)
  begin
    if (mark) begin
      marked_flit[index] = 1;
      mark_finish = 1;
    end
    else if (~mark) begin
      mark_finish = 0;
    end
  end
  
  always @(un_mark)
  begin
    if (un_mark) begin
      marked_flit[index] = 0;
      un_mark_finish = 1;
    end
    else if (~un_mark) begin
      un_mark_finish = 0;
    end
  end
  
  task automatic delete;
    
    reg [addr_w-1:0] i;
    
    begin
      for ( i = index ; i > rd_ptr ; i = i - 1) begin
        Q[i] = Q[i-1];
        marked_flit[i] = marked_flit[i-1];
      end
      rd_ptr = rd_ptr + 1;
    end
    
  endtask
  
endmodule