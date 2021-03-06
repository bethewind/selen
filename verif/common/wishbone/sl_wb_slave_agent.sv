// ----------------------------------------------------------------------------
// FILE NAME      : sl_wb_slave_agent.sv
// PROJECT        : Selen
// AUTHOR         : Maksim Kobzar
// AUTHOR'S EMAIL :
// ----------------------------------------------------------------------------
// DESCRIPTION    :
// ----------------------------------------------------------------------------
`ifndef INC_WB_SLAVE_AGENT
`define INC_WB_SLAVE_AGENT

class wb_slave_agent extends uvm_agent;

	wb_slave_driver  driver;
	wb_monitor 	     monitor;
	wb_sequencer     sequencer;

  wb_agent_cfg     cfg;

	uvm_analysis_port #(wb_bus_item) item_collected_port;

	`uvm_component_utils_begin(wb_slave_agent)
    `uvm_field_object(driver,    UVM_DEFAULT)
    `uvm_field_object(monitor,   UVM_DEFAULT)
    `uvm_field_object(sequencer, UVM_DEFAULT)
  `uvm_component_utils_end

  function new(string name = "wb_slave_agent", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(wb_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal("NOCFG", {"Configuration must be set for ", get_full_name(), ".cfg"})
    item_collected_port = new("item_collected_port", this);
    monitor = wb_monitor::type_id::create("monitor", this);
    if(this.get_is_active() == UVM_ACTIVE) begin
    	driver    = wb_slave_driver::type_id::create("driver", this);
    	sequencer = wb_sequencer::type_id::create("sequencer", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    monitor.item_collected_port.connect(item_collected_port);
    if(this.get_is_active() == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
    end
  endfunction

endclass

`endif