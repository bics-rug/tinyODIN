######## Kria XDC FileSample ########
# Project: Neuromorphic chip implementation with AER and 4-phase protocole
# Target Connector is RPI GPIO
# Note: These pin assignments made according to KR260 Rev B01 schematic file
#############################################################################

#####################################
#                                   #
#      		Main clocks		   	 	#
#                                   #
#####################################

# Controller clock
create_clock -period 10.000 -name CLK -waveform {0.000 5.000} [get_ports CLK]

# SPI slave clock
create_clock -period 50.000 -name SCK -waveform {0.000 25.000} [get_ports SCK]

set_clock_groups -asynchronous -group CLK -group SCK

# Clock distribution latency and uncertainty
set_clock_latency 0.500 [all_clocks]


#####################################
#                                   #
#         INPUT/OUPUT DELAYS	    #
#                                   #
#####################################

# False paths
# set_false_path -through [get_ports RST]
# set_false_path -through [get_ports AERIN_ADDR]
# set_false_path -through [get_ports AERIN_REQ]
# set_false_path -through [get_ports AERIN_ACK]
set_false_path -through [get_ports SCHED_FULL]

# INPUT from I/O buffers - mosi
set_input_delay -clock SCK -clock_fall -max -network_latency_included 5.000 [get_ports MOSI]
set_input_delay -clock SCK -clock_fall -min -network_latency_included -5.000 [get_ports MOSI]

# OUTPUTS to I/O buffers - miso
set_output_delay -clock SCK -max -network_latency_included 5.000 [get_ports MISO]
set_output_delay -clock SCK -min -network_latency_included -5.000 [get_ports MISO]


set_property PACKAGE_PIN H12 [get_ports OUTPUT_BITS_ONION_p[0]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[0]]
set_property PACKAGE_PIN B10 [get_ports OUTPUT_BITS_ONION_n[0]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[0]]

set_property PACKAGE_PIN E10 [get_ports OUTPUT_BITS_ONION_p[1]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[1]]
set_property PACKAGE_PIN E12 [get_ports OUTPUT_BITS_ONION_n[1]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[1]]

set_property PACKAGE_PIN D10 [get_ports OUTPUT_BITS_ONION_p[2]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[2]]
set_property PACKAGE_PIN D11 [get_ports OUTPUT_BITS_ONION_n[2]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[2]]

set_property PACKAGE_PIN C11 [get_ports OUTPUT_BITS_ONION_p[3]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[3]]
set_property PACKAGE_PIN B11 [get_ports OUTPUT_BITS_ONION_n[3]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[3]]

set_property PACKAGE_PIN J11 [get_ports OUTPUT_BITS_ONION_p[4]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[4]]
set_property PACKAGE_PIN H11 [get_ports OUTPUT_BITS_ONION_n[4]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[4]]

set_property PACKAGE_PIN J10 [get_ports OUTPUT_BITS_ONION_p[5]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[5]]
set_property PACKAGE_PIN G10 [get_ports OUTPUT_BITS_ONION_n[5]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[5]]

set_property PACKAGE_PIN K13 [get_ports OUTPUT_BITS_ONION_p[6]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[6]]
set_property PACKAGE_PIN F12 [get_ports OUTPUT_BITS_ONION_n[6]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[6]]

set_property PACKAGE_PIN K12 [get_ports OUTPUT_BITS_ONION_p[7]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[7]]
set_property PACKAGE_PIN F11 [get_ports OUTPUT_BITS_ONION_n[7]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[7]]

set_property PACKAGE_PIN AE12 [get_ports OUTPUT_BITS_ONION_p[8]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_p[8]]
set_property PACKAGE_PIN AF11 [get_ports OUTPUT_BITS_ONION_n[8]]
set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_n[8]]

# set_property PACKAGE_PIN AF12 [get_ports OUTPUT_BITS_ONION_A_AO]
# set_property IOSTANDARD LVCMOS33 [get_ports OUTPUT_BITS_ONION_A_AO]

set_property PACKAGE_PIN AG11 [get_ports SCHED_FULL]
set_property IOSTANDARD LVCMOS33 [get_ports SCHED_FULL]

set_property PACKAGE_PIN AC12 [get_ports SCK]
set_property IOSTANDARD LVCMOS33 [get_ports SCK]

set_property PACKAGE_PIN AG10 [get_ports MISO]
set_property IOSTANDARD LVCMOS33 [get_ports MISO]

set_property PACKAGE_PIN AH12 [get_ports MOSI]
set_property IOSTANDARD LVCMOS33 [get_ports MOSI]

set_property PACKAGE_PIN C3 [get_ports CLK]
set_property IOSTANDARD LVCMOS18 [get_ports CLK]

set_property PACKAGE_PIN F8 [get_ports LED]
set_property IOSTANDARD LVCMOS18 [get_ports LED]
