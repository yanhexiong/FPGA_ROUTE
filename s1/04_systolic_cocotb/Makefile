# cocotb 的标准 Makefile 写法：指定仿真器、源文件、顶层模块和测试模块，其余交给 cocotb。
# make            运行全部测试
# make WAVES=1    同时导出波形到 sim_build/
# make pe         只检查 pe.v（tb_pe.v，重放 README「示例时序」）
# make V=1        显示完整的编译与运行命令（默认不显示，输出更简洁）
ifndef V
.SILENT:
endif

# 隐藏 cocotb 底层（GPI）启动时的几行日志；测试结果与断言信息不受影响。
export GPI_LOG_LEVEL ?= WARNING

SIM ?= icarus
TOPLEVEL_LANG ?= verilog
VERILOG_SOURCES = $(PWD)/pe.v $(PWD)/systolic4x4.v
COCOTB_TOPLEVEL = systolic4x4
COCOTB_TEST_MODULES = test_systolic

include $(shell cocotb-config --makefiles)/Makefile.sim

# 此目标须写在 include 之后，否则会取代 cocotb 的默认目标。
pe: pe.v tb_pe.v
	iverilog -g2012 -Wall -o sim_pe pe.v tb_pe.v
	vvp sim_pe | grep -v "^VCD info"

.PHONY: pe

clean::
	rm -rf sim_build results.xml __pycache__ sim_pe wave_pe.vcd
