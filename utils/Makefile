BUILD_DIR = build
PCAP_DIR = pcaps
LOG_DIR = logs

ifndef TOPO
TOPO = topology.json
endif

P4C = p4c-bm2-sume
RUN_SCRIPT = ../../utils/run_sume_exercise.py

ifndef P4_SRC
P4_SRC := $(wildcard *.p4)
endif

P4C_ARGS += $(P4_SRC)

outfile := $(P4_SRC:.p4=.json)

compiled_json := $(BUILD_DIR)/$(notdir $(outfile))

run_args += -j $(compiled_json)

# Set BMV2_SWITCH_EXE to override the BMv2 target
ifdef BMV2_SWITCH_EXE
run_args += -b $(BMV2_SWITCH_EXE)
endif

all: run

run: build
	sudo python $(RUN_SCRIPT) -t $(TOPO) $(run_args)

stop:
	sudo mn -c

build: dirs $(compiled_json)

$(compiled_json):
	$(P4C) -D BMV2 --p4v 16 $(P4C_ARGS) -o $@ $<

dirs:
	mkdir -p $(BUILD_DIR) $(PCAP_DIR) $(LOG_DIR)

clean: stop
	rm -f *.pcap
	rm -rf $(BUILD_DIR) $(PCAP_DIR) $(LOG_DIR)
