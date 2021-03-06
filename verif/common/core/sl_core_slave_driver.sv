// ----------------------------------------------------------------------------
//
// ----------------------------------------------------------------------------
// FILE NAME      : sl_core_slave_driver.sv
// PROJECT        : Selen
// AUTHOR         : Grigoriy Zhikharev
// AUTHOR'S EMAIL : gregory.zhiharev@gmail.com
// ----------------------------------------------------------------------------
// DESCRIPTION    : Driver with core interface
// ----------------------------------------------------------------------------

`ifndef INC_SL_CORE_SLAVE_DRIVER
`define INC_SL_CORE_SLAVE_DRIVER

class sl_core_slave_driver extends uvm_driver #(sl_core_bus_item);

  virtual core_if vif;
  sl_core_bus_item tr_item;
  sl_core_agent_cfg cfg;

  // Для порта инструкций, если адрес не меняется
  // значит конвейер стоит. Нужно отвечать одинаковой
  // транзакцией, чтобы не терять стимулы
  protected bit [31:0] prev_addr;

  `uvm_component_utils(sl_core_slave_driver)

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    assert(uvm_config_db#(virtual core_if)::get(this, "" ,"vif", vif))
    else `uvm_fatal("NOVIF", {"Virtual interface must be set for: ", get_full_name(),".vif"});
    assert(uvm_config_db#(sl_core_agent_cfg)::get(this, "" ,"cfg", cfg))
    else `uvm_fatal("NOCFG", {"CFG must be set for: ", get_full_name(),".cfg"});
  endfunction

  function int rand_delay();
    int delay;
    if(cfg.drv_fixed_delay) begin
      delay = cfg.drv_delay_max;
    end
    else begin
      std::randomize(delay) with {
        delay dist {0 :/ 90, [1:cfg.drv_delay_max] :/ 10};
      };
    end
    return(delay);
  endfunction

  task run_phase(uvm_phase phase);
    forever begin
      @(vif.mon);
      if(!vif.rst) begin
        if(vif.mon.req_val) begin
          if(vif.mon.req_addr == prev_addr && cfg.port == INSTR) begin
            repeat(rand_delay()) begin
              clear_interface();
              @(vif.drv_s);
            end
            drive_item(tr_item);
          end
          else begin
            seq_item_port.try_next_item(tr_item);
            if(tr_item != null) begin
              sl_core_bus_item ret_item;
              assert($cast(ret_item, tr_item.clone()));
              ret_item.set_id_info(tr_item);
              ret_item.accept_tr();
              repeat(rand_delay()) begin
                clear_interface();
                @(vif.drv_s);
              end
              drive_item(ret_item);
              prev_addr = vif.mon.req_addr;
              seq_item_port.item_done();
              seq_item_port.put_response(ret_item);
            end
            else
              clear_interface();
          end
        end
        else
          clear_interface();
      end
      else
        reset_interface();
    end
  endtask

  // Reset interface
  task reset_interface();
    vif.drv_s.req_ack <= 0;
    vif.drv_s.req_ack_data <= 0;
  endtask

  // Clear interface
  task clear_interface();
    vif.drv_s.req_ack <= 0;
  endtask

  // Drive item
  task drive_item(sl_core_bus_item item);
    vif.drv_s.req_ack <= 1'b1;
    vif.drv_s.req_ack_data <= item.data;
  endtask

endclass

`endif