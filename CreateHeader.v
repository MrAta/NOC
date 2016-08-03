module CreateHeader;

  /*********** Variables ************/
  
  integer conn_entries, 
          num_credit_delay,
          num_of_vcs,
          max_cycles,
          num_of_routers,
          vcs_size;
  
  integer fd, fh;
  
  integer temp_res_0, temp_res_1, temp_res_2, temp_res_3;
  
  /*********** Code ************/
  
  initial
  begin
    
    conn_entries = 0;
    num_credit_delay = 0;
    num_of_vcs = 0;
    max_cycles = 0;
    num_of_routers = 0;
    vcs_size = 0;
    
    fd = $fopen("router_configuration_-1.txt", "r");
    if (fd == 0) begin
      $finish;
    end
    fh = $fscanf(fd, "num_credit_delay_cycles=%d\n", num_credit_delay);
    fh = $fscanf(fd, "num_vcs=%d\n", num_of_vcs);
    while (fh != -1) begin
      fh = $fscanf(fd, "%d:%d-%d:%d\n", temp_res_0, temp_res_1, temp_res_2, temp_res_3);
      if (fh > 0) begin
        conn_entries = conn_entries + 1;
        if (temp_res_0 + 1 > num_of_routers)
          num_of_routers = temp_res_0 + 1;
        if (temp_res_2 + 1 > num_of_routers)
          num_of_routers = temp_res_2 + 1;
      end
    end
    $fclose(fd); // finished reading router configuration file
    
    fd = $fopen("traffic_-1.txt", "r");
    if (fd == 0) begin
      $finish;
    end
    fh = $fscanf(fd, "verbose=%d\n", temp_res_0);
    fh = $fscanf(fd, "max_cycle=%d\n", max_cycles);
    $fclose(fd); // finished reading traffic file
    
    CalVCSize();
    
    // writing parameters to file 'parameters.vh'
    
    fd = $fopen("parameters.vh", "w");
    
    $fdisplay(fd, "`ifndef _noc_params_vh_");
    $fdisplay(fd, "`define _noc_params_vh_\n");
    
    $fdisplay(fd, "\t`define conn_entries %0d", conn_entries);
    $fdisplay(fd, "\t`define num_credit_delay %0d", num_credit_delay);
    $fdisplay(fd, "\t`define num_of_vcs %0d", num_of_vcs);
    $fdisplay(fd, "\t`define max_cycles %0d", max_cycles);
    $fdisplay(fd, "\t`define num_of_routers %0d", num_of_routers);
    $fdisplay(fd, "\t`define vcs_size %0d", vcs_size);
    
    $fdisplay(fd, "\n`endif");
    
    $fclose(fd);
  end
  
  task automatic CalVCSize;
    
    integer temp;
    
    begin
      if (num_of_vcs == 1)
        vcs_size = 1;
      else begin
        temp = num_of_vcs - 1;
        while (temp != 0) begin
          vcs_size = vcs_size + 1;
          temp = temp / 2;
        end
      end
    end 
    
  endtask
  
endmodule