module Router(
  
  out_port_0, out_credit_0, write_0,
  out_port_1, out_credit_1, write_1,
  out_port_2, out_credit_2, write_2,
  out_port_3, out_credit_3, write_3,
  out_port_4, out_credit_4, write_4,
  out_port_5, out_credit_5, write_5,
  out_port_6, out_credit_6, write_6,
     
  in_port_0, in_credit_0, read_0,
  in_port_1, in_credit_1, read_1,
  in_port_2, in_credit_2, read_2,
  in_port_3, in_credit_3, read_3,
  in_port_4, in_credit_4, read_4,
  in_port_5, in_credit_5, read_5,
  in_port_6, in_credit_6, read_6,
    
  clk, done
  
  );
  
  /*********** Parameters ************/
  
  parameter map_size                    = 1000;
  parameter ID                          =  112;
  parameter flit_size                   =   30;
  parameter node_id_size                =   10;
  parameter credit_delay_buffer_addr_w  =    9;
  parameter buffer_addr_w               =    8;
  parameter num_of_intfs                =    7;
  parameter intfs_size                  =    3;
  parameter num_of_vcs                  =    2;
  parameter vcs_size                    =    2;
  parameter num_credit_delay            =    1;
  
  parameter credit_delay_buffer_width   = intfs_size + vcs_size + 10; // 10 -> max credit delay = 2^10
  
  parameter buffer_size = (1 << buffer_addr_w);
  
  /*********** Output-Input ************/
  
  output reg [flit_size-1:0] out_port_0,
                             out_port_1, 
                             out_port_2,
                             out_port_3,
                             out_port_4,
                             out_port_5,
                             out_port_6;
  
  output reg [num_of_vcs-1:0] out_credit_0, 
                              out_credit_1,
                              out_credit_2,
                              out_credit_3,
                              out_credit_4,
                              out_credit_5,
                              out_credit_6;
  
  output reg write_0, write_1, write_2, write_3, write_4, write_5, write_6, done;
  
  input [flit_size-1:0] in_port_0,
                        in_port_1,
                        in_port_2,
                        in_port_3,
                        in_port_4,
                        in_port_5,
                        in_port_6;
  
  input [num_of_vcs-1:0] in_credit_0,
                         in_credit_1,
                         in_credit_2,
                         in_credit_3,
                         in_credit_4,
                         in_credit_5,
                         in_credit_6;
  
  input read_0, read_1, read_2, read_3, read_4, read_5, read_6;
  
  input clk;
  
  /*********** Variables ************/
  
  reg [flit_size-1:0] temp_in [0:num_of_intfs-1];
  
  reg temp_read [0:num_of_intfs-1];
  
  reg [num_of_vcs-1:0] temp_credit [0:num_of_intfs-1];
  
  wire [flit_size-1:0] buffer_out [0:num_of_intfs-1][0:num_of_vcs-1];
  reg  [flit_size-1:0] buffer_in  [0:num_of_intfs-1][0:num_of_vcs-1];
  
  wire buffer_remove_finish  [0:num_of_intfs-1][0:num_of_vcs-1];
  wire buffer_add_finish   [0:num_of_intfs-1][0:num_of_vcs-1];
  wire buffer_mark_finish    [0:num_of_intfs-1][0:num_of_vcs-1];
  wire buffer_un_mark_finish [0:num_of_intfs-1][0:num_of_vcs-1];
  wire buffer_empty          [0:num_of_intfs-1][0:num_of_vcs-1];
  wire buffer_full           [0:num_of_intfs-1][0:num_of_vcs-1];
  
  reg [buffer_addr_w-1:0] buffer_index [0:num_of_intfs-1][0:num_of_vcs-1];
  reg buffer_add                       [0:num_of_intfs-1][0:num_of_vcs-1];
  reg buffer_remove                    [0:num_of_intfs-1][0:num_of_vcs-1];
  reg buffer_mark                      [0:num_of_intfs-1][0:num_of_vcs-1];
  reg buffer_un_mark                   [0:num_of_intfs-1][0:num_of_vcs-1];
  
  reg is_valid_sending_flit [0:num_of_intfs-1];
  reg [flit_size-1:0] sending_flit [0:num_of_intfs-1];
  reg [intfs_size-1:0] sending_flit_in_port [0:num_of_intfs-1][0:num_of_vcs-1];
  reg [vcs_size-1:0] sending_flit_vc [0:num_of_intfs-1];
  reg [buffer_addr_w-1:0] sending_flit_index [0:num_of_intfs-1][0:num_of_vcs-1];
  reg is_out_virtual_link_reserved [0:num_of_intfs-1][0:num_of_vcs-1];
  
  reg [buffer_addr_w-1:0] credit [0:num_of_intfs-1][0:num_of_vcs-1];
  
  reg [vcs_size+intfs_size-1:0] select_flit_state;
  
  reg select_flit_start;
  
  integer counter_1, counter_2;
  
  genvar i, j, intfs_cnt, vcs_cnt;
  
  wire [credit_delay_buffer_width-1:0] credit_delay_buffer_out;
  wire credit_delay_buffer_remove_finish, credit_delay_buffer_add_finish, 
       credit_delay_buffer_mark_finish, credit_delay_buffer_un_mark_finish, 
       credit_delay_buffer_full, credit_delay_buffer_empty;
  
  reg [credit_delay_buffer_width-1:0] credit_delay_buffer_in;
  
  reg [credit_delay_buffer_addr_w-1:0] credit_delay_buffer_index;
  
  reg credit_delay_buffer_add, credit_delay_buffer_remove, credit_delay_buffer_mark, credit_delay_buffer_un_mark;
  
  reg signed [intfs_size:0] routing_table [0:map_size-1];
  
  /*********** Modules ************/
  
  defparam credit_delay_buffer.addr_w = credit_delay_buffer_addr_w;
  defparam credit_delay_buffer.width   = credit_delay_buffer_width;
  
  Buffer credit_delay_buffer (
                                credit_delay_buffer_out, 
                                credit_delay_buffer_remove_finish, 
                                credit_delay_buffer_add_finish, 
                                credit_delay_buffer_mark_finish, 
                                credit_delay_buffer_un_mark_finish, 
                                credit_delay_buffer_full, 
                                credit_delay_buffer_empty, 
                                credit_delay_buffer_in, 
                                credit_delay_buffer_index, 
                                credit_delay_buffer_add, 
                                credit_delay_buffer_remove, 
                                credit_delay_buffer_mark, 
                                credit_delay_buffer_un_mark
                              );
                              
  /*********** Code ************/
  
  always @(posedge clk)
  begin : MAIN // 1. Phase 0  ---  2. Phase 1
    
    reg [credit_delay_buffer_width-1:0] temp_credit_pack;
    reg [intfs_size-1:0] temp_credit_port;
    reg [vcs_size-1:0] temp_credit_vc;
    reg [10-1:0] temp_delay;
    reg [credit_delay_buffer_addr_w-1:0] temp_rd_ptr;
    reg [credit_delay_buffer_addr_w-1:0] temp_wr_ptr;
    reg full_flag;
    
    reg [flit_size-1:0] temp_flit;
    reg [intfs_size-1:0] temp_in_port;
    reg [vcs_size-1:0] temp_vc;
    reg signed [intfs_size-0:0] dest_port;
    
    // reset select flit state, out credit and write signals
    
    select_flit_state = 0;
    
    out_credit_0 = 0; out_credit_1 = 0; out_credit_2 = 0; out_credit_3 = 0; out_credit_4 = 0; out_credit_5 = 0; out_credit_6 = 0;
    
    write_0 = 0; write_1 = 0; write_2 = 0; write_3 = 0; write_4 = 0; write_5 = 0; write_6 = 0;
    
    // phase 0 : 1. Enqueue flits from temps to buffers  ---  2. Check input credits
    
    for (counter_1 = 0 ; counter_1 < num_of_intfs ; counter_1 = counter_1 + 1) begin // 0.1
      if (temp_read[counter_1]) begin : ENQUEUE
        temp_vc = temp_in[counter_1][0 +: vcs_size];
        dest_port = routing_table[temp_in[counter_1][20 +: node_id_size]];
        if (temp_vc < num_of_vcs && ~buffer_full[counter_1][temp_vc] && dest_port > -1) begin 
          $display("router %0d: flit received from %0d, dest %0d, vc %0d", ID, temp_in[counter_1][10 +: node_id_size], temp_in[counter_1][20 +: node_id_size], temp_vc);
          buffer_in  [counter_1][temp_vc] = temp_in[counter_1];
          buffer_add [counter_1][temp_vc] = 1;
          wait (buffer_add_finish[counter_1][temp_vc] == 1);
          buffer_add [counter_1][temp_vc] = 0;
        end
        else begin
          // drop flit
        end
      end
    end
    
    for (counter_1 = 0 ; counter_1 < num_of_intfs ; counter_1 = counter_1 + 1) // 0.2
      for (counter_2 = 0 ; counter_2 < num_of_vcs ; counter_2 = counter_2 + 1) begin
        if (temp_credit[counter_1][counter_2]) begin
          credit[counter_1][counter_2] = credit[counter_1][counter_2] + 1;
      end
    end
    // phase 1 : 1. Select flits with highest priority to send  ---  2. Put selected flits on out ports
    
    select_flit_start = 1; // 1.1 ( start selecting flits )
    wait (select_flit_start == 0);
    
    done = 1;
    
    for (counter_1 = 0 ; counter_1 < num_of_intfs ; counter_1 = counter_1 + 1) // 1.2
      if (is_valid_sending_flit[counter_1]) begin // if there is a flit to send
        done = 0;
        temp_flit = sending_flit[counter_1];
        temp_vc = sending_flit_vc[counter_1];
        temp_in_port = sending_flit_in_port[counter_1][temp_vc];
        if (credit[counter_1][temp_vc] > 0) begin
          credit[counter_1][temp_vc] = credit[counter_1][temp_vc] - 1; // decrement credit
          case (temp_flit[8+:2])
            0: begin // Body flit
              // nothing to do here
            end
            1: begin // Tail flit
              is_out_virtual_link_reserved[counter_1][temp_vc] = 0;
            end
            2: begin // Head flit
              is_out_virtual_link_reserved[counter_1][temp_vc] = 1;
            end
            3: begin // Head-Tail flit
              is_out_virtual_link_reserved[counter_1][temp_vc] = 0;
            end
          endcase
          
          is_valid_sending_flit[counter_1] = 0;
          buffer_index[temp_in_port][temp_vc] = sending_flit_index[counter_1][temp_vc];
          buffer_remove[temp_in_port][temp_vc] = 1;
          wait (buffer_remove_finish[temp_in_port][temp_vc] == 1);
          buffer_remove[temp_in_port][temp_vc] = 0;
          
          case (counter_1)
            0: begin
              write_0 = 1;
              out_port_0 = sending_flit[counter_1];
            end
            1: begin
              write_1 = 1;
              out_port_1 = sending_flit[counter_1];
            end
            2: begin
              write_2 = 1;
              out_port_2 = sending_flit[counter_1];
            end
            3: begin
              write_3 = 1;
              out_port_3 = sending_flit[counter_1];
            end
            4: begin
              write_4 = 1;
              out_port_4 = sending_flit[counter_1];
            end
            5: begin
              write_5 = 1;
              out_port_5 = sending_flit[counter_1];
            end
            6: begin
              write_6 = 1;
              out_port_6 = sending_flit[counter_1];
            end
          endcase
          
          // add credit to queue
          
          if (~credit_delay_buffer_full) begin
            if (sending_flit_in_port[counter_1][temp_vc] == 0) // no delay for proccessor
              credit_delay_buffer_in = {10'd1, temp_vc, sending_flit_in_port[counter_1][temp_vc]};
            else
              credit_delay_buffer_in = {num_credit_delay, temp_vc, sending_flit_in_port[counter_1][temp_vc]};
            credit_delay_buffer_add = 1;
            wait (credit_delay_buffer_add_finish == 1);
            credit_delay_buffer_add = 0;
          end
          
        end
        else begin
          // output virtual link is full
        end
      end
      
      // iterate over credit delay queue
      
      full_flag = credit_delay_buffer_full;
      
      temp_rd_ptr = credit_delay_buffer.rd_ptr;
      temp_wr_ptr = credit_delay_buffer.wr_ptr;
      
      while (temp_rd_ptr != temp_wr_ptr || full_flag) begin
        full_flag = 0;
        
        temp_credit_pack = credit_delay_buffer.Q[temp_rd_ptr];
        temp_credit_port = temp_credit_pack[0 +: intfs_size];
        temp_credit_vc = temp_credit_pack[intfs_size +: vcs_size];
        temp_delay = temp_credit_pack[(intfs_size+vcs_size) +: 10];
        
        if (temp_delay == 1) begin
          
          case (temp_credit_port)
            0: begin
              out_credit_0[temp_credit_vc] = 1;
            end
            1: begin
              out_credit_1[temp_credit_vc] = 1;
            end
            2: begin
              out_credit_2[temp_credit_vc] = 1;
            end
            3: begin
              out_credit_3[temp_credit_vc] = 1;
            end
            4: begin
              out_credit_4[temp_credit_vc] = 1;
            end
            5: begin
              out_credit_5[temp_credit_vc] = 1;
            end
            6: begin
              out_credit_6[temp_credit_vc] = 1;
            end
          endcase
          
          credit_delay_buffer_index = temp_rd_ptr;
          credit_delay_buffer_remove = 1;
          wait(credit_delay_buffer_remove_finish == 1);
          credit_delay_buffer_remove = 0;
        end
        else begin
          credit_delay_buffer.Q[temp_rd_ptr] = {temp_delay-1, temp_credit_vc, temp_credit_port};
        end
        
        temp_rd_ptr = temp_rd_ptr + 1;
          
      end
      done = done & credit_delay_buffer_empty;
  end
  
  initial 
  begin
    
    select_flit_state = 0;
    select_flit_start = 0;
    
    out_port_0 = 0; out_credit_0 = 0;
    out_port_1 = 0; out_credit_1 = 0;
    out_port_2 = 0; out_credit_2 = 0;
    out_port_3 = 0; out_credit_3 = 0;
    out_port_4 = 0; out_credit_4 = 0;
    out_port_5 = 0; out_credit_5 = 0;
    out_port_6 = 0; out_credit_6 = 0;
    
    write_0 = 0; write_1 = 0; write_2 = 0; write_3 = 0; write_4 = 0; write_5 = 0; write_6 = 0;
    
    credit_delay_buffer_in = 0;
    credit_delay_buffer_index = 0;
    credit_delay_buffer_add = 0; 
    credit_delay_buffer_remove = 0;
    credit_delay_buffer_mark = 0;
    credit_delay_buffer_un_mark = 0;
    
    for (counter_1 = 0 ; counter_1 < map_size ; counter_1 = counter_1 + 1)
      routing_table[counter_1] = -1;
    
    for (counter_1 = 0 ; counter_1 < num_of_intfs ; counter_1 = counter_1 + 1) begin
      temp_in[counter_1] = 0;
      temp_read[counter_1] = 0;
      is_valid_sending_flit[counter_1] = 0;
      sending_flit[counter_1] = 0;
      sending_flit_vc[counter_1] = 0;
      temp_credit[counter_1] = 0;
    end
    
    for (counter_1 = 0 ; counter_1 < num_of_intfs ; counter_1 = counter_1 + 1)
      for (counter_2 = 0 ; counter_2 < num_of_vcs ; counter_2 = counter_2 + 1) begin
        buffer_index[counter_1][counter_2] = 0;
        buffer_in[counter_1][counter_2]  = 0;
        buffer_add[counter_1][counter_2] = 0;
        buffer_remove[counter_1][counter_2] = 0;
        buffer_mark[counter_1][counter_2] = 0;
        buffer_un_mark[counter_1][counter_2] = 0;
        is_out_virtual_link_reserved[counter_1][counter_2] = 0;
        sending_flit_in_port[counter_1][counter_2] = 0;
        sending_flit_index[counter_1][counter_2] = 0;
        credit[counter_1][counter_2] = 1; // can be up to each virtual link buffer size
      end
      
  end
  
  always @(negedge clk) // copy values at negedge ( to support continuouse flit receiving )
  begin
    temp_in[1] = in_port_1; temp_read[1] = read_1; temp_credit[1] = in_credit_1;
    temp_in[2] = in_port_2; temp_read[2] = read_2; temp_credit[2] = in_credit_2;
    temp_in[3] = in_port_3; temp_read[3] = read_3; temp_credit[3] = in_credit_3;
    temp_in[4] = in_port_4; temp_read[4] = read_4; temp_credit[4] = in_credit_4;
    temp_in[5] = in_port_5; temp_read[5] = read_5; temp_credit[5] = in_credit_5;
    temp_in[6] = in_port_6; temp_read[6] = read_6; temp_credit[6] = in_credit_6;
  end
  
  always @*
  begin
    temp_in[0] = in_port_0; temp_read[0] = read_0; temp_credit[0] = in_credit_0;
  end
  
  generate
    for ( i = 0 ; i < num_of_intfs ; i = i + 1 ) begin : PORT
      for ( j = 0 ; j < num_of_vcs ; j = j + 1 ) begin : VC
        
        defparam buffer.size = buffer_size;
        defparam buffer.width = flit_size;
        defparam buffer.addr_w = buffer_addr_w;
        
        Buffer buffer(buffer_out[i][j], 
                      buffer_remove_finish[i][j], 
                      buffer_add_finish[i][j],
                      buffer_mark_finish[i][j],
                      buffer_un_mark_finish[i][j],
                      buffer_full[i][j], 
                      buffer_empty[i][j], 
                      buffer_in[i][j],
                      buffer_index[i][j],
                      buffer_add[i][j], 
                      buffer_remove[i][j],
                      buffer_mark[i][j],
                      buffer_un_mark[i][j]);
      end
    end
  endgenerate
  
  generate
    for ( intfs_cnt = 0 ; intfs_cnt < num_of_intfs ; intfs_cnt = intfs_cnt + 1 ) begin
      for ( vcs_cnt = 0 ; vcs_cnt < num_of_vcs ; vcs_cnt = vcs_cnt + 1 ) begin
        always @(posedge clk)
        begin : SELECT_FLIT_WITH_MAX_PRIORITY
          reg [buffer_addr_w-1:0] temp_rd_ptr, temp_wr_ptr;
          reg [flit_size  -1:0] temp_flit;
          reg [node_id_size -1:0] dest_node_id;
          reg [vcs_size-1:0] temp_vc; 
          reg full_flag, priority_flag;
          
          reg signed [intfs_size-0:0] dest_port; // -0 for expanding it to contain negative num -1 which means not found
          
          select_flit_state = 0;
          
          wait(select_flit_start == 1);
          
          temp_rd_ptr = PORT[intfs_cnt].VC[vcs_cnt].buffer.rd_ptr;
          temp_wr_ptr = PORT[intfs_cnt].VC[vcs_cnt].buffer.wr_ptr;
          
          wait (select_flit_state == (intfs_cnt*num_of_vcs)+vcs_cnt);
          
          if (~buffer_empty[intfs_cnt][vcs_cnt]) begin
              
              full_flag = buffer_full[intfs_cnt][vcs_cnt];
              while (temp_rd_ptr != temp_wr_ptr || full_flag) begin
                full_flag = 0;
                if (~PORT[intfs_cnt].VC[vcs_cnt].buffer.marked_flit[temp_rd_ptr]) begin
                  temp_flit = PORT[intfs_cnt].VC[vcs_cnt].buffer.Q[temp_rd_ptr];
                  dest_node_id = temp_flit[20 +: node_id_size];
                  dest_port = routing_table[dest_node_id];
                  if (dest_port > -1) begin // double check if dest port is valid, checked before when enqueuing
                    if (is_out_virtual_link_reserved[dest_port][vcs_cnt]) begin
                      if (intfs_cnt == sending_flit_in_port[dest_port][vcs_cnt] && vcs_cnt == sending_flit_vc[dest_port]) begin
                        if (is_valid_sending_flit[dest_port]) begin
                          // already being reserved by the packet's further flit
                        end
                        else begin
                          is_valid_sending_flit[dest_port] = 1;
                          sending_flit[dest_port] = temp_flit;
                          sending_flit_index[dest_port][vcs_cnt] = temp_rd_ptr;
                          buffer_mark[intfs_cnt][vcs_cnt] = 1;
                          wait (buffer_mark_finish[intfs_cnt][vcs_cnt] == 1);
                          buffer_mark[intfs_cnt][vcs_cnt] = 0;
                        end
                      end
                      else begin
                        // flit is not for the reserved packet
                      end                        
                    end
                    else begin
                      if (is_valid_sending_flit[dest_port]) begin
                        // compare based on input port & vc
                        priority_flag = vcs_cnt > sending_flit_vc[dest_port];
                        priority_flag = priority_flag || (vcs_cnt == sending_flit_vc[dest_port] && intfs_cnt > sending_flit_in_port[dest_port][sending_flit_vc[dest_port]]);
                        if (priority_flag) begin
                          temp_vc = sending_flit_vc[dest_port];
                          buffer_index[sending_flit_in_port[dest_port][temp_vc]][temp_vc] = sending_flit_index[dest_port][temp_vc];
                          buffer_un_mark[sending_flit_in_port[dest_port][temp_vc]][temp_vc] = 1;
                          wait (buffer_un_mark_finish[sending_flit_in_port[dest_port][temp_vc]][temp_vc] == 1);
                          buffer_un_mark[sending_flit_in_port[dest_port][temp_vc]][temp_vc] = 0;
                          sending_flit[dest_port] = temp_flit;
                          sending_flit_in_port[dest_port][vcs_cnt] = intfs_cnt;
                          sending_flit_vc[dest_port] = vcs_cnt;
                          sending_flit_index[dest_port][vcs_cnt] = temp_rd_ptr;
                          buffer_mark[intfs_cnt][vcs_cnt] = 1;
                          wait (buffer_mark_finish[intfs_cnt][vcs_cnt] == 1);
                          buffer_mark[intfs_cnt][vcs_cnt] = 0;
                        end
                      end
                      else begin
                        is_valid_sending_flit[dest_port] = 1;
                        sending_flit[dest_port] = temp_flit;
                        sending_flit_in_port[dest_port][vcs_cnt] = intfs_cnt;
                        sending_flit_vc[dest_port] = vcs_cnt;
                        sending_flit_index[dest_port][vcs_cnt] = temp_rd_ptr;
                        buffer_mark[intfs_cnt][vcs_cnt] = 1;
                        wait (buffer_mark_finish[intfs_cnt][vcs_cnt] == 1);
                        buffer_mark[intfs_cnt][vcs_cnt] = 0;
                      end
                    end
                  end
                end
                if (PORT[intfs_cnt].VC[vcs_cnt].buffer.size > 1)
                  temp_rd_ptr = temp_rd_ptr + 1;
              end
            end
            
          if (select_flit_state == (num_of_intfs*num_of_vcs-1))
            select_flit_start = 0;
          else
            select_flit_state = select_flit_state + 1;
        end
      end
    end
  endgenerate
  
endmodule