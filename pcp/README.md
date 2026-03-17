# PCP Utilities Documentation

## Overview

This directory contains utilities for managing Performance Co-Pilot (PCP) data collection during performance testing workloads. The utilities provide a systemd service-based architecture for collecting system metrics and custom workload metrics via OpenMetrics.

## Components

### 1. pcp_commands.inc

A bash library providing high-level functions for PCP integration with workload tests.

#### Key Functions

##### Setup and Installation

**`setup_pcp()`**
- Installs PCP packages if not already present
- Configures PMDAs (Performance Metrics Domain Agents) for openmetrics and denki
- Handles OS-specific installation (Ubuntu, SLES, etc.)
- Copies service files and configuration to appropriate locations
- Sets up the PCPrecord systemd service

##### Recording Control

**`start_pcp(archive_dir, test_name, config_file)`**
- Resets OpenMetrics values
- Sends Start command to PCPrecord service via FIFO
- Parameters:
  - `$1`: Directory for PCP archive data (should be within workload data directory)
  - `$2`: Test name (used for archive naming)
  - `$3`: PMLogger config file path

**`stop_pcp()`**
- Sends Stop command to PCPrecord service
- Terminates pmlogger recording session

**`shutdown_pcp()`**
- Completely stops the PCPrecord and pmcd services
- Use at end of test runs for cleanup

##### Metric Management

**`result2pcp(metric, value)`** (DEPRECATED)
- Logs a single metric value to OpenMetrics
- Use `results2pcp_multiple()` instead
- Parameters:
  - `$1`: Metric name
  - `$2`: Metric value

**`results2pcp_multiple(metric_list)`**
- Logs multiple metric values atomically
- Format: `"metric1:value1,metric2:value2,metric3:value3"`
- More efficient than multiple `result2pcp()` calls
- Validates metrics exist in the OpenMetrics reset file

**`results2pcp_add_value(metric:value)`**
- Adds metric to a pending list without committing
- Use with `results2pcp_add_value_commit()` for batching

**`results2pcp_add_value_commit()`**
- Commits all pending metrics added via `results2pcp_add_value()`
- Clears the pending metric list after writing

##### Subset Management

**`start_pcp_subset()`**
- Marks the beginning of a subset of interest within a long recording
- Resets OpenMetrics values
- Sets the "running" flag to 1 for visualization filtering

**`stop_pcp_subset()`**
- Marks the end of a subset
- Sets the "running" flag to 0

**`reset_pcp_om()`**
- Resets all OpenMetrics values to their defaults from the reset file

##### Validation

**`openmetrics_file_verification(metric_file)`**
- Validates OpenMetrics file format
- Checks:
  - No special characters in metric names (only alphanumeric and underscore)
  - No blank lines
  - Metrics don't start with digits
  - Exactly 2 fields per line (metric name and value)
  - No duplicate metric names
- Parameters:
  - `$1`: Path to OpenMetrics file to validate

**`check_svc(wait_timeout)`**
- Waits for PCPrecord service to report READY status
- Parameters:
  - `$1`: Timeout in seconds
- Exits with error if timeout expires

#### Global Variables

- `FIFO="/tmp/pcpFIFO"` - Named pipe for communication with PCPrecord service
- `timeout_long=10` - Timeout for Start/Stop operations (seconds)
- `timeout_short=2` - Timeout for other operations (seconds)

#### Usage Example

```bash
# Source the library
source ${TOOLS_BIN}/pcp/pcp_commands.inc

# Setup PCP (one-time per host)
setup_pcp

# Start recording
start_pcp "/path/to/data" "mytest" "${TOOLS_BIN}/pcp/default.cfg"

# Log custom metrics
results2pcp_multiple "throughput:1234.5,latency:45.2,numthreads:8"

# Or batch metrics
results2pcp_add_value "throughput:1234.5"
results2pcp_add_value "latency:45.2"
results2pcp_add_value_commit

# Stop recording
stop_pcp

# Cleanup
shutdown_pcp
```

---

### 2. PCPrecord_actions.sh

A systemd service daemon that processes PCP recording commands via a FIFO pipe.

#### Architecture

- Runs as a systemd Type=notify service
- Infinite loop reading commands from `/tmp/pcpFIFO`
- Uses systemd-notify for status reporting and readiness signaling
- Manages pmlogger lifecycle and OpenMetrics file updates

#### Supported Actions

##### Start
**Format:** `Start <archive_dir> <test_name> <conf_file>`
- Starts pmlogger with specified configuration
- Creates archive in the specified directory
- Only starts if pmlogger is not already running
- Example: `Start /data/results test1 /usr/local/src/PCPrecord/default.cfg`

##### Stop
**Format:** `Stop`
- Stops the currently running pmlogger instance
- Only stops if pmlogger is running

##### Reset
**Format:** `Reset`
- Resets all OpenMetrics values to defaults from reset file
- Can be called at any time (doesn't require pmlogger running)

##### Workload Metrics
**Format:** `<metric_name> <value>`
- Supported metrics: `throughput`, `latency`, `numthreads`, `runtime`
- Updates the specified metric in the OpenMetrics workload file
- Only processes if pmlogger is running
- Example: `throughput 1234.5`

##### Workload States
**Format:** `<state_name> <value>`
- Supported states: `running`, `iteration`
- Updates state values in OpenMetrics file
- Only processes if pmlogger is running
- Example: `running 1`

#### Service Status Reporting

The service uses systemd-notify to report:
- **READY:** Waiting for next command (includes timing of last action)
- **Processing:** Currently handling a command
- **ERROR:** Error occurred during command processing

Check status with:
```bash
systemctl status PCPrecord.service
```

#### Global Variables

- `FIFO="/tmp/pcpFIFO"` - Named pipe for receiving commands
- `sample_rate=5` - Default pmlogger sample rate in seconds
- `pmlogger_running="false"` - State tracking
- `om_workload_file="/tmp/openmetrics_workload.txt"` - Active metrics file
- `om_workload_file_reset="/tmp/openmetrics_workload_reset.txt"` - Default values

#### Dependencies

- `pcp_functions.inc` - PCP utility functions
- `error_codes` - Error code definitions
- pmlogger (from PCP package)
- OpenMetrics PMDA

#### Service Management

```bash
# Start service
systemctl start PCPrecord.service

# Check status
systemctl status PCPrecord.service

# Stop service
systemctl stop PCPrecord.service

# View logs
journalctl -u PCPrecord.service -f
```

#### Debugging

The service includes debug timing measurements:
- Tracks processing time for each action in milliseconds
- Reports timing in status message: `READY: last-action - <action> = <time>ms`
- View with: `systemctl status PCPrecord.service`

---

## Workflow Integration

### Typical Test Workflow

1. **Pre-test Setup** (once per host)
   ```bash
   source ${TOOLS_BIN}/pcp/pcp_commands.inc
   setup_pcp
   ```

2. **Start Recording**
   ```bash
   start_pcp "${run_dir}/pcp_data" "${test_name}" "${TOOLS_BIN}/pcp/default.cfg"
   ```

3. **During Test** - Log metrics periodically
   ```bash
   results2pcp_multiple "throughput:${tput},latency:${lat},numthreads:${threads}"
   ```

4. **Stop Recording**
   ```bash
   stop_pcp
   ```

5. **Post-test Cleanup**
   ```bash
   shutdown_pcp
   ```

### Subset Recording (for long-running tests)

When recording a single archive for an entire test run but only interested in specific portions:

```bash
# Start archive at beginning of test
start_pcp "${run_dir}/pcp_data" "${test_name}" "${TOOLS_BIN}/pcp/default.cfg"

# ... test warmup phase ...

# Mark beginning of measurement phase
start_pcp_subset

# ... run actual test ...

# Mark end of measurement phase
stop_pcp_subset

# ... test cooldown phase ...

# Stop archive at end of test
stop_pcp
```

---

## OpenMetrics File Format

The OpenMetrics workload file (`/tmp/openmetrics_workload.txt`) contains custom metrics in this format:

```
metric_name value
another_metric value
```

Requirements:
- Metric names: alphanumeric and underscore only, cannot start with digit
- Exactly 2 whitespace-separated fields per line
- No blank lines
- No duplicate metric names

Example:
```
throughput 0
latency 0
numthreads 0
runtime 0
running 0
iteration 0
```

The reset file (`/tmp/openmetrics_workload_reset.txt`) defines default values that metrics return to on reset.

---

## Error Handling

Both utilities use consistent error handling:

- **Exit codes**: Defined in `error_codes` file
  - `E_SUCCESS`: Successful operation
  - `E_PCP_FAILURE`: PCP-related failure

- **Error functions**:
  - `fail_exit(message)` in pcp_commands.inc
  - `error_exit(message)` in PCPrecord_actions.sh

- **Validation**: All critical operations check return codes and exit with errors

---

## Configuration Files

### PCPrecord.service
Location: `/etc/systemd/system/PCPrecord.service`

Systemd service unit file for the PCPrecord daemon.

### workload.url
Location: `/var/lib/pcp/pmdas/openmetrics/config.d/workload.url`

OpenMetrics PMDA configuration for scraping the workload metrics file.

### default.cfg
Default pmlogger configuration file specifying which PCP metrics to collect.

### openmetrics_default_reset.txt
Default OpenMetrics values file. Can be overridden per-test with:
`${run_dir}/openmetrics_${test_name}_reset.txt`

---

## Dependencies

### Required Packages
- PCP (Performance Co-Pilot) core packages
- pmlogger
- pmcd (PCP Collector Daemon)
- pcp-pmda-openmetrics
- pcp-pmda-denki (optional, for power metrics)

### Required Tools
- systemd
- bash (version 4+)
- standard Unix utilities: sed, awk, grep, cut, sort, wc

---

## Troubleshooting

### Service won't start
```bash
# Check service status
systemctl status PCPrecord.service

# Check journal for errors
journalctl -u PCPrecord.service -n 50

# Verify FIFO exists
ls -l /tmp/pcpFIFO

# Verify OpenMetrics files exist
ls -l /tmp/openmetrics_workload*.txt
```

### Timeouts waiting for service
- Increase `timeout_long` or `timeout_short` in pcp_commands.inc
- Check system load (high CPU usage affects timing)
- Verify PCPrecord service is running

### Invalid metric errors
- Check OpenMetrics file format with `openmetrics_file_verification()`
- Verify no duplicate metric names
- Ensure metric names use only alphanumeric and underscore
- Check for blank lines or extra fields

### pmlogger not recording
- Verify pmcd is running: `systemctl status pmcd`
- Check pmlogger config file is valid
- Ensure archive directory exists and is writable
- Review pmlogger logs: `journalctl -u pmlogger`

---

## Performance Considerations

### CPU Usage
- The `check_svc()` function polls systemd status and can be CPU-intensive
- Timing is sensitive to system load
- Consider longer timeouts on heavily loaded systems

### Metric Update Frequency
- Each metric update incurs file I/O and processing time
- Batch metrics with `results2pcp_multiple()` for efficiency
- Typical update interval: 1-10 seconds depending on workload

### Archive Size
- Archive size depends on sample rate and number of metrics
- Default sample rate: 5 seconds
- Consider disk space for long-running tests
- Use subset recording for targeted data collection

---

## License

Copyright (C) 2025 Matt Lucius, John Harrigan

Licensed under GPL v2 or later. See LICENSE file for details.
