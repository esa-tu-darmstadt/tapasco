module MSIxUSPTranslator(
              input [63:0] s_cfg_interrupt_msix_address,
              input [31:0] s_cfg_interrupt_msix_data,
              input s_cfg_interrupt_msix_int,
              output [3:0] s_cfg_interrupt_msix_enable,
              output s_cfg_interrupt_msix_fail,
              output s_cfg_interrupt_msix_sent,
              output [63:0] m_cfg_interrupt_msix_address,
              output [31:0] m_cfg_interrupt_msix_data,
              output m_cfg_interrupt_msix_int,
              input [3:0] m_cfg_interrupt_msix_enable,
              input m_cfg_interrupt_msix_fail,
              input m_cfg_interrupt_msix_sent
              );

assign m_cfg_interrupt_msix_address = s_cfg_interrupt_msix_address;
assign m_cfg_interrupt_msix_data = s_cfg_interrupt_msix_data;
assign m_cfg_interrupt_msix_int = s_cfg_interrupt_msix_int;
assign s_cfg_interrupt_msix_enable = m_cfg_interrupt_msix_enable;
assign s_cfg_interrupt_msix_fail = m_cfg_interrupt_msix_fail;
assign s_cfg_interrupt_msix_sent = m_cfg_interrupt_msix_sent;

endmodule
