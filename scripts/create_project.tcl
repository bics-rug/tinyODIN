#!/usr/bin/tclsh
# scripts/create_project.tcl - Essential project creation script

# ============================================================================
# PROJECT CONFIGURATION - EDIT THESE VALUES FOR YOUR PROJECT
# ============================================================================

# Set the project name
set project_name "tinyODIN_r01"
set part "xck26-sfvc784-2LV-c"
set board_part "xilinx.com:kr260_som:part0:1.1"
set board_connections "som240_2_connector xilinx.com:kr260_carrier:som240_2_connector:1.1 som240_1_connector xilinx.com:kr260_carrier:som240_1_connector:1.1"
set board_id "kr260_som_som240_2_connector_kr260_carrier_som240_2_connector_som240_1_connector_kr260_carrier_som240_1_connector"
set target_language "Verilog"
# set top_module "top_level"

# ============================================================================
# AUTOMATIC SETUP - DON'T EDIT BELOW UNLESS YOU KNOW WHAT YOU'RE DOING
# ============================================================================

# Use project name variable, if specified in the tcl shell
if { [info exists ::user_project_name] } {
  set project_name $::user_project_name
}

# Get script directory
set script_dir [file normalize [file dirname [info script]]]
set project_root [file dirname $script_dir]
set project_dir [file join $project_root $project_name]

puts "=== CREATING VIVADO PROJECT ==="
puts "Project: $project_name"
puts "Part: $part"
puts "Language: $target_language"
puts "Root directory: $project_root"

# Create project
create_project ${project_name} ${project_dir} -part xck26-sfvc784-2LV-c


# Set project properties
set obj [current_project]
if {$board_part ne ""} {
  set_property -name "board_part" -value ${board_part} -objects $obj
}
if {$board_connections ne ""} {
  set_property -name "board_connections" -value ${board_connections} -objects $obj
}
if {$board_id ne ""} {
  set_property -name "platform.board_id" -value ${board_id} -objects $obj
}
set_property -name "simulator_language" -value "Mixed" -objects $obj
set_property -name "target_language" -value ${target_language} -objects $obj
set_property -name "tool_flow" -value "Vivado" -objects $obj

# Define relative paths from script directory
set src_dir [file join $project_root src]
set sim_dir [file join $project_root simulation]
set constraints_dir [file join $project_root constraints]

# Create 'sources_1' fileset (if not found)
if {[string equal [get_filesets -quiet sources_1] ""]} {
  create_fileset -srcset sources_1
}

# Add source files
if {[file exists ${src_dir}]} {
    add_files -norecurse [glob -nocomplain ${src_dir}/*.vhd ${src_dir}/*.v ${src_dir}/*.sv]
}

# Create 'constrs_1' fileset (if not found)
if {[string equal [get_filesets -quiet constrs_1] ""]} {
  create_fileset -constrset constrs_1
}

# Add constraints
if {[file exists ${constraints_dir}]} {
    add_files -fileset constrs_1 -norecurse [glob -nocomplain ${constraints_dir}/*.xdc]
}

# Create 'sim_1' fileset (if not found)
if {[string equal [get_filesets -quiet sim_1] ""]} {
  create_fileset -simset sim_1
}

# Add simulation files
if {[file exists ${sim_dir}]} {
    add_files -fileset sim_1 -norecurse [glob -nocomplain ${sim_dir}/*.vhd ${sim_dir}/*.v ${sim_dir}/*.sv]
}

# Update compile order
update_compile_order -fileset sources_1
catch {update_compile_order -fileset sim_1}


puts "\n✅ PROJECT CREATED SUCCESSFULLY!"
puts "Project location: $project_dir"
puts "Next steps:"
puts "1. Add your HDL files to src/"
puts "2. Add your simulation files to simulation/"
puts "3. Add your constraints to constraints/"
puts "4. Add your constraints to constraints/"
