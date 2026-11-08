SRC = mac.v tb_mac.v

sim: $(SRC) vectors.hex
	iverilog -g2012 -Wall -o sim $(SRC)
	vvp sim

vectors.hex: gen_vectors.py
	python3 gen_vectors.py

wave: sim
	gtkwave wave.vcd &

clean:
	rm -f sim wave.vcd vectors.hex

.PHONY: sim wave clean
