# STREAM Memory Bandwidth Benchmark Wrapper

## Description

This wrapper automates running the STREAM memory bandwidth benchmark written by John D. McCalpin and Joe R. Zagar. The STREAM benchmark measures sustained memory bandwidth (in MB/s) for simple vector kernels.

The wrapper provides:
- Automated execution across multiple cache sizes and thread counts
- Support for different compiler optimization levels (O2, O3)
- Result collection, processing, and verification
- CSV and JSON output formats
- System configuration metadata capture
- Integration with test_tools framework
- Optional Performance Co-Pilot (PCP) integration

## What the Script Does

The `streams_run` script performs the following workflow:

1. **Environment Setup**:
   - Clones the test_tools-wrappers repository if not present (default: ~/test_tools)
   - Sources error codes and general setup utilities

2. **Package Installation**:
   - Installs required dependencies via package_tool (gcc, bc, numactl, etc.)
   - Dependencies are defined in streams.json for different OS variants (RHEL, Ubuntu, SLES, Amazon Linux)

3. **Test Execution**:
   - Runs STREAM benchmark with configurable parameters:
     - Multiple array sizes (based on cache size multipliers)
     - Multiple thread counts (based on thread multipliers)
     - Different optimization levels (O2 and/or O3)
   - Executes via the run_stream helper script

4. **Data Collection**:
   - Captures system configuration (CPU count, cores per socket, NUMA nodes, kernel version, memory)
   - Records STREAM version information
   - Logs timestamps for each test run

5. **Result Processing**:
   - Aggregates results from multiple runs and iterations
   - Averages results across iterations
   - Sorts data by socket count and array size
   - Generates CSV files with Copy, Scale, Add, and Triad bandwidth rates
   - Creates transposed JSON output for verification

6. **Verification**:
   - Validates results against Pydantic schema (results_schema.py)
   - Ensures all bandwidth values are greater than 0
   - Uses csv_to_json and verify_results from test_tools

7. **Output**:
   - Creates timestamped results directory: `results_streams_<tuned_setting>_<YYYYMMDDHHMMSS>`
   - Saves all raw output files, processed CSV/JSON, and system metadata
   - Optionally saves PCP performance data
   - Archives results to configured storage location

## Dependencies

Location of underlying workload: part of the github kit

Packages required: gcc,bc,numactl

To run:
```
[root@hawkeye ~]# git clone https://github.com/redhat-performance/streams-wrapper
[root@hawkeye ~]# streams-wrapper/streams/streams_run
```

The script will set the buffer sizes based on the hardware it is being executed on.

## The STREAM Benchmark Kernels

STREAM measures memory bandwidth using four simple vector operations:

1. **Copy**: `a[i] = b[i]` - Measures read and write bandwidth
2. **Scale**: `a[i] = q * b[i]` - Measures read, multiply, and write bandwidth
3. **Add**: `a[i] = b[i] + c[i]` - Measures bandwidth with multiple reads
4. **Triad**: `a[i] = b[i] + q * c[i]` - The most common operation in scientific codes

Each operation is measured in MB/s. Higher values indicate better memory subsystem performance.

## Results Schema

The wrapper validates results using a Pydantic schema that requires:
- **Array_sizes**: String describing the array sizes tested
- **Copy**: Integer bandwidth > 0 (MB/s)
- **Scale**: Integer bandwidth > 0 (MB/s)
- **Add**: Integer bandwidth > 0 (MB/s)
- **Triad**: Integer bandwidth > 0 (MB/s)

## Output Files

The results directory contains:

- **results_streams_opt_O2.csv** / **results_streams_opt_O3.csv**: CSV files with bandwidth measurements organized by socket count and array size
- **stream_\*.out**: Raw output files from individual STREAM runs
- **streams_build_options**: Compiler options used for the build
- **System metadata**: CPU info, memory, NUMA topology, kernel version
- **PCP data** (if --pcp option used): Performance Co-Pilot monitoring data

## Command-Line Options

```
Options
--cache_multiply <value>: Multiply cache sizes by <value>. Default is 2
--cache_start_factor <value>: Start the cache size at base cache * <value>
    Default is 1
--cache_cap_size <value>: Caps the size of cache to this value.  Default is no cap.
--nsizes <value>:  Maximum number of cache sizes to do. Default is 4
--opt2 <value>:  If value is not 0, then we will run with optimization level
    2.  Default value is 1
--opt3 <value>:  If value is not 0, then we will run with optimization level
    3.  Default value is 1
--results_dir <string>:  Directory to place results into.  Default is
    results_streams_tuned_<tuned using>_<date>
--size_list <x,y...>:  List of array sizes in byte
--threads_multiple <value>: Multiply number threads by <value>. Default is 2
--tools_git <value>: git repo to retrieve the required tools from, default is https://github.com/redhat-performance/test_tools-wrappers

General options
  --home_parent <value>: Our parent home directory.  If not set, defaults to current working directory.
  --host_config <value>: default is the current host name.
  --iterations <value>: Number of times to run the test, defaults to 1.
  --run_user: user that is actually running the test on the test system. Defaults to user running wrapper.
  --sys_type: Type of system working with, aws, azure, hostname.  Defaults to hostname.
  --sysname: name of the system running, used in determining config files.  Defaults to hostname.
  --tuned_setting: used in naming the tar file, default for RHEL is the current active tuned.  For non
    RHEL systems, default is none.
  --usage: this usage message.
```

## Examples

### Basic run with defaults
```bash
./streams_run
```
This runs with:
- Default 5 iterations
- Both O2 and O3 optimization levels
- 4 cache sizes (base cache × 1, 2, 4, 8)
- Thread counts multiplied by 2 at each step

### Run with specific cache sizes
```bash
./streams_run --size_list 1000000,5000000,10000000
```
Tests specific array sizes (in bytes) instead of auto-calculated cache-based sizes.

### Run only O3 optimization, skip O2
```bash
./streams_run --opt2 0 --opt3 1
```

### Run with more cache sizes and higher thread multiplier
```bash
./streams_run --nsizes 6 --threads_multiple 4
```
Tests 6 different cache sizes with threads multiplied by 4 at each step.

### Run with PCP monitoring
```bash
./streams_run --pcp
```
Collects Performance Co-Pilot data during the run.

### Cap maximum cache size
```bash
./streams_run --cache_cap_size 50000000
```
Limits testing to arrays no larger than 50MB (useful for systems with large caches).

## How Cache Sizing Works

The script automatically calculates array sizes based on system cache hierarchy:

1. Detects base cache size from system
2. Starting size = base cache × `--cache_start_factor` (default 1)
3. Each subsequent size = previous size × `--cache_multiply` (default 2)
4. Continues for `--nsizes` iterations (default 4)
5. Stops if size exceeds `--cache_cap_size` (if set)

Example: With L3 cache of 20MB, defaults produce array sizes of 20MB, 40MB, 80MB, 160MB.

## How Thread Scaling Works

The script tests multiple thread configurations:

1. Detects number of hardware threads
2. Tests with increasing thread counts based on `--threads_multiple`
3. Also tests configurations with different socket counts

This explores the memory bandwidth scaling characteristics across different levels of parallelism.

## Integration with test_tools

The wrapper integrates with the test_tools-wrappers framework:

- **csv_to_json**: Converts results to JSON format
- **gather_data**: Collects system information
- **general_setup**: Parses common options, handles tuned profile detection
- **invoke_test**: Handles test orchestration and logging
- **move_data**: Organizes output files
- **package_tool**: Installs required packages
- **save_results**: Archives results to configured storage
- **test_header_info**: Generates CSV headers with system metadata
- **verify_results**: Validates against Pydantic schema

## Return Codes

The script uses standardized error codes from test_tools error_codes:
- **0**: Success
- **101**: Git clone failure
- **E_GENERAL**: General execution errors (validation failures, test execution failures)

Exit codes indicate specific failure points for automated testing workflows.

## Notes

- The STREAM benchmark does not explicitly handle NUMA (Non-Uniform Memory Access) architectures
- Results vary based on system load, so multiple iterations are recommended
- Higher optimization levels (O3) generally produce better bandwidth numbers
- Array sizes should be much larger than L3 cache to measure main memory bandwidth accurately
