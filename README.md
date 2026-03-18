## Overview

This repository contains a collection of bash scripts and utilities used by test wrappers in the [redhat-performance](https://github.com/redhat-performance) project. These tools provide common functionality for system configuration, disk management, OS detection, NUMA information, and filesystem operations.

All scripts support a `--usage` or `-h` option to display help information.

---

## Exit Codes

All scripts use standardized exit codes defined in `error_codes`:

| Code | Name | Description |
|------|------|-------------|
| 0 | E_SUCCESS | Successful execution |
| 1 | E_PACKAGE_TOOL_PACKAGING | Package tool packaging error |
| 2 | E_PACKAGE_TOOL_REMOVE | Package tool removal error |
| 3 | E_PACKAGE_TOOL_UPDATE | Package tool update error |
| 101 | E_GENERAL | General error |
| 102 | E_PACKAGE_TOOL_NO_REMOVE | Package tool removal error |
| 103 | E_USAGE | Usage/help displayed or invalid usage |
| 104 | E_PARSE_ARGS | Argument parsing error |
| 105 | E_PCP_FAILURE | Performance Co-Pilot failure |
| 106 | E_INVAL_DATA | Invalid data |
| 107 | E_NO_ARGS | No arguments provided |
| 108 | E_VALIDATION_FAIL | Validation failure |
| 109 | E_DEVICE_IN_USE | At least one device is in use |
| 110 | E_NO_CONFIG_FILE | Unable to find configuration file |
| 127 | E_NO_CMD | Command not found |


E_NO_CMD=127
**Note:** Exit codes 1-99 indicate the test should be retried; codes ≥100 indicate do not retry.

---

## Core Utilities

### convert_csv_to_txt

**Purpose:** Converts CSV files to formatted plain text with fixed-width columns.

**Inputs:**
- `--results_in <file>` - Input CSV file (required).
- `--results_out <file>` - Output text file (required).
- `--field_size <n>` - Width of each field in characters (required).
- `--field_separator <char>` - CSV field separator (default: ":").
- `--usage/-h` - Display help information.

**Outputs:**
- **File:** Creates formatted text file at `--results_out` path.
- **Exit code:** 0 on success, error code on failure.
- **Side effects:** If the file designated by --results_out exists, it will be overwritten.

**Behavior:**
- Comment lines (starting with #) are preserved as-is.
- Lines without the field separator are preserved as-is.
- Spaces in values are converted to underscores.
- Values are right-aligned in fixed-width columns.

**Examples:**
```bash
./convert_csv_to_txt --results_in data.csv --results_out data.txt --field_size 15
./convert_csv_to_txt --results_in data.csv --results_out data.txt --field_size 20 --field_separator ","
```

---

### create_filesystem

**Purpose:** Creates and mounts a filesystem on a specified device.

**Inputs:**
- `--device <path>` - Device to create filesystem on (required).
- `--fs_type <type>` - Filesystem type: xfs, ext3, ext4, gfs, gfs2 (required).
- `--mount_dir <path>` - Mount point directory (required, created if needed).
- `--usage/-h` - Display help information.

**Outputs:**
- **stdout:** Command being executed (`mkfs -t ...`).
- **stderr:** Error messages.
- **Exit code:** 0 on success, 101 on error.

**Examples:**
```bash
./create_filesystem --device /dev/sdb --fs_type xfs --mount_dir /mnt/test
./create_filesystem --device /dev/mapper/vg-lv --fs_type ext4 --mount_dir /data
```

**Filesystem Options Used:**
- ext3/ext4: `-F` (force)
- xfs: `-f` (force)
- gfs/gfs2: `-O -p lock_nolock -j 1`

---

### csv_to_json

**Purpose:** Converts CSV files to JSON format with optional transposition.

**Inputs:**
- `--csv_file <file>` - Input CSV file (default: stdin).
- `--output_file <file>` - Output JSON file (default: stdout).
- `--separator <char>` - CSV separator (default: ",").
- `--transpose` - Transpose CSV (rows↔columns) before conversion.
- `--json_skip` - Skip processing (no-op, exits with 0).

**Outputs:**
- **stdout/File:** JSON array of records with 4-space indentation
- **stderr:** Error messages
- **Exit code:**
  - 0 on success.
  - 106 (E_INVALID_DATA) on parse error.
  - 127 (E_PACKAGE_FAIL) if pandas not installed.

**Requirements:** Python 3 with pandas library

**Examples:**
```bash
./csv_to_json --csv_file data.csv --output_file data.json
./csv_to_json --csv_file data.csv --separator ":" --transpose
cat data.csv | ./csv_to_json > data.json
```

---

### detect_numa

**Purpose:** Fetches NUMA (Non-Uniform Memory Access) information from the system using `lscpu`.

**Inputs:**
- `--node-count` - Display number of NUMA nodes (default operation).
- `--cpu-list` - List CPUs on NUMA nodes.
- `-n/--node <value>` - Restrict CPU list to specific nodes (supports ranges: 0-5, comma-separated: 0,2,4, or single: 1).
- `--include-empty` - Include empty NUMA nodes in count.
- `-i/--input <command>` - Provide alternative command for lscpu data (for testing).
- `-h/--help/--usage` - Display help information..

**Outputs:**
- **stdout:**
  - With `--node-count`: Number of NUMA nodes (default: excludes empty nodes).
  - With `--cpu-list`: CPU list(s), one per line.
- **stderr:** Error messages if invalid node specified.
- **Exit code:** 0 on success, 101 on error.

**Examples:**
```bash
./detect_numa                    # Output: 2 (number of nodes)
./detect_numa --cpu-list         # Output: CPU lists for all nodes
./detect_numa --cpu-list -n 0    # Output: CPUs on node 0
./detect_numa --node-count --include-empty  # Include empty nodes
```

---

### detect_os

**Purpose:** Detects the operating system and version information from `/etc/os-release`.

**Inputs:**
- `--os-version` - Get the OS version instead of the OS name.
- `--major-version` - Output only the major version (requires `--os-version`).
- `--minor-version` - Output only the minor version (requires `--os-version`).
- `--version-separator <char>` - Set separator between major/minor version (default: ".").
- `-h/--help/--usage` - Display help information.

**Outputs:**
- **stdout:** OS ID (e.g., "rhel", "fedora") or version information.
- **Exit code:** 0 on success, error code on failure.

**Examples:**
```bash
./detect_os                          # Output: rhel
./detect_os --os-version             # Output: 9.2
./detect_os --os-version --major-version  # Output: 9
```

---

### grab_disks

**Purpose:** Identifies available unused disks on the system or uses a specified disk list.

**Inputs:**
- Positional argument: Either "grab_disks" or comma-separated list of disk names.
- If "grab_disks": automatically discovers unused disks.
- If "none": exits with error on local systems (allowed only for cloud).
- If disk list: uses provided disks (with or without `/dev/` prefix).

**Environment Variables:**
- `TOOLS_BIN` - Path to tools directory.
- `to_sys_env` - Set to "local" for local system validation.

**Outputs:**
- **stdout:** Format: `<disk1> <disk2> ...:number_of_disks`.
  - Example: `/dev/sdb /dev/sdc:2`
- **stderr:** Error messages.
- **Exit code:** 0 on success, 101 if no disks found or invalid input.
- **Temporary files:** Creates and removes `disks` file.

**Examples:**
```bash
./grab_disks grab_disks          # Output: /dev/sdb /dev/sdc:2
./grab_disks sdb,sdc             # Output: /dev/sdb /dev/sdc:2
./grab_disks /dev/sdb,/dev/sdc   # Output: /dev/sdb /dev/sdc:2
```

**Algorithm:**
1. If `hw_config.yml` exists, reads storage devices from it.
2. Otherwise:
   - Lists all disks with `lsblk`.
   - Identifies root/boot/swap devices.
   - Excludes mounted filesystems.
   - Returns unused disks in reverse order.

---

### invoke_test

**Purpose:** Wrapper for invoking tests with tuned profile tracking.

**Inputs:**
- `--command <string>` - Command to execute (required).
- `--options <strings>` - Options to pass to command.
- `--test_name <string>` - Test name for status tracking (required).
- `-h` - Display help information.

**Outputs:**
- **File:** Creates `/tmp/<test_name>_tuned.status` with tuned profile information.
- **Exit code:** 103 on usage error, 101 on general error.

**Behavior:**
- On RHEL: Captures active tuned profile.
- Checks if tuned service is inactive (writes warning).
- Requires `to_os_running` environment variable.

**Examples:**
```bash
./invoke_test --command "fio" --options "--name=test" --test_name mytest
```

---

### lvm_create

**Purpose:** Creates an LVM (Logical Volume Manager) volume group and logical volume from specified devices.

**Inputs:**
- `--devices <list>` - Comma-separated list of devices (required).
- `--lvm_grp <name>` - LVM group name (required).
- `--lvm_vol <name>` - LVM volume name (required).
- `--wipefs` - Wipe filesystem signatures before LVM operations.
- `--usage/-h` - Display help information.

**Outputs:**
- **stdout:** Progress messages.
- **stderr:** Error messages if operations fail.
- **Exit code:** 0 on success, 101 on error.
- **Side effects:**
  - Removes existing LV/VG with same names.
  - Creates physical volumes (`pvcreate`).
  - Creates volume group (`vgcreate`).
  - Creates logical volume with striping across all devices.
  - Total size = (sum of device sizes in GB) - 200GB.
  - Wipes the created logical volume.

**Examples:**
```bash
./lvm_create --devices /dev/sdb,/dev/sdc --lvm_grp vg01 --lvm_vol lv01
./lvm_create --devices sdb,sdc --lvm_grp data_vg --lvm_vol data_lv --wipefs
```

**Note:** Script includes 60-second sleeps after `pvcreate` and `vgcreate` operations.

---

### lvm_delete

**Purpose:** Deletes an LVM logical volume and volume group.

**Inputs:**
- `--lvm_vol <name>` - LVM volume name (required).
- `--lvm_grp <name>` - LVM group name (required).
- `--mount_pnt <path>` - Mount point to unmount.
- `--usage/-h` - Display help information.

**Outputs:**
- **Exit code:** 0 on success, 101 on error
- **Side effects:**
  - Unmounts the filesystem from the designated mount point.
  - Removes logical volume.
  - Removes volume group.

**Examples:**
```bash
./lvm_delete --lvm_vol vg01 --lvm_grp lv01 --mount_pnt /mnt/test
```

---

### package_tool

**Purpose:** Cross-distribution package management wrapper for installing system and pip packages.

**Inputs:**
- `--is_installed <package>` - Check if package is installed (exits with 0/1).
- `--no_packages <0|1>` - Skip system package installation if 1.
- `--no_system_packages <0|1>` - Skip system packages if 1.
- `--no_pip_packages <0|1>` - Skip pip packages if 1.
- `--packages <list>` - Comma-separated list of system packages to install.
- `--pip_packages <list>` - Comma-separated list of pip modules to install.
- `--python_exec <path>` - Python interpreter for pip (default: "python3").
- `--remove_packages <list>` - Comma-separated list of packages to remove.
- `--update` - Update all system packages.
- `--update_cache <0|1>` - Update package cache before operations (default: 1).
- `--wrapper_config <json_file>` - JSON file with dependencies specification.
- `-h/--usage` - Display help information.

**Outputs:**
- **stdout:** Package installation progress.
- **stderr:** Error messages.
- **Exit code:**
  - 0 (E_SUCCESS) on success
  - 1 (E_PACKAGE_TOOL_PACKAGING) on package installation failure or `--is_installed` check failure.
  - 2 (E_PACKAGE_TOOL_REMOVE) on package removal failure.
  - 3 (E_PACKAGE_TOOL_UPDATE) on system update failure.
  - 101 (E_GENERAL) if package manager cannot be determined.

**Supported Distributions:**
- RHEL/Fedora/CentOS: dnf or yum
- Ubuntu/Debian: apt
- SLES/openSUSE: zypper

**Examples:**
```bash
./package_tool --packages bc,jq,lsblk
./package_tool --pip_packages pandas,numpy
./package_tool --wrapper_config test_deps.json
./package_tool --is_installed git  # Check if installed
./package_tool --update  # Update all packages
```

**JSON Configuration Format:**
```json
{
  "dependencies": {
    "rhel": ["package1", "package2"],
    "ubuntu": ["pkg1-ubuntu", "pkg2-ubuntu"],
    "pip": ["pandas", "pydantic"]
  }
}
```

**Advanced JSON (Version-Specific):**
```json
{
  "dependencies": {
    "rhel": {
      "9.2": ["pkg-9.2"],
      "9": ["pkg-9.x"],
      "default": ["pkg-any"]
    }
  }
}
```

**Behavior:**
- Automatically detects OS and selects appropriate package manager.
- Updates package cache once before first install (unless disabled).
- Installs python3-pip automatically when pip packages requested.
- On Ubuntu, uses `--break-system-packages` flag for pip.
- Falls back to versioned dependencies: full version → major version → default.
- Requires `jq` for JSON parsing (auto-installs if needed).

---

### umount_filesystems

**Purpose:** Unmounts multiple filesystems created by test wrappers using a numbered naming scheme.

**Inputs:**
- `--mount_pnt <prefix>` - Mount point directory prefix (required)
- `--number_mount_pnts <n>` - Number of mount points (required).
- `-h/--usage` - Display help information.

**Outputs:**
- **Exit code:** 0 on success, 103 on usage error
- **Side effects:** Unmounts filesystems from `${mount_pnt}0` to `${mount_pnt}N-1`

**Examples:**
```bash
./umount_filesystems --mount_pnt /mnt/disk --number_mount_pnts 3
# Unmounts: /mnt/disk0, /mnt/disk1, /mnt/disk2
```

**Behavior:**
- Iterates through numbered mount points (0-indexed)
- Calls `umount` for each mount point: `${mount_pnt}0`, `${mount_pnt}1`, etc.

---

### verify_results

**Purpose:** Validates JSON test results against a pydantic schema model.

**Inputs:**
- `--file <file>` - JSON file to verify (default: stdin).
- `--schema_file <file>` - Python file containing the schema model (required).
- `--class_name <name>` - Class name in schema file to validate against (default: "Results").
- `--verify_skip` - Skip verification (no-op, exits with 0).
- `--usage` - Display help information.

**Outputs:**
- **stdout:** "Results verified" on success.
- **stderr:** Validation error details on failure.
- **Exit code:**
  - 0 on success or if `--verify_skip` used.
  - 104 (E_PARSE_ARGS) if schema file or class not found.
  - 106 (E_VALIDATION_FAIL) if validation fails.
  - 108 (E_VALIDATION_FAIL) if we have a data validation error.
  - 127 (E_PACKAGE_FAIL) if pydantic not installed.

**Requirements:** Python 3 with pydantic library

**Examples:**
```bash
./verify_results --file results.json --schema_file schema.py --class_name Results
cat results.json | ./verify_results --schema_file schema.py
./verify_results --verify_skip  # Skip verification, returns 0
```

**Behavior:**
- Imports the schema class dynamically from the specified Python file
- Validates JSON data as a list of schema objects using pydantic
- Reports detailed validation errors if schema doesn't match

---

## Helper Files

### error_codes

**Purpose:** Defines standardized exit codes for all scripts.

**Usage:**
```bash
source ${TOOLS_BIN}/error_codes
exit $E_SUCCESS  # or other error code
```

See Exit Codes section above for complete list.

---

### general_setup

**Purpose:** Common setup script sourced by test wrappers. Processes standard command-line options and sets up the test environment.

**Exported Variables:**

| Variable | Description | Default |
|----------|-------------|---------|
| `TOOLS_BIN` | Tools directory path | Script directory or `~/test_tools` |
| `to_home_root` | Parent home directory | Current user's home parent |
| `to_configuration` | Configuration name | hostname |
| `to_times_to_run` | Number of test iterations | 1 |
| `to_user` | Test user | Current user |
| `to_sys_type` | System type | hostname |
| `to_sys_env` | System environment | "local" |
| `to_sysname` | System name | hostname |
| `to_tuned_setting` | Tuned profile | Auto-detected |
| `to_no_pkg_install` | Disable package installation | 0 |
| `to_use_pcp` | Use Performance Co-Pilot | 0 |
| `to_os_running` | Current OS | Auto-detected |

**Common Options:**
- `--debug` - Enable bash -x debugging.
- `--home_parent <path>` - Set parent home directory.
- `--host_config <name>` - Configuration name.
- `--iterations <n>` - Number of test runs.
- `--iteration_default <n>` - Default iteration count.
- `--no_pkg_install` - Disable all package installation.
- `--no_system_packages` - Disable system package installation.
- `--no_pip_packages` - Disable pip package installation.
- `--run_label <label>` - Run label.
- `--run_user <user>` - Test execution user.
- `--sys_type <type>` - System type (aws, azure, local, etc.).
- `--sysname <name>` - System name.
- `--test_tools_release <tag>` - Use specific test_tools version.
- `--tuned_setting <profile>` - Set tuned profile.
- `--usage` - Display help information..
- `--verify_skip` - Skip test verification.
- `--json_skip` - Skip JSON conversion.
- `--use_pcp` - Enable PCP monitoring.

**Side Effects:**
- Sources `~/.bashrc`
- Installs verification dependencies (unless skipped).
- Records active tuned profile to `~/tuned_before`.
- May clone specific test_tools release from GitHub.
- Sets up USR1 signal trap for command-not-found handling.
- Exports environment variables.

**Usage Pattern:**
```bash
#!/bin/bash
if [[ $TOOLS_BIN == "" ]]; then
    TOOLS_BIN=$(realpath $(dirname $0))
fi
source ${TOOLS_BIN}/general_setup

# Your wrapper-specific code here
# Can now use all to_* variables
```

---

### helpers.inc

**Purpose:** Bash library providing common helper functions.

**Functions:**

#### retrieve_time_stamp()
- **Returns:** ISO 8601 UTC timestamp (e.g., "2026-03-16T14:23:45Z").
- **Usage:** Provides a routine for all wrappers to call to get a common timestamp format.

#### build_data_string()
- **Parameters:** Any number of arguments.
- **Returns:** Comma-separated string with all commas removed from values.
- **Usage:** Building CSV records.

**Variables:**
- `test_start_time` - Timestamp when script sourced.

**Example:**
```bash
source helpers.inc
timestamp=$(retrieve_time_stamp)
data=$(build_data_string "value1" "value,with,commas" "value3")
# Result: "value1,valuewithcommas,value3"
```

---

### save_results

**Purpose:** Common script for saving and exporting test results. Creates timestamped result directories, archives test data, and tracks tuned profile changes.

**Inputs:**
- `--curdir <dir>` - Directory where wrapper started execution (default: `pwd`).
- `--home_root <dir>` - Running user's home directory.
- `--test_name <name>` - Name of the test (required for directory naming).
- `--results <file>` - Primary results file to export.
- `--other_files <file,file,...>` - Comma-separated list of additional files to export.
- `--tar_file <tarball>` - Tar file to extract into results directory.
- `--copy_dir <dir>` - Entire directory to copy into results.
- `--tuned_setting <profile>` - Tuned profile setting for archive naming.
- `--version <version>` - Version number/commit of the test (or "None").
- `--user <name>` - Name of user who ran the wrapper.
- `-h/--usage` - Display help information.

**Outputs:**
- **Directory:** `$home_root/$user/export_results/<test_name>_<timestamp>/`.
  - Contains all exported files and results.
  - Timestamp format: `YYYY.MM.DD-HH.MM.SS`.
- **Files:**
  - `tuned_setting` - Differance of tuned profile before/after test (RHEL only).
  - `version` - Test version or commit information.
  - All specified result files and directories.
- **Archives:**
  - `/tmp/results_<test_name>_<tuned_setting>.tar` - Full results tarball
  - `/tmp/results_<test_name>.zip` - Zip archive for Zathra integration
- **Exit code:** 0 (E_SUCCESS) on completion

**Environment Variables Used:**
- `TOOLS_BIN` - Tools directory path
- `to_os_running` - Operating system (for tuned profile tracking)

**Behavior:**
1. Creates export directory structure if needed.
2. Copies primary results file.
3. Checks tuned profile changes (RHEL only):
   - Compares `~/tuned_before` with current tuned-adm output
   - Warns if tuned settings changed during test
4. Copies additional files specified in `--other_files`.
5. Extracts tar file if provided.
6. Copies entire directory if `--copy_dir` specified.
7. Records version information.
8. Copies metadata files (`meta_data*.yml`, `hw_info.out`).
9. Creates tar archive and zip file in `/tmp`.

**Usage Pattern:**
```bash
#!/bin/bash
source ${TOOLS_BIN}/general_setup

# Run test
# ...

# Save results
${TOOLS_BIN}/save_results \
    --curdir $curdir \
    --home_root $to_home_root \
    --test_name "mytest" \
    --results results.csv \
    --other_files "log1.txt,log2.txt" \
    --tuned_setting $to_tuned_setting \
    --version $test_version \
    --user $to_user
```

**Notes:**
- Automatically includes metadata and hardware info files if present.
- Creates symbolic links for files (internal `link_files` function).
- Preserves directory structure when copying.
- Replaces existing zip files with same name.
- Tuned profile tracking only active on RHEL systems.

---

## Additional Scripts

### convert_val

**Purpose:** Converts values between different units (memory sizes or time durations).

**Inputs:**
- `--value <n>` - Value to convert (default: 1).
- `--from_unit <unit>` - Source unit (default: "K" for memory, "s" for time).
- `--to_unit <unit>` - Destination unit (default: "B" for memory, "ns" for time).
- `--time_val` - Interpret as time units instead of memory units.
- `-h/--help/--usage` - Display help information.

**Outputs:**
- **stdout:** Converted value with unit suffix.
- **Exit code:** 0 on success, 101 on invalid unit, 103 on usage, 104 on parse error.

**Memory Units:**
- **SI:** B, K, M, G, T (base 1000)
- **IEC:** Ki, Mi, Gi, Ti (base 1024)

**Time Units:**
- ns (nanoseconds), us (microseconds), ms (milliseconds)
- s (seconds), m (minutes), h (hours)

**Examples:**
```bash
./convert_val --from_unit M --value 1024 --to_unit G
# Output: 1G

./convert_val --from_unit Mi --value 1024 --to_unit Gi
# Output: 1Gi

./convert_val --from_unit Mi --value 1024 --to_unit Ki
# Output: 1048576Ki

./convert_val --from_unit Mi
# Output: 1048576B  (shows Mi in base bytes)

./convert_val --time_val --from_unit s --value 10 --to_unit ms
# Output: 10000ms

./convert_val --time_val --from_unit s --value 60 --to_unit m
# Output: 1m

./convert_val --time_val --from_unit h
# Output: 3600000000000ns  (shows h in base nanoseconds)
```

**Behavior:**
- Uses `numfmt` for memory conversions (SI and IEC standards).
- Custom calculation for time conversions.
- All conversions go through base unit (bytes for memory, nanoseconds for time).
- Outputs integer results using `bc` for arithmetic.

---

### detect_mounts

**Purpose:** Checks if specified devices are currently mounted or used by LVM.

**Inputs:**
- Positional arguments: Device paths to check (e.g., `/dev/sdb`, `/dev/sdc`)
- `-h` - Display help information.

**Outputs:**
- **stdout:** Usage message (only with `-h`)
- **Exit code:**
  - 0 (E_SUCCESS) if none of the devices are mounted
  - 103 (E_USAGE) on usage error
  - 109 (E_DEVICE_IN_USE) if any device is mounted or used by LVM

**Examples:**
```bash
./detect_mounts /dev/sdb /dev/sdc
# Exit 0 if neither is mounted, 109 if either is mounted

./detect_mounts /dev/sdb
# Check single device
```

**Behavior:**
- Creates temporary file with list of mounted devices from `mount` output.
- Checks LVM physical volumes used by any logical volumes in `/dev/mapper`.
- Searches for exact device path matches.
- Returns error if ANY specified device is found.
- Cleans up temporary file on exit.

**Use Case:**
- Called before disk operations to ensure devices are not in use.
- Prevents accidental formatting of mounted filesystems.

---

### gather_data

**Purpose:** Collects comprehensive system information for test documentation.

**Inputs:**
- No command-line arguments.
- Reads `$to_os_running` environment variable for OS-specific behavior.

**Outputs:**
- **stdout:** Formatted system information report.
- **Exit code:** Always 0.
- **Temporary files:** Creates `/tmp/lscpu.tmp`, `/tmp/data_gather.tmp*`.

**Information Collected:**
- **General:** Hostname, OS release, timestamp.
- **Hardware:** CPU architecture, model, count, NUMA configuration, product name, BIOS info.
- **Memory:** Total memory, hugepage size, NUMA node memory distribution.
- **Boot:** Kernel command-line options.
- **Tuned:** Active tuned profile (RHEL only).
- **Security:** SELinux status.
- **Storage:** Disk information with model names.
- **Filesystems:** Mount points, mount options, overlay detection.

**Examples:**
```bash
./gather_data > system_info.txt
to_os_running=rhel ./gather_data
```

**Special Features:**
- Detects multiple mounts of the same directory (overlay detection).
- Shows physical devices used by LVM volumes.
- RHEL-specific tuned profile detection.

---

### generate_intervals

**Purpose:** Generates a sequence of interval values for testing (e.g., for ramping up load).

**Inputs:**
- `--interval <n>` - Number of intervals to create (required).
- `--max_value <n>` - Maximum value to reach (required).
- `-h/--usage` - Display help information..

**Outputs:**
- **stdout:** Comma-separated sequence of values.
- **Exit code:** 0 on success, 101 on error, 107 on no args.

**Examples:**
```bash
./generate_intervals --interval 4 --max_value 100
# Output: 1,25,50,75,100

./generate_intervals --interval 4 --max_value 99
# Output: 1,24,48,72,96,99

./generate_intervals --interval 1 --max_value 50
# Output: 1,50
```

**Behavior:**
- Calculates evenly-spaced intervals using `bc` for division.
- Always starts at 1.
- Always includes max_value (adds it if not evenly divisible).
- Interval count cannot exceed max_value.

---

### get_params_file

**Purpose:** Locates test parameter configuration files with fallback logic.

**Inputs:**
- `-c <name>` - Configuration name (required).
- `-d <dir>` - Directory containing test_params subdirectory (required)
- `-t <test>` - Test name (required).

**Outputs:**
- **stdout:** Full path to parameter file if found, or "No config file".
- **Exit code:** 0 if file found, 110 if not found.

**Examples:**
```bash
./get_params_file -c production -d /home/user/tests -t fio
# Looks for: /home/user/tests/test_params/production.fio

./get_params_file -c myhost -d /var/tests -t benchmark
# Looks for: /var/tests/test_params/myhost.benchmark
# Falls back to: /var/tests/test_params/zathras_light.benchmark
```

**Search Order:**
1. `${directory}/test_params/${config_name}.${test}` - Config-specific
2. `${directory}/test_params/zathras_light.${test}` - Default "light" version

---

### get_tuned_setting

**Purpose:** Retrieves the currently active tuned profile on the system.

**Inputs:**
- None (reads `$TOOLS_BIN` environment variable)

**Outputs:**
- **stdout:** Active tuned profile name, or "tuned_none" if not active/installed.
- **Exit code:** Always 0.

**Examples:**
```bash
./get_tuned_setting
# Output: throughput-performance

./get_tuned_setting  # On system without tuned
# Output: tuned_none
```

**Behavior:**
- Checks for `/usr/sbin/tuned-adm` existence.
- Parses `tuned-adm active` output to extract profile name.
- Returns "tuned_none" if:
  - tuned-adm not installed
  - No active profile (output contains "profile.")

---

### move_data

**Purpose:** Copies metadata and hardware information files between directories.

**Inputs:**
- Positional argument 1: Source directory
- Positional argument 2: Destination directory

**Outputs:**
- **Exit code:** 0 on success, 101 on copy error.
- **Side effects:** Copies files if they exist:
  - `meta_data*.yml` (glob pattern)
  - `hw_info.out`

**Examples:**
```bash
./move_data /tmp/test_results /home/user/export
```

**Behavior:**
- Silently skips files that don't exist.
- Only errors if `cp` command fails for existing files>

---

### test_header_info

**Purpose:** Generates standardized test metadata headers for CSV/text result files.

**Inputs:**
- `--field_header <string>` - CSV column header line.
- `--field_separ <char>` - Field separator in directory name (default: "_").
- `--front_matter` - Include full system information header.
- `--host <name>` - Host configuration name.
- `--info_in_dir_name "<dir> <fields>"` - Extract metadata from directory name structure.
- `--meta_output <string>` - Additional metadata string (can be repeated).
- `--results_file <file>` - Output file to write headers to (required).
- `--results_version <version>` - Test results format version.
- `--sys_type <type>` - System environment type.
- `--test_name <name>` - Test name.
- `--tuned <profile>` - Tuned profile setting.
- `-h/--usage` - Display help information..

**Outputs:**
- **File:** Writes formatted headers to `--results_file`
- **Exit code:** 0 on success, 103 on usage error

**Examples:**
```bash
./test_header_info --results_file results.csv --test_name fio --front_matter \
  --host myserver --sys_type aws --tuned throughput-performance

./test_header_info --results_file out.csv --field_header "IOPS,Bandwidth,Latency"

# Extract info from directory name
dir="fio_ndisks_4_ioengine_libaio_2024.01.15"
./test_header_info --results_file test.csv --info_in_dir_name "$dir 2,3 4,5"
# Extracts: ndisks: 4, ioengine: libaio
```

**Header Sections:**
- **Front Matter** (with `--front_matter`):
  - Test name, results version, host, system environment, tuned profile
  - OS/kernel version, NUMA nodes, CPU family, CPU count, memory
- **Test Metadata:**
  - Custom metadata from `--meta_output` options
  - Extracted directory name fields
- **CSV Header:** Field names followed by "Start_Date,End_Date"

**Directory Name Parsing:**
- Format: `--info_in_dir_name "<dir_name> <field_positions>"`
- Field positions are comma-separated numbers (1-indexed)
- Underscore separators in field values are converted to spaces
- Example: field `2,3` from `test_ndisks_4_type_ssd` extracts "ndisks: 4"

---

## Dependencies

### Required Commands
- `bash` - Shell interpreter
- `lsblk` - List block devices
- `df` - Disk free
- `grep`, `sed`, `awk` - Text processing
- `getopt` - Argument parsing
- `realpath` - Path resolution
- `date` - Timestamp generation

### Optional Commands
- `jq` - JSON parsing (falls back to bash regex)
- `curl` or `wget` - File downloads
- `sha256sum` / `shasum` - Checksum verification
- `lscpu` - CPU information (for detect_numa)
- `tuned-adm` - Tuned profile management (RHEL)
- Python 3 with pandas - For csv_to_json

### LVM Tools (for lvm_create/lvm_delete)
- `pvcreate`, `vgcreate`, `lvcreate`
- `lvremove`, `vgremove`
- `wipefs`

### Filesystem Tools (for create_filesystem)
- `mkfs` - Filesystem creation
- `mount` / `umount` - Mount operations

---

## Environment Variables

Scripts respect these environment variables:

- `TOOLS_BIN` - Override tools directory location
- `to_sys_env` - System environment type (local, aws, azure, etc.)
- `to_os_running` - Operating system (set by general_setup)
- `to_no_pkg_install` - Disable package installation (set by general_setup)

---

## Configuration Files

### hw_config.yml
Optional file for specifying hardware configuration. If present in the current directory, `grab_disks` reads storage devices from it:

```yaml
storage: /dev/sdb,/dev/sdc,/dev/sdd
```

### ignore_missing_cmds.txt
Lists commands that are expected to be missing on certain operating systems (used by general_setup).

Format: `os_name,command_name,`

Example:
```
suse,tuned-adm,
```

---

## Testing

The `tests/` directory contains test scripts:

- `test_detect_numa` - Tests NUMA detection functionality
- `test_detect_os` - Tests OS detection functionality
- `assert.sh` - Assertion library for tests
- `resources/` - Test data and fixtures

---

## Integration with Test Wrappers

These tools are designed to be sourced and called from test wrapper scripts in the redhat-performance organization. Typical wrapper pattern:

```bash
#!/bin/bash

# Set TOOLS_BIN
if [[ $TOOLS_BIN == "" ]]; then
    TOOLS_BIN=$(realpath $(dirname $0))
fi

# Source common setup (handles common options)
source ${TOOLS_BIN}/general_setup

# Wrapper-specific option parsing
# ...

# Use helper functions
disks_info=$(${TOOLS_BIN}/grab_disks grab_disks)
disks=$(echo $disks_info | cut -d: -f1)

# Create filesystem
${TOOLS_BIN}/create_filesystem --device $disk --fs_type xfs --mount_dir /mnt/test

# Run test
# ...

# Exit with appropriate code
exit $E_SUCCESS
```

---

## Notes

1. All scripts use `set -x` debug mode when `--debug` is passed via general_setup.
2. Scripts validate input parameters and exit with appropriate error codes.
3. Most scripts support `--usage`, `-h`, or `--help` for inline documentation.
4. The `general_setup` script provides robust error handling including command-not-found tracking.
5. Exit codes follow a consistent pattern: 0=success, 1-99=retry, ≥100=fatal error.

---

## License

All scripts are licensed under GPL v2. See individual file headers for copyright information.

Copyright (C) 2022-2026 David Valin, Keith Valin, and contributors.
