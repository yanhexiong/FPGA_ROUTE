# make        编译并运行 led_flow 的仿真验收
# make wave   用 GTKWave 打开波形
# make clean  删除生成的文件
SRC = led_flow.v tb_led_flow.v

sim: $(SRC)
	iverilog -g2012 -Wall -o sim $(SRC)
	vvp sim

wave: sim
	gtkwave wave.vcd &

clean:
	rm -f sim wave.vcd

.PHONY: sim wave clean
