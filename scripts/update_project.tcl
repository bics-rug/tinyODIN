#!/usr/bin/tclsh
# scripts/update_project.tcl - Essential project file synchronization

# Get script directory and project info
set script_dir [file normalize [file dirname [info script]]]
set project_root [file dirname $script_dir]
set project_dir [file join $project_root "tinyODIN_r01"]

# Universal project handler (same as before)
proc ensure_project {} {
    global project_dir
    
    if {![catch {current_project} project_name]} {
        puts "=== PROJECT FILE SYNCHRONIZATION ==="
        puts "✅ Using open project: $project_name"
        return $project_name
    }
    
    puts "=== PROJECT FILE SYNCHRONIZATION ==="
    puts "No project currently open, searching for project..."
    
    set project_files [glob -nocomplain "$project_dir/*.xpr"]
    if {[llength $project_files] == 0} {
        puts "❌ No Vivado project found in $project_dir"
        error "No project available"
    }
    
    set project_file [lindex $project_files 0]
    puts "Found project: [file tail $project_file]"
    open_project $project_file
    
    set project_name [get_property NAME [current_project]]
    puts "✅ Project opened: $project_name"
    return $project_name
}

# Utility function to normalize file paths
proc normalize_files {file_list} {
    set normalized_list [list]
    foreach file $file_list {
        lappend normalized_list [file normalize $file]
    }
    return $normalized_list
}

# Sync source files
proc sync_sources {} {
    global project_root
    
    puts "\n--- SYNCING SOURCE FILES ---"
    set src_dir [file join $project_root "src"]
    
    # Get current files in project
    set project_files [get_files -filter {FILE_TYPE == VHDL || FILE_TYPE == Verilog || FILE_TYPE == SystemVerilog}]
    set project_files [normalize_files $project_files]
    
    # Get files from filesystem
    set fs_files [list]
    if {[file exists $src_dir]} {
        foreach ext {vhd vhdl v sv} {
            set files [glob -nocomplain "$src_dir/*.$ext"]
            set fs_files [concat $fs_files $files]
        }
    }
    set fs_files [normalize_files $fs_files]
    
    set changes 0
    
    # Add new files
    foreach fs_file $fs_files {
        if {[lsearch -exact $project_files $fs_file] == -1} {
            add_files -norecurse $fs_file
            puts "  + Added: [file tail $fs_file]"
            incr changes
        }
    }
    
    # Remove missing files
    foreach proj_file $project_files {
        if {[lsearch -exact $fs_files $proj_file] == -1 && ![file exists $proj_file]} {
            puts "  - Removed: [file tail $proj_file]"
            remove_files -fileset sources_1 $proj_file            
            incr changes
        }
    }
    
    if {$changes == 0} {
        puts "  ✓ No changes needed"
    }
    
    return $changes
}

# Sync constraint files
proc sync_constraints {} {
    global project_root
    
    puts "\n--- SYNCING CONSTRAINT FILES ---"
    set const_dir [file join $project_root "constraints"]
    
    # Get current constraint files
    set project_files [get_files -of_objects [get_filesets constrs_1]]
    set project_files [normalize_files $project_files]
    
    # Get files from filesystem
    set fs_files [list]
    if {[file exists $const_dir]} {
        foreach ext {xdc ucf} {
            set files [glob -nocomplain "$const_dir/*.$ext"]
            set fs_files [concat $fs_files $files]
        }
    }
    set fs_files [normalize_files $fs_files]
    
    set changes 0
    
    # Add new files
    foreach fs_file $fs_files {
        if {[lsearch -exact $project_files $fs_file] == -1} {
            add_files -fileset constrs_1 -norecurse $fs_file
            puts "  + Added: [file tail $fs_file]"
            incr changes
        }
    }
    
    # Remove missing files
    foreach proj_file $project_files {
        if {[lsearch -exact $fs_files $proj_file] == -1 && ![file exists $proj_file]} {
            puts "  - Removed: [file tail $proj_file]"
            remove_files -fileset constrs_1 $proj_file
            incr changes
        }
    }
    
    if {$changes == 0} {
        puts "  ✓ No changes needed"
    }
    
    return $changes
}

# Sync simulation files
proc sync_simulation {} {
    global project_root
    
    puts "\n--- SYNCING SIMULATION FILES ---"
    set sim_dir [file join $project_root "simulation"]
    
    # Get current simulation files
    set project_files [get_files -of_objects [get_filesets sim_1]]
    set project_files [normalize_files $project_files]
    
    # Get files from filesystem
    set fs_files [list]
    if {[file exists $sim_dir]} {
        foreach ext {vhd vhdl v sv} {
            set files [glob -nocomplain "$sim_dir/*.$ext"]
            set fs_files [concat $fs_files $files]
        }
    }
    set fs_files [normalize_files $fs_files]
    
    set changes 0
    
    # Add new files
    foreach fs_file $fs_files {
        if {[lsearch -exact $project_files $fs_file] == -1} {
            add_files -fileset sim_1 -norecurse $fs_file
            puts "  + Added: [file tail $fs_file]"
            incr changes
        }
    }
    
    # Remove missing files
    foreach proj_file $project_files {
        if {[lsearch -exact $fs_files $proj_file] == -1 && ![file exists $proj_file]} {
            puts "  - Removed: [file tail $proj_file]"
            remove_files -fileset sim_1 $proj_file
            incr changes
        }
    }
    
    if {$changes == 0} {
        puts "  ✓ No changes needed"
    }
    
    return $changes
}

# Update compile order and validate
proc update_project {} {
    puts "\n--- UPDATING PROJECT ---"
    
    # Update compile orders
    update_compile_order -fileset sources_1
    puts "  ✓ Updated source compile order"
    
    catch {update_compile_order -fileset sim_1}
    puts "  ✓ Updated simulation compile order"
    
    # # Validate top module
    # set current_top [get_property top [current_fileset]]
    # set source_files [get_files -filter {FILE_TYPE == VHDL || FILE_TYPE == Verilog || FILE_TYPE == SystemVerilog}]
    
    # set top_exists 0
    # foreach file $source_files {
    #     set module_name [file rootname [file tail $file]]
    #     if {$module_name eq $current_top} {
    #         set top_exists 1
    #         break
    #     }
    # }
    
    # if {!$top_exists && $current_top ne ""} {
    #     puts "  ⚠ Warning: Top module '$current_top' not found"
    #     # Try to find a suitable replacement
    #     foreach file $source_files {
    #         set module_name [file rootname [file tail $file]]
    #         if {[string match "*top*" $module_name] || [string match "*main*" $module_name]} {
    #             set_property top $module_name [current_fileset]
    #             puts "  ✓ Set new top module: $module_name"
    #             break
    #         }
    #     }
    # } else {
    #     puts "  ✓ Top module validated: $current_top"
    # }
}

proc show_status {} {
    puts "\n=== PROJECT STATUS ==="
    puts "Project: [get_property NAME [current_project]]"
    puts "Location: [get_property DIRECTORY [current_project]]"
    puts "Part: [get_property PART [current_project]]"
    
    set src_count [llength [get_files -filter {FILE_TYPE == VHDL || FILE_TYPE == Verilog || FILE_TYPE == SystemVerilog}]]
    set const_count [llength [get_files -of_objects [get_filesets constrs_1]]]
    set sim_count [llength [get_files -of_objects [get_filesets sim_1]]]
    
    puts "Files in project:"
    puts "  Sources: $src_count"
    puts "  Constraints: $const_count"
    puts "  Simulation: $sim_count"
    
    puts "Top module: [get_property top [current_fileset]]"
    puts "Target language: [get_property target_language [current_project]]"
}

proc main_sync {} {
    set total_changes 0
    
    # Sync all file types
    incr total_changes [sync_sources]
    incr total_changes [sync_constraints]
    incr total_changes [sync_simulation]
    
    update_project
    
    puts "\n=== SYNCHRONIZATION COMPLETE ==="
    if {$total_changes > 0} {
        puts "✅ Made $total_changes changes to project"
    } else {
        puts "✅ Project already synchronized"
    }
    
    return $total_changes
}

# Ensure we have a project ready
if {[catch {ensure_project} project_name]} {
    exit 1
}

puts "Working with project: $project_name"

# Command line handling
set command "sync"
if {[info exists argc] && $argc > 0} {
    set command [lindex $argv 0]
}

switch $command {
    "sync" {
        main_sync
        # save_project_as $project_name $project_dir
    }
    "sources" {
        sync_sources
        # save_project_as $project_name $project_dir
    }
    "constraints" {
        sync_constraints
        # save_project_as $project_name $project_dir
    }
    "sim" {
        sync_simulation
        # save_project_as $project_name $project_dir
    }
    "status" {
        show_status
    }
    "help" {
        puts "Project File Synchronization Script"
        puts "Usage: vivado -mode batch -source scripts/update_project.tcl -tclargs <command>"
        puts ""
        puts "Commands:"
        puts "  sync        - Synchronize all files (default)"
        puts "  sources     - Sync source files only"
        puts "  constraints - Sync constraint files only"
        puts "  sim         - Sync simulation files only"
        puts "  status      - Show project status"
        puts "  help        - Show this help"
        puts ""
        puts "This script keeps your Vivado project synchronized with:"
        puts "  - src/*.{vhd,v,sv}           (HDL source files)"
        puts "  - constraints/*.{xdc,ucf}    (Constraint files)"
        puts "  - simulation/*.{vhd,v,sv}           (Simulation files)"  
    }
    default {
        puts "❌ Unknown command: $command"
        puts "Use 'help' to see available commands"
        exit 1
    }
}