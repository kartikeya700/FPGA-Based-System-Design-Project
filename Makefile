IV = iverilog -g2005

all: sim-det sim-lock

sim-det:
	$(IV) -o /tmp/sim_det tb/tb_seq_detector.v rtl/seq_detector.v && vvp /tmp/sim_det

sim-lock:
	$(IV) -o /tmp/sim_lock tb/tb_lock_fsm.v rtl/lock_fsm.v && vvp /tmp/sim_lock

lint:
	$(IV) -Irtl -o /dev/null rtl/top_seq_detector.v rtl/seq_detector.v rtl/seq_generator.v rtl/clk_divider.v
	$(IV) -Irtl -o /dev/null rtl/top_digital_lock.v rtl/lock_fsm.v rtl/piso.v rtl/clk_divider.v

clean:
	rm -f *.vcd
.PHONY: all sim-det sim-lock lint clean
