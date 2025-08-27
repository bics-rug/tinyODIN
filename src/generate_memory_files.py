import random

#Network Parameters
NUM_NEURONS = 256
MAX_SYNAPSES_PER_NEURON = 5
MIN_SYNAPSES_PER_NEURON = 1
MAX_SYNAPSE_MEMORY_SIZE = 4096

#Neuron Parameters (for LIF Neurons)
DEFAULT_LEAK_STRENGTH = 10          # 7-bit (0-127)
DEFAULT_THRESHOLD = 3             # 12-bit (0-4095)
DEFAULT_INITIAL_POTENTIAL = 0       # 12-bit (signed, but its 0 in here)
DEFAULT_NEURON_DISABLED = 0         # 1-bit (0: enabled, 1: disabled)

#Output file names
BRAM_LUT_FILE = "bram_lut_data.mem"
BRAM_SYNAPSE_FILE = "bram_synapse_data.mem"
NEURON_MEMORY_FILE = "neuron_memory_data.mem"

def generate_bram_lut_and_synapse_data():

    bram_lut_entries = []
    bram_synapse_entries = []
    current_synapse_base_addr = 0

    print("Generating BRAM_LUT and BRAM_Synapse informations...")

    for pre_syn_neuron_id in range(NUM_NEURONS * 2):
        num_connections = random.randint(MIN_SYNAPSES_PER_NEURON, MAX_SYNAPSES_PER_NEURON)

        if current_synapse_base_addr + num_connections > MAX_SYNAPSE_MEMORY_SIZE:
            num_connections = MAX_SYNAPSE_MEMORY_SIZE - current_synapse_base_addr
            if num_connections < 0:
                num_connections = 0
        
        lut_entry = (current_synapse_base_addr << 8) | num_connections
        bram_lut_entries.append(lut_entry)

        connected_neurons = random.sample(range(NUM_NEURONS), num_connections)

        for post_syn_neuron_addr in connected_neurons:
            syn_weight = random.randint(0, 15)

            synapse_entry = (post_syn_neuron_addr << 4) | syn_weight
            bram_synapse_entries.append(synapse_entry)

        current_synapse_base_addr += num_connections
    
    with open(BRAM_LUT_FILE, 'w') as f:
        for entry in bram_lut_entries:
            f.write(f"{entry:025b}\n")
    
    with open(BRAM_SYNAPSE_FILE, 'w') as f:
        for entry in bram_synapse_entries:
            f.write(f"{entry:012b}\n")

    print(f"'{BRAM_LUT_FILE}' and '{BRAM_SYNAPSE_FILE}' created.")
    print(f"Total {len(bram_synapse_entries)} synaptic connections created.")


def generate_neuron_memory_data():

    print("Generating neuron memory informations...")
    neuron_memory_entries = []

    for _ in range(NUM_NEURONS):
        neuron_data = (DEFAULT_NEURON_DISABLED << 31) | \
                      (DEFAULT_LEAK_STRENGTH << 24) | \
                      (DEFAULT_THRESHOLD << 12) | \
                      (DEFAULT_INITIAL_POTENTIAL)
        
        neuron_memory_entries.append(neuron_data)

        with open(NEURON_MEMORY_FILE, 'w') as f:
            for entry in neuron_memory_entries:
                f.write(f"{entry:032b}\n")

    print(f"'{NEURON_MEMORY_FILE}' succesfully created.")

if __name__ == "__main__":
    generate_bram_lut_and_synapse_data()
    print("-"*30)
    generate_neuron_memory_data()
    print("-"*30)
    print("All memory files created!")