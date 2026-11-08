SRC = sync_fifo.v tb_sync_fifo.v

sim: $(SRC)
	iverilog -g2012 -Wall -o sim $(SRC)
	vvp sim

wave: sim
	gtkwave wave.vcd &

clean:
	rm -f sim wave.vcd

.PHONY: sim wave clean
