BENCH_HOME := $(dir $(lastword $(MAKEFILE_LIST)))/..
TOP=l1_tb_top

include $(BENCH_HOME)/../../rtl/l1_cache/Makefrag
include $(BENCH_HOME)/../tools/Makefile.global
include $(BENCH_HOME)/run/Makefrag

build: analyze elaborate

draft_test:
	./simv +UVM_NO_RELNOTES +UVM_TESTNAME=draft_test $(RUN_OPTS) $(SIM_OPTS)
