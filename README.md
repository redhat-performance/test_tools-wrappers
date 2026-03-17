 Copyright (C) 2022  David Valin dvalin@redhat.com

 This program is free software; you can redistribute it and/or
 modify it under the terms of the GNU General Public License
 as published by the Free Software Foundation; either version 2
 of the License, or (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program; if not, write to the Free Software
 Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

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
| 101 | E_GENERAL | General error |
| 102 | E_PACKAGE_TOOL_NO_REMOVE | Package tool removal error |
| 103 | E_USAGE | Usage/help displayed or invalid usage |
| 104 | E_PARSE_ARGS | Argument parsing error |
| 105 | E_PCP_FAILURE | Performance Co-Pilot failure |
| 106 | E_INVAL_DATA | Invalid data |
| 107 | E_NO_ARGS | No arguments provided |
| 127 | E_NO_CMD | Command not found |

**Note:** Exit codes 1-99 indicate the test should be retried; codes ≥100 indicate do not retry.

---

## Core Utilities

### detect_os

**Purpose:** Detects the operating system and version information from `/etc/os-release`.

**Inputs:**
- `--os-version` - Get the OS version instead of the OS name
- `--major-version` - Output only the major version (requires `--os-version`)
- `--minor-version` - Output only the minor version (requires `--os-version`)
- `--version-separator <char>` - Set separator between major/minor version (default: ".")
- `-h/--help/--usage` - Display help

**Outputs:**
- **stdout:** OS ID (e.g., "rhel", "fedora") or version information
- **Exit code:** 0 on success, error code on failure

**Examples:**
```bash
./detect_os                          # Output: rhel
./detect_os --os-version             # Output: 9.2
./detect_os --os-version --major-version  # Output: 9
```

---

### detect_numa

**Purpose:** Fetches NUMA (Non-Uniform Memory Access) information from the system using `lscpu`.

**Inputs:**
- `--node-count` - Display number of NUMA nodes (default operation)
- `--cpu-list` - List CPUs on NUMA nodes
- `-n/--node <value>` - Restrict CPU list to specific nodes (supports ranges: 0-5, comma-separated: 0,2,4, or single: 1)
- `--include-empty` - Include empty NUMA nodes in count
- `-i/--input <command>` - Provide alternative command for lscpu data (for testing)
- `-h/--help/--usage` - Display help

**Outputs:**
- **stdout:**
  - With `--node-count`: Number of NUMA nodes (default: excludes empty nodes)
  - With `--cpu-list`: CPU list(s), one per line
- **stderr:** Error messages if invalid node specified
- **Exit code:** 0 on success, 101 on error

**Examples:**
```bash
./detect_numa                    # Output: 2 (number of nodes)
./detect_numa --cpu-list         # Output: CPU lists for all nodes
./detect_numa --cpu-list -n 0    # Output: CPUs on node 0
./detect_numa --node-count --include-empty  # Include empty nodes
```

---

### grab_disks

**Purpose:** Identifies available unused disks on the system or uses a specified disk list.

**Inputs:**
- Positional argument: Either "grab_disks" or comma-separated list of disk names
- If "grab_disks": automatically discovers unused disks
- If "none": exits with error on local systems (allowed only for cloud)
- If disk list: uses provided disks (with or without `/dev/` prefix)

**Environment Variables:**
- `TOOLS_BIN` - Path to tools directory
- `to_sys_env` - Set to "local" for local system validation

**Outputs:**
- **stdout:** Format: `<disk1> <disk2> ...:number_of_disks`
  - Example: `/dev/sdb /dev/sdc:2`
- **stderr:** Error messages
- **Exit code:** 0 on success, 101 if no disks found or invalid input
- **Temporary files:** Creates and removes `disks` file

**Examples:**
```bash
./grab_disks grab_disks          # Output: /dev/sdb /dev/sdc:2
./grab_disks sdb,sdc             # Output: /dev/sdb /dev/sdc:2
./grab_disks /dev/sdb,/dev/sdc   # Output: /dev/sdb /dev/sdc:2
```

**Algorithm:**
1. If `hw_config.yml` exists, reads storage devices from it
2. Otherwise:
   - Lists all disks with `lsblk`
   - Identifies root/boot/swap devices
   - Excludes mounted filesystems
   - Returns unused disks in reverse order

---

### create_filesystem

**Purpose:** Creates and mounts a filesystem on a specified device.

**Inputs:**
- `--device <path>` - Device to create filesystem on (required)
- `--fs_type <type>` - Filesystem type: xfs, ext3, ext4, gfs, gfs2 (required)
- `--mount_dir <path>` - Mount point directory (required, created if needed)
- `--usage/-h` - Display help

**Outputs:**
- **stdout:** Command being executed (`mkfs -t ...`)
- **stderr:** Error messages
- **Exit code:** 0 on success, 101 on error
- **Side effects:**
  - Creates filesystem on device
  - Creates mount directory if it doesn't exist
  - Mounts filesystem to specified directory

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

### lvm_create

**Purpose:** Creates an LVM (Logical Volume Manager) volume group and logical volume from specified devices.

**Inputs:**
- `--devices <list>` - Comma-separated list of devices (required)
- `--lvm_grp <name>` - LVM group name (required)
- `--lvm_vol <name>` - LVM volume name (required)
- `--wipefs` - Wipe filesystem signatures before LVM operations
- `--usage/-h` - Display help

**Outputs:**
- **stdout:** Progress messages
- **stderr:** Error messages if operations fail
- **Exit code:** 0 on success, 101 on error
- **Side effects:**
  - Removes existing LV/VG with same names
  - Creates physical volumes (`pvcreate`)
  - Creates volume group (`vgcreate`)
  - Creates logical volume with striping across all devices
  - Total size = (sum of device sizes in GB) - 200GB
  - Wipes the created logical volume

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
- `--lvm_vol <name>` - LVM volume name (required)
- `--lvm_grp <name>` - LVM group name (required)
- `--mount_pnt <path>` - Mount point to unmount
- `--usage/-h` - Display help

**Outputs:**
- **Exit code:** 0 on success, 101 on error
- **Side effects:**
  - Unmounts the mount point
  - Removes logical volume
  - Removes volume group

**Examples:**
```bash
./lvm_delete --lvm_vol vg01 --lvm_grp lv01 --mount_pnt /mnt/test
```

---

### convert_csv_to_txt

**Purpose:** Converts CSV files to formatted plain text with fixed-width columns.

**Inputs:**
- `--results_in <file>` - Input CSV file (required)
- `--results_out <file>` - Output text file (required)
- `--field_size <n>` - Width of each field in characters (required)
- `--field_separator <char>` - CSV field separator (default: ":")
- `--usage/-h` - Display help

**Outputs:**
- **File:** Creates formatted text file at `--results_out` path
- **Exit code:** 0 on success, error code on failure
- **Side effects:** Removes existing output file before writing

**Behavior:**
- Comment lines (starting with #) are preserved as-is
- Lines without the field separator are preserved as-is
- Spaces in values are converted to underscores
- Values are right-aligned in fixed-width columns

**Examples:**
```bash
./convert_csv_to_txt --results_in data.csv --results_out data.txt --field_size 15
./convert_csv_to_txt --results_in data.csv --results_out data.txt --field_size 20 --field_separator ","
```

---

### csv_to_json

**Purpose:** Converts CSV files to JSON format with optional transposition.

**Inputs:**
- `--csv_file <file>` - Input CSV file (default: stdin)
- `--output_file <file>` - Output JSON file (default: stdout)
- `--separator <char>` - CSV separator (default: ",")
- `--transpose` - Transpose CSV (rows↔columns) before conversion
- `--json_skip` - Skip processing (no-op, exits with 0)

**Outputs:**
- **stdout/File:** JSON array of records with 4-space indentation
- **stderr:** Error messages
- **Exit code:**
  - 0 on success
  - 106 (E_INVALID_DATA) on parse error
  - 127 (E_PACKAGE_FAIL) if pandas not installed

**Requirements:** Python 3 with pandas library

**Examples:**
```bash
./csv_to_json --csv_file data.csv --output_file data.json
./csv_to_json --csv_file data.csv --separator ":" --transpose
cat data.csv | ./csv_to_json > data.json
```

---

### invoke_test

**Purpose:** Wrapper for invoking tests with tuned profile tracking.

**Inputs:**
- `--command <string>` - Command to execute (required)
- `--options <strings>` - Options to pass to command
- `--test_name <string>` - Test name for status tracking (required)
- `-h` - Display help

**Outputs:**
- **File:** Creates `/tmp/<test_name>_tuned.status` with tuned profile information
- **Exit code:** 103 on usage error, 101 on general error

**Behavior:**
- On RHEL: Captures active tuned profile
- Checks if tuned service is inactive (writes warning)
- Requires `to_os_running` environment variable

**Examples:**
```bash
./invoke_test --command "fio" --options "--name=test" --test_name mytest
```

---

## Helper Files

### helpers.inc

**Purpose:** Bash library providing common helper functions.

**Functions:**

#### retrieve_time_stamp()
- **Returns:** ISO 8601 UTC timestamp (e.g., "2026-03-16T14:23:45Z")
- **Usage:** For CSV file timestamps

#### build_data_string()
- **Parameters:** Any number of arguments
- **Returns:** Comma-separated string with all commas removed from values
- **Usage:** Building CSV records

**Variables:**
- `test_start_time` - Timestamp when script sourced

**Example:**
```bash
source helpers.inc
timestamp=$(retrieve_time_stamp)
data=$(build_data_string "value1" "value,with,commas" "value3")
# Result: "value1,valuewithcommas,value3"
```

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
- `--debug` - Enable bash -x debugging
- `--home_parent <path>` - Set parent home directory
- `--host_config <name>` - Configuration name
- `--iterations <n>` - Number of test runs
- `--iteration_default <n>` - Default iteration count
- `--no_pkg_install` - Disable all package installation
- `--no_system_packages` - Disable system package installation
- `--no_pip_packages` - Disable pip package installation
- `--run_label <label>` - Run label
- `--run_user <user>` - Test execution user
- `--sys_type <type>` - System type (aws, azure, local, etc.)
- `--sysname <name>` - System name
- `--test_tools_release <tag>` - Use specific test_tools version
- `--tuned_setting <profile>` - Set tuned profile
- `--usage` - Display help
- `--verify_skip` - Skip test verification
- `--json_skip` - Skip JSON conversion
- `--use_pcp` - Enable PCP monitoring

**Side Effects:**
- Sources `~/.bashrc`
- Installs verification dependencies (unless skipped)
- Records active tuned profile to `~/tuned_before`
- May clone specific test_tools release from GitHub
- Sets up USR1 signal trap for command-not-found handling
- Exports environment variables

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

### error_codes

**Purpose:** Defines standardized exit codes for all scripts.

**Usage:**
```bash
source ${TOOLS_BIN}/error_codes
exit $E_SUCCESS  # or other error code
```

See Exit Codes section above for complete list.

---

## Additional Scripts

### umount_filesystems
Unmounts filesystems created by test wrappers.

### save_results
Saves test results to designated location.

### verify_results
Verifies test results against expected values.

### move_data
Moves data between locations.

### gather_data
Gathers system data for analysis.

### generate_intervals
Generates time intervals for testing.

### get_params_file
Retrieves parameter configuration files.

### get_tuned_setting
Gets current tuned profile setting.

### test_header_info
Outputs test header information.

### package_tool
Wrapper for package management operations.

### convert_val
Converts values between different formats.

### detect_mounts
Detects mounted filesystems.

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

1. All scripts use `set -x` debug mode when `--debug` is passed via general_setup
2. Scripts validate input parameters and exit with appropriate error codes
3. Most scripts support `--usage`, `-h`, or `--help` for inline documentation
4. The `general_setup` script provides robust error handling including command-not-found tracking
5. Exit codes follow a consistent pattern: 0=success, 1-99=retry, ≥100=fatal error

---

## License

All scripts are licensed under GPL v2. See individual file headers for copyright information.

Copyright (C) 2022-2026 David Valin, Keith Valin, and contributors.
