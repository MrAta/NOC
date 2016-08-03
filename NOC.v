module NOC(start);
  
  `timescale 1ns/1ps
  
  /*********** Parameters ************/
  
  parameter conn_entries = 3000;
  parameter num_credit_delay  = 1;
  parameter node_id_size = 10;
  parameter num_of_vcs = 2;
  parameter max_cycles = 100000;
  parameter num_of_routers = 5;
  parameter vcs_size = 2;
  parameter intfs_size = 3;
  parameter num_of_intfs = 7;
  parameter flit_size = 30;
  parameter max_num_of_packet_flits_addr_w = 8; // a packet can have up tp 2^8 flits 
  parameter entries_addr_w = 10;
  parameter max_num_of_traffic_entries = (1 << entries_addr_w);
  
  /*********** Output-Input ************/
  
  input start;
  
  /*********** Variables ************/
  
  wire cpu_start, all_done;
  
  reg clk, done_connecting_routers, done_filling_router_tables, done_connecting_cpus, done_traffic_entry;
  
  integer conn_source [0:conn_entries-1];
  integer conn_source_out_port [0:conn_entries-1];
  integer conn_dest [0:conn_entries-1];
  integer conn_dest_in_port [0:conn_entries-1];
  
  integer cycles;
  
  genvar i, j, t;
  
  integer k, p, s, n;
  
  reg [entries_addr_w-1:0] cpu_num_of_packets [0:num_of_routers-1];
  reg [node_id_size-1:0] packet_dest_node [0:num_of_routers-1][0:max_num_of_traffic_entries-1];
  reg [vcs_size-1:0] packet_vc [0:num_of_routers-1][0:max_num_of_traffic_entries-1];
  reg [max_num_of_packet_flits_addr_w-1:0] packet_num_of_flits [0:num_of_routers-1][0:max_num_of_traffic_entries-1];
  
  reg signed [intfs_size:0] router_table [0:num_of_routers-1][0:num_of_routers-1];
  
  wire [flit_size-1:0] cpu_out_port [0:num_of_routers-1];
  wire [num_of_vcs-1:0] cpu_out_credit [0:num_of_routers-1];
  wire cpu_write [0:num_of_routers-1];
  wire [0:num_of_routers-1] cpu_done;
  
  reg [flit_size-1:0] cpu_in_port [0:num_of_routers-1];
  reg [num_of_vcs-1:0] cpu_in_credit [0:num_of_routers-1];
  reg cpu_read [0:num_of_routers-1];  
  
  wire [flit_size-1:0] router_out_port [0:num_of_routers-1][0:num_of_intfs-1];
  wire [num_of_vcs-1:0] router_out_credit [0:num_of_routers-1][0:num_of_intfs-1];
  wire router_write [0:num_of_routers-1][0:num_of_intfs-1];
  wire [0:num_of_routers-1] router_done;
  
  reg [flit_size-1:0] router_in_port [0:num_of_routers-1][0:num_of_intfs-1];
  reg [num_of_vcs-1:0] router_in_credit [0:num_of_routers-1][0:num_of_intfs-1];
  reg router_read [0:num_of_routers-1][0:num_of_intfs-1];  
  
  /*********** Code ************/
  
  initial
  begin
    clk = 0;
    cycles = 0;
    done_connecting_routers = 0;
    done_filling_router_tables = 0;
    done_connecting_cpus = 0;
    done_traffic_entry = 0;
  end
  
  always #15 clk = ~clk;
  
  generate
    for (i = 0 ; i < num_of_routers ; i = i + 1) begin : MAP
      
      defparam router.map_size = num_of_routers;
      defparam router.ID = i;
      defparam router.buffer_addr_w = 1;
      defparam router.buffer_size = 1;
      defparam router.num_of_vcs = num_of_vcs;
      defparam router.vcs_size = vcs_size;
      defparam router.num_credit_delay = num_credit_delay;
      defparam router.flit_size = flit_size;
      
      Router router(
                  router_out_port[i][0], router_out_credit[i][0], router_write[i][0],
                  router_out_port[i][1], router_out_credit[i][1], router_write[i][1],
                  router_out_port[i][2], router_out_credit[i][2], router_write[i][2],
                  router_out_port[i][3], router_out_credit[i][3], router_write[i][3],
                  router_out_port[i][4], router_out_credit[i][4], router_write[i][4],
                  router_out_port[i][5], router_out_credit[i][5], router_write[i][5],
                  router_out_port[i][6], router_out_credit[i][6], router_write[i][6],
     
                  router_in_port[i][0], router_in_credit[i][0], router_read[i][0],
                  router_in_port[i][1], router_in_credit[i][1], router_read[i][1],
                  router_in_port[i][2], router_in_credit[i][2], router_read[i][2],
                  router_in_port[i][3], router_in_credit[i][3], router_read[i][3],
                  router_in_port[i][4], router_in_credit[i][4], router_read[i][4],
                  router_in_port[i][5], router_in_credit[i][5], router_read[i][5],
                  router_in_port[i][6], router_in_credit[i][6], router_read[i][6],
    
                  clk, router_done[i]
                  );
                  
      defparam cpu.flit_size = flit_size;
      defparam cpu.entries_addr_w = entries_addr_w;
      defparam cpu.buffer_addr_w = 1;
      defparam cpu.num_of_vcs = num_of_vcs;
      defparam cpu.vcs_size = vcs_size;
      defparam cpu.ID = i;         
      
      CPU cpu(
              cpu_out_port[i], 
              cpu_out_credit[i], 
              cpu_write[i],
              cpu_done[i],
              cpu_in_port[i], 
              cpu_in_credit[i], 
              cpu_read[i], 
              clk, 
              cpu_start
              );
        
    end
  endgenerate
  
  generate
    for (j = 0 ; j < num_of_routers ; j = j + 1)
      always @(start)
        if (start) begin 
          for (k = 0 ; k < num_of_routers ; k = k + 1) begin
            MAP[j].router.routing_table[k] = router_table[j][k];
            if (k == num_of_routers-1)
              done_filling_router_tables = 1;
          end
        end
  endgenerate
  
  always @* begin
    if (start) begin : CONNECT_ROUTERS
      integer cnt;
      for (cnt = 0 ; cnt < conn_entries ; cnt = cnt + 1) begin
        // assign is not possible because of this error : Slice of unpacked array not allowed in procedural continuous assignment
        // so sensitivity list is changed to *
        // also we know that multiple packed array is not allowed in verilog
        router_in_port[conn_dest[cnt]][conn_dest_in_port[cnt]] = router_out_port[conn_source[cnt]][conn_source_out_port[cnt]];
        router_in_credit[conn_dest[cnt]][conn_dest_in_port[cnt]] = router_out_credit[conn_source[cnt]][conn_source_out_port[cnt]];
        router_read[conn_dest[cnt]][conn_dest_in_port[cnt]] = router_write[conn_source[cnt]][conn_source_out_port[cnt]];
        if (cnt == conn_entries-1)
          done_connecting_routers = 1;
      end
    end
  end
  
  always @* begin
    if (start) begin : CONNECT_CPUS
      integer cnt;
      for (cnt = 0 ; cnt < num_of_routers ; cnt = cnt + 1) begin
        router_in_port[cnt][0] = cpu_out_port[cnt];
        router_in_credit[cnt][0] = cpu_out_credit[cnt];
        router_read[cnt][0] = cpu_write[cnt];
        cpu_in_port[cnt] = router_out_port[cnt][0];
        cpu_in_credit[cnt] = router_out_credit[cnt][0];
        cpu_read[cnt] = router_write[cnt][0];
        if (cnt == num_of_routers-1)
          done_connecting_cpus = 1;
      end
    end
  end
  
  generate
    for (t = 0 ; t < num_of_routers ; t = t + 1)
      always @(start)
        if (start) begin : ENTERING_TRAFFIC
          reg [flit_size-1:0] temp_flit;
          reg [node_id_size-1:0] temp_source;
          reg [7:0] temp_vc;
          reg temp_head;
          reg temp_tail;
          temp_source = t;
          for (s = 0 ; s < cpu_num_of_packets[t] ; s = s + 1) begin
            for (n = 0 ; n < packet_num_of_flits[t][s] ; n = n + 1) begin
              temp_vc = packet_vc[t][s];
              if (n == 0)
                temp_head = 1;
              else
                temp_head = 0;
              if (n == packet_num_of_flits[t][s]-1)
                temp_tail = 1;
              else
                temp_tail = 0;
              temp_flit = {packet_dest_node[t][s], temp_source, {{temp_head, temp_tail}, temp_vc}};
              MAP[t].cpu.flit_buffer[MAP[t].cpu.flit_counter] = temp_flit;
              MAP[t].cpu.flit_counter = MAP[t].cpu.flit_counter + 1;
            end
          end
          if (t == num_of_routers-1)
            done_traffic_entry = 1;
        end
  endgenerate
  
  always @(posedge clk) begin
    if (cpu_start) begin
      if (all_done) begin
        $display("done in clock time %0d", cycles);
        $finish;
      end
      if (cycles + 1 > max_cycles) begin
        $display("not done in max cycles");
        $finish;
      end
      $display("clock time: %0d", cycles);
      cycles = cycles + 1;
    end
  end
  
  assign all_done = (&cpu_done) && (&router_done);
  
  assign cpu_start = done_connecting_routers & done_filling_router_tables & done_connecting_cpus & done_traffic_entry;
  
endmodule