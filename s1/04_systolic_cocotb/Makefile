# cocotb 的标准 Makefile 写法：指定仿真器、源文件、顶层模块和测试模块，其余交给 cocotb。
# make            运行全部测试
# make WAVES=1    同时导出波形到 sim_build/
SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES = $(PWD)/pe.v $(PWD)/systolic4x4.v
COCOTB_TOPLEVEL = systolic4x4
COCOTB_TEST_MODULES = test_systolic

include $(shell cocotb-config --makefiles)/Makefile.sim

clean::
	rm -rf sim_build results.xml __pycache__
