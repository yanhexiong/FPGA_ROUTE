# make        编译并运行仿真
# make wave   用 GTKWave 打开波形
# make clean  删除生成的文件
SRC = counter.v tb_counter.v

sim: $(SRC)
	iverilog -g2012 -Wall -o sim $(SRC)
	vvp sim

wave: sim
	gtkwave wave.vcd &

clean:
	rm -f sim wave.vcd

.PHONY: sim wave clean
