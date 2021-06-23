/*
AXI stream user signal overwrite

no keep signal forwarded
*/
module axis_usermod #(
	parameter USER_OVERWRITE = 0,
	parameter DATA_WIDTH = 512,
	parameter USER_WIDTH = 4,
	parameter DEST_WIDTH = 4
)(
	input wire clk,
	output wire [DATA_WIDTH-1:0]  m_axis_tdata,
	output wire [USER_WIDTH-1:0]  m_axis_tuser,
	output wire [DEST_WIDTH-1:0]  m_axis_tdest,
	output wire                   m_axis_tlast,
	// no keep
	input  wire                   m_axis_tready,
	output wire                   m_axis_tvalid,

	input  wire [DATA_WIDTH-1:0]  s_axis_tdata,
	input  wire [USER_WIDTH-1:0]  s_axis_tuser,
	input  wire [DEST_WIDTH-1:0]  s_axis_tdest,
	input  wire                   s_axis_tlast,
	// no keep
	output wire                   s_axis_tready,
	input  wire                   s_axis_tvalid
);

assign s_axis_tready = m_axis_tready;
assign m_axis_tvalid = s_axis_tvalid;
assign m_axis_tdata = s_axis_tdata;
assign m_axis_tuser = USER_OVERWRITE;
assign m_axis_tdest = s_axis_tdest;
assign m_axis_tlast = s_axis_tlast;

endmodule
