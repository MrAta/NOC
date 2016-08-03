module Initializer;
  
  `include "parameters.vh"
  
  /*********** Parameters ************/
    
  parameter max_conn_entries = 3000;
  
  /*********** Variables ************/
  
  reg start;
  
  integer i;
  
  integer fd, fh;
  
  integer temp_res_0, temp_res_1, temp_res_2, temp_res_3, temp_res_4, temp_res_5;
  
  /*********** Code ************/
  
  initial
  begin
    fd = $fopen("router_configuration_-1.txt", "r");
    if (fd == 0) begin
      $finish;
    end
    fh = $fscanf(fd, "num_credit_delay_cycles=%d\n", temp_res_0);
    fh = $fscanf(fd, "num_vcs=%d\n", temp_res_0);
    i = 0;
    while (fh > 0) begin
      fh = $fscanf(fd, "%d:%d-%d:%d\n", temp_res_0, temp_res_1, temp_res_2, temp_res_3);
      if (fh > 0) begin
        noc.conn_source[i] = temp_res_0;
        noc.conn_source_out_port[i] = temp_res_1;
        noc.conn_dest[i] = temp_res_2;
        noc.conn_dest_in_port[i] = temp_res_3;
        i = i + 1;
      end
    end  
    $fclose(fd); // finished reading router configuration file
    
    fd = $fopen("traffic_-1.txt", "r");
    if (fd == 0) begin
      $finish;
    end
    fh = $fscanf(fd, "verbose=%d\n", temp_res_0);
    fh = $fscanf(fd, "max_cycle=%d\n", temp_res_0);
    
    i = 0;
    while (i < `num_of_routers*`num_of_routers) begin
      fh = $fscanf(fd, "route:%d->%d:%d\n", temp_res_0, temp_res_1, temp_res_2);
      if (fh > 0) begin
        noc.router_table[temp_res_0][temp_res_1] = temp_res_2;
        i = i + 1;
      end
    end
    
    for (i = 0 ; i < `num_of_routers ; i = i + 1)
      noc.cpu_num_of_packets[i] = 0;
    
    while (fh != -1) begin
      fh = $fscanf(fd, "node %d:%d\n", temp_res_0, temp_res_1);
      if (fh > 0) begin
        noc.cpu_num_of_packets[temp_res_0] = temp_res_1;
        i = 0;
        while (i < temp_res_1) begin
          fh = $fscanf(fd, "%d:%d:%d:%d\n", temp_res_2, temp_res_3, temp_res_4, temp_res_5);
          if (fh > 0) begin
            noc.packet_dest_node[temp_res_0][i] = temp_res_3;
            noc.packet_vc[temp_res_0][i] = temp_res_4;
            noc.packet_num_of_flits[temp_res_0][i] = temp_res_5;
            i = i + 1;
          end
        end
      end
    end
    
    start = 1;
    
  end
    
  defparam noc.conn_entries = `conn_entries;
  defparam noc.num_credit_delay = `num_credit_delay;
  defparam noc.num_of_vcs = `num_of_vcs;
  defparam noc.max_cycles = `max_cycles;
  defparam noc.num_of_routers = `num_of_routers;
  defparam noc.vcs_size = `vcs_size;
  
  NOC noc(start);
  
endmodule