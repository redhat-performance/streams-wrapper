# STREAM Memory Bandwidth Benchmark Wrapper

## Description

This wrapper facilitates the automated execution of the STREAM memory bandwidth benchmark. STREAM is a standard metric for assessing a system's sustainable memory bandwidth, measuring throughput in MB/s across four vector operations (Copy, Scale, Add, Triad).

The wrapper provides:
- Automated STREAM compilation and execution with OpenMP support.
- Automatic array sizing based on system cache topology.
- Scaling tests across NUMA nodes and CPU sockets.
- Support for multiple GCC optimization levels (O2 and O3).
- Support for x86_64 (AMD/Intel) and aarch64 (ARM) architectures.
- Result collection, processing, and verification.
- CSV and JSON output formats.
- System configuration metadata capture.
- Integration with test_tools framework.
- Optional Performance Co-Pilot (PCP) integration.

## Command-Line Options

```
Streams Options:
  --cache_multiply <value>: Multiply cache sizes by <value>. Default is 2.
  --cache_start_factor <value>: Start the cache size at base cache * <value>. Default is 1.
  --cache_cap_size <value>: Caps the size of cache to this value. Default is no cap (0).
  --nsizes <value>: Maximum number of cache sizes to test. Default is 4.
  --opt2 <value>: If value is not 0, run with O2 optimization level. Default is 1.
  --opt3 <value>: If value is not 0, run with O3 optimization level. Default is 1.
  --result_dir <string>: Directory to place results into. Default is
      results_streams_tuned_<tuned_setting>_<date>.
  --size_list <x,y...>: Explicit comma-separated list of array sizes in bytes.
      Overrides automatic cache-based sizing.
  --threads_multiple <value>: Multiply number of threads by <value>. Default is 2.
  --tools_git <value>: Git repo to retrieve the required tools from.
      Default: https://github.com/redhat-performance/test_tools-wrappers

General test_tools options:
  --home_parent <value>: Parent home directory. If not set, defaults to current working directory.
  --host_config <value>: Host configuration name, defaults to current hostname.
  --iterations <value>: Number of times to run the test, defaults to 5.
  --run_user: User that is actually running the test on the test system. Defaults to current user.
  --sys_type: Type of system working with (aws, azure, hostname). Defaults to hostname.
  --sysname: Name of the system running, used in determining config files. Defaults to hostname.
  --tuned_setting: Used in naming the results directory. For RHEL, defaults to current active tuned profile.
      For non-RHEL systems, defaults to 'none'.
  --use_pcp: Enable Performance Co-Pilot monitoring during test execution.
  --tools_git <value>: Git repo to retrieve the required tools from.
      Default: https://github.com/redhat-performance/test_tools-wrappers
  --usage: Display this usage message.
```

## What the Script Does

The `streams_run` script performs the following workflow:

1. **Environment Setup**:
   - Clones the test_tools-wrappers repository if not present (default: ~/test_tools).
   - Sources error codes and general setup utilities.
   - Detects NUMA topology and cache hierarchy.

2. **Package Installation**:
   - Installs required dependencies via package_tool (gcc, bc, numactl, etc.).
   - Dependencies are defined in streams.json for different OS variants (RHEL, Ubuntu, SLES, Amazon Linux).

3. **Cache Detection and Array Sizing**:
   - Reads L3 cache size from `/sys/devices/system/cpu/cpu0/cache/index*/size`.
   - For ARM Neoverse systems without exposed L3 cache, uses hardcoded 32 MB SLC per NUMA node.
   - Calculates progressively larger array sizes based on cache size and `cache_multiply`.
   - Validates each size against available free memory (skips sizes requiring >90%).

4. **STREAM Compilation**:
   - Compiles STREAM 5.10 source (stream_omp_5_10.c) with OpenMP support.
   - Generates separate binaries for each array size.
   - Supports both O2 and O3 optimization levels.
   - Uses architecture-specific compiler flags (`-m64` for x86_64, `-mno-outline-atomics` for aarch64).

5. **Test Execution**:
   - Scales across socket configurations (1 socket through all sockets).
   - Sets `OMP_NUM_THREADS` based on CPUs per NUMA node and socket count.
   - Pins threads to specific CPUs via `GOMP_CPU_AFFINITY`.
   - Runs each (socket count, array size) combination for the specified number of iterations.
   - Captures system information (lscpu) alongside each run.

6. **Data Collection**:
   - Captures system configuration (CPU model, memory, NUMA topology, kernel version).
   - Records STREAM configuration parameters (array sizes, optimization level).
   - Logs timestamps for each test run.
   - Optionally records PCP performance data.

7. **Result Processing**:
   - Extracts performance metrics (Copy, Scale, Add, Triad rates in MB/s) from STREAM output.
   - Averages results across iterations for each configuration.
   - Sorts results by array size and socket count.
   - Generates CSV files with configuration and performance data.
   - Creates JSON output for verification.
   - Validates results against Pydantic schema.

8. **Verification**:
   - Validates results against Pydantic schema (results_schema.py).
   - Ensures all required fields are present and valid (all rates > 0).
   - Uses csv_to_json and verify_results from test_tools.

9. **Output**:
   - Creates timestamped results directory in `results_streams_<tuned_setting>_<YYYYMMDDHHMMSS>`.
   - Saves all raw output files, processed CSV/JSON, and system metadata.
   - Optionally saves PCP performance data.
   - Archives results to configured storage location.

## Dependencies

Location of underlying workload: included in the git repository (stream_omp_5_10.c, STREAM version 5.10).

**Required packages by platform**:
- **RHEL**: gcc, bc, perf, zip, unzip, numactl.
- **Ubuntu**: bc, zip, unzip, numactl, libnuma-dev.
- **SLES**: gcc, make, bc, perf, git, unzip, zip, libnuma1, numactl.
- **Amazon Linux**: gcc, bc, git, zip, unzip, numactl.

To run:
```bash
git clone https://github.com/redhat-performance/streams-wrapper
cd streams-wrapper/streams
./streams_run
```

The script will automatically detect your cache topology and set buffer sizes based on the hardware it is being executed on.

## The STREAM Benchmark

STREAM is a benchmark that measures sustainable memory bandwidth by performing simple vector operations on large arrays of double-precision floating-point numbers.

### STREAM Kernels

STREAM measures four operations:

| Kernel | Operation | Bytes per Element |
|--------|-----------|-------------------|
| **Copy** | `c[i] = a[i]` | 24 (2 reads + 1 write) |
| **Scale** | `b[i] = scalar * c[i]` | 24 (2 reads + 1 write) |
| **Add** | `c[i] = a[i] + b[i]` | 32 (3 reads + 1 write) |
| **Triad** | `a[i] = b[i] + scalar * c[i]` | 32 (3 reads + 1 write) |

### Key Parameters

1. **STREAM_ARRAY_SIZE**: The number of double-precision elements in each array. Larger arrays ensure the working set exceeds cache, forcing memory accesses. The wrapper automatically sizes arrays based on the system's cache hierarchy.

2. **Optimization Level**: GCC optimization flags (-O2 or -O3). Both levels are run by default to compare compiler optimization effects on memory bandwidth.

3. **OMP_NUM_THREADS**: Number of OpenMP threads used. The wrapper scales from a single NUMA node's worth of CPUs up to all CPUs across all sockets.

4. **Performance Metric**: STREAM reports bandwidth in **MB/s** (megabytes per second). Higher values indicate better memory bandwidth. The benchmark runs each kernel 10 times internally and reports the best rate (excluding the first iteration).

## Output Files

The results directory contains:

- **results_streams_opt_\<N\>.csv**: CSV file with STREAM configuration and performance metrics per optimization level.
- **stream.\<size\>k.out.threads_\<T\>.numb_sockets_\<S\>_iter_\<I\>**: Raw output files from individual STREAM runs including lscpu data, CPU affinity, and performance metrics.
- **results_streams.wrkr**: Aggregated worker results in `buffer_size:#threads:#sockets:Copy:Scale:Add:Triad` format.
- **streams_build_options**: Log of all gcc compilation commands executed.
- **meta_data\*.yml**: System metadata (CPU info, memory, NUMA topology, kernel version).
- **PCP data** (if --use_pcp option used): Performance Co-Pilot monitoring data.

## Examples

### Basic run with defaults
```bash
./streams_run
```
This runs with:
- Both O2 and O3 optimization levels.
- Automatic cache-based array sizing (4 sizes, starting at L3 cache size, doubling each step).
- 5 iterations per configuration.
- Automatic scaling across all socket configurations.

### Run with custom cache multiplier
```bash
./streams_run --cache_multiply 4
```
Uses a 4x multiplier between successive array sizes instead of the default 2x.

### Run with specific array sizes
```bash
./streams_run --size_list 1048576,4194304,16777216
```
Tests with explicit array sizes (in bytes) instead of automatic cache-based sizing.

### Run with more cache sizes
```bash
./streams_run --nsizes 8
```
Tests up to 8 progressively larger array sizes instead of the default 4.

### Run only O3 optimization
```bash
./streams_run --opt2 0
```
Disables O2 optimization, running only with O3.

### Run multiple iterations
```bash
./streams_run --iterations 10
```
Runs each configuration 10 times instead of the default 5.

### Run with capped cache size
```bash
./streams_run --cache_cap_size 65536
```
Caps array sizes at 65536 KB, useful for limiting test duration.

### Run with PCP monitoring
```bash
./streams_run --use_pcp
```
Collects Performance Co-Pilot data during the run.

### Combination example
```bash
./streams_run --cache_multiply 4 --nsizes 6 --iterations 10 --use_pcp
```
Uses 4x cache multiplier, tests 6 sizes, runs 10 iterations, and collects PCP data.

## How Array Sizing Works

The script automatically calculates STREAM array sizes based on system cache topology:

### Cache Detection
1. Reads the highest-level cache size from `/sys/devices/system/cpu/cpu0/cache/index*/size`.
2. For ARM Neoverse systems where L3 cache is not exposed in sysfs, uses a hardcoded 32 MB System-Level Cache (SLC) per NUMA node.
3. Multiplies the base cache size by `cache_start_factor` (default: 1).

### Array Size Progression
1. Starts at the base cache size (in KB).
2. Each subsequent size is multiplied by `cache_multiply` (default: 2).
3. Generates up to `nsizes` (default: 4) different sizes.
4. Sizes exceeding `cache_cap_size` are skipped (if set).
5. Sizes requiring more than 90% of free memory are skipped.

For example, with a 32 MB L3 cache and default settings:
- Size 1: 32 MB (1x cache)
- Size 2: 64 MB (2x cache)
- Size 3: 128 MB (4x cache)
- Size 4: 256 MB (8x cache)

### Thread and Socket Scaling
1. Detects the number of NUMA nodes.
2. Calculates CPUs per NUMA node: `total_cpus / numa_nodes`.
3. Scales from 1 socket to all sockets:
   - 1 socket: `OMP_NUM_THREADS = cpus_per_node`
   - 2 sockets: `OMP_NUM_THREADS = cpus_per_node * 2`
   - N sockets: `OMP_NUM_THREADS = cpus_per_node * N`
4. Sets `GOMP_CPU_AFFINITY` to pin threads to the CPUs in the active NUMA nodes.

## Return Codes

The script uses standardized error codes from test_tools error_codes:
- **0**: Success.
- **101**: Git clone failure.
- **E_GENERAL**: General execution errors (compilation failures, memory sizing issues, execution failures, validation failures).
- **E_USAGE**: Invalid usage/arguments.

Exit codes indicate specific failure points for automated testing workflows.

## Notes

### Architecture Support
- **x86_64**: Full support for AMD and Intel CPUs. Uses `-m64` compiler flag.
- **aarch64**: Full support for ARM CPUs. Uses `-mno-outline-atomics` compiler flag. Special cache handling for Neoverse systems with unexposed L3 cache.

### Memory Considerations
- STREAM uses three arrays of double-precision elements (8 bytes each), so total memory per array size is `STREAM_ARRAY_SIZE * 24` bytes.
- The wrapper skips array sizes that would require more than 90% of free memory.
- For systems with very large caches, use `--cache_cap_size` to limit the largest array size tested.

### Special Cases
- **ARM Neoverse**: L3/SLC cache is not exposed in sysfs. The wrapper uses a hardcoded 32 MB per NUMA node as the base cache size.
- **Thread pinning**: Threads are pinned to specific CPUs via `GOMP_CPU_AFFINITY` based on NUMA node membership, ensuring accurate per-socket bandwidth measurements.

### Performance Tips
- Run multiple iterations (default is 5) to verify consistency.
- Ensure the system is idle (no other workloads) for best results.
- Disable CPU frequency scaling (use performance governor) for reproducible results.
- Consider the active tuned profile on RHEL systems.
- Compare O2 and O3 results to understand compiler optimization effects on memory bandwidth.
- For production benchmarking, allow the system to warm up with a test run first.

### Troubleshooting
- If STREAM fails to compile, verify that gcc is installed and supports OpenMP (`-fopenmp`).
- If array sizes are being skipped, check available free memory with `free -k`.
- If performance is unexpectedly low, check CPU frequency, system load, and NUMA binding.
- Use `--use_pcp` to collect detailed performance counters for analysis.
- Check the `streams_build_options` file to verify compilation flags are correct.
