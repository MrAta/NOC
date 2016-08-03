module CPU(out_port, out_credit, write, done, in_port, in_credit, read, clk, start);
  
  /*********** Parameters ************/
  
  // CPU does not support buffer at input port, receiving flit at every clock positive edge
  
  parameter ID                         = 55;
  parameter flit_size                  = 30;
  parameter entries_addr_w             = 10;
  parameter node_id_size               = 10;
  parameter buffer_addr_w              =  8;
  parameter intfs_size                 =  3;
  parameter num_of_vcs                 =  2;
  parameter vcs_size                   =  2;
  parameter max_num_of_traffic_entries = (1 << entries_addr_w);
  
  /*********** Output-Input ************/
  
  output reg [flit_size-1:0] out_port;
  output reg [num_of_vcs-1:0] out_credit;
  output reg write, done;
  
  input [flit_size-1:0] in_port;
  input [num_of_vcs-1:0] in_credit;
  input read, clk, start;
  
  /*********** Variables ************/
  
  reg [flit_size-1:0] flit_buffer [0:max_num_of_traffic_entries-1];
  reg [entries_addr_w-1:0] flit_counter, counter;
  reg [buffer_addr_w-1:0] credit [0:num_of_vcs-1];
  
  reg [flit_size-1:0] temp_in, temp_flit;
  reg [num_of_vcs-1:0] temp_credit;
  reg temp_read;
  
  integer i;
  
  /*********** Code ************/
  
  initial
  begin
    out_port = 0;
    out_credit = 0;
    write = 0;
    done = 0;
    flit_counter = 0;
    counter = 0;
    temp_in = 0;
    temp_credit = 0;
    temp_read = 0;
    for (i = 0 ; i < num_of_vcs ; i = i + 1)
      credit[i] = 1;
    
    wait (start == 1);
    
    while (counter < flit_counter) begin
      write = 0;
      temp_flit = flit_buffer[counter];
      if (credit[temp_flit[0 +: vcs_size]] > 0) begin
        credit[temp_flit[0 +: vcs_size]] = credit[temp_flit[0 +: vcs_size]] - 1;
        out_port = temp_flit;
        write = 1;
        counter = counter + 1;
        wait (clk == 1);
        wait (clk == 0);
      end
    end
    write = 0;
    done = 1;
  end
  
  always @* begin
    temp_in = in_port; temp_read = read; temp_credit = in_credit;
    for (i = 0 ; i < num_of_vcs ; i = i + 1) begin
      if (temp_credit[i])
        credit[i] = credit[i] + 1;
    end
    out_credit = 0;
    if (temp_read) begin
      $display("CPU %0d : a flit received from %0d with vc %0d, head-tail %0d-%0d", ID, temp_in[10 +: node_id_size], temp_in[0 +: vcs_size], temp_in[9], temp_in[8]);
      out_credit[temp_in[0 +: vcs_size]] = 1; // cpu doesn't support sending back credit with delay
    end
  end
  
endmodule