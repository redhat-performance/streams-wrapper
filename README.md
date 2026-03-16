# STREAM Wrapper Quick Start Guide

## Installation

```bash
git clone https://github.com/redhat-performance/streams-wrapper
cd streams-wrapper/streams
```

## Basic Usage

### Run with defaults (recommended for first time)
```bash
./streams_run
```
This will:
- Run 5 iterations
- Test with both O2 and O3 compiler optimizations
- Auto-detect cache sizes and test 4 different array sizes
- Scale thread counts by 2x at each step
- Save results to `results_streams_<tuned>_<timestamp>/`

### Check results
Results are saved in timestamped directories. Example:
```bash
cd results_streams_throughput-performance_20260316103045/streams_results/
ls -l
```

You'll find:
- `results_streams_opt_O2.csv` - Results with -O2 optimization
- `results_streams_opt_O3.csv` - Results with -O3 optimization
- Raw output files: `stream_*.out`
- System configuration metadata

## Common Use Cases

### 1. Quick Performance Check
```bash
./streams_run --iterations 3 --nsizes 2
```
Runs faster with fewer iterations and array sizes.

### 2. Thorough Benchmark
```bash
./streams_run --iterations 10 --nsizes 6 --threads_multiple 4
```
More comprehensive testing with more data points.

### 3. Test Specific Array Sizes
```bash
./streams_run --size_list 10000000,50000000,100000000
```
Tests exactly the sizes you specify (in bytes).

### 4. Only Test One Optimization Level
```bash
./streams_run --opt2 0 --opt3 1  # O3 only
./streams_run --opt2 1 --opt3 0  # O2 only
```

### 5. Cap Array Size (for systems with large caches)
```bash
./streams_run --cache_cap_size 100000000
```
Limits testing to arrays ≤ 100MB.

## Reading the Results

### CSV Output Format
```
System_Name,Hostname
Kernel,5.14.0-284.el9.x86_64
...
# 1 Socket
Array_sizes,20000000,40000000,80000000,160000000,Start_Date,End_Date
Copy,45123,44892,43234,42156,2026-03-16T10:00:00,2026-03-16T10:15:00
Scale,43892,43654,42123,41032,...
Add,48234,47892,46234,45123,...
Triad,47123,46892,45234,44123,...
```

### Understanding the Numbers
- **Copy**: Simple `a[i] = b[i]` - Basic read/write bandwidth
- **Scale**: `a[i] = q * b[i]` - Read, multiply, write
- **Add**: `a[i] = b[i] + c[i]` - Two reads, one write
- **Triad**: `a[i] = b[i] + q * c[i]` - **Most important metric**

All values in MB/s. Higher is better.

### What's Good Performance?
- **DDR4-2933**: ~20-25 GB/s per socket (Triad)
- **DDR4-3200**: ~25-30 GB/s per socket (Triad)
- **DDR5-4800**: ~35-45 GB/s per socket (Triad)

Performance varies by CPU architecture, memory channels, and population.

## Troubleshooting

### Problem: Package installation fails
**Solution**:
```bash
./streams_run --no_packages  # Skip package installation
# Manually install: gcc bc numactl
```

### Problem: Results show 0 bandwidth
**Causes**:
- Array size too small (increase --cache_start_factor)
- Compilation failed (check for gcc)
- System under heavy load

### Problem: Verification failed
Check the results_streams.json file that was created during processing. Common issues:
- One of the bandwidth values is 0 or negative
- Results format doesn't match schema

## Performance Tips

1. **Run on idle system**: Close other applications for accurate results
2. **Disable turbo boost**: For consistent, repeatable results
   ```bash
   echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo  # Intel
   ```
3. **Use same tuned profile**: When comparing results
4. **Multiple iterations**: Use `--iterations 5` or higher for statistical confidence
5. **Check NUMA policy**: May affect multi-socket results

## Understanding Array Sizes

### How Sizes Are Chosen
By default, the script:
1. Detects L3 cache size (e.g., 20 MB)
2. Tests 4 sizes: 1x, 2x, 4x, 8x the cache (20MB, 40MB, 80MB, 160MB)

### Why Multiple Sizes?
- **Smaller than cache**: Tests cache bandwidth (very high)
- **Similar to cache**: Tests cache-to-memory transition
- **Larger than cache**: Tests main memory bandwidth (most relevant)

### Choosing Custom Sizes
```bash
# Test transition from L3 to memory
./streams_run --size_list $((20*1024*1024)),$((50*1024*1024)),$((100*1024*1024))
```

## Advanced Options

### PCP Performance Monitoring
```bash
./streams_run --pcp
```
Requires Performance Co-Pilot installed. Captures system metrics during run.

### Custom Results Directory
```bash
./streams_run --results_dir my_benchmark_$(date +%Y%m%d)
```

### Change Test Tools Source
```bash
./streams_run --tools_git https://my-internal-git.com/test_tools.git
```

### System Type Tagging
```bash
./streams_run --sys_type aws --sysname c5.metal
```
Useful for tracking results from different platforms.

## Example Workflows

### Weekly Performance Tracking
```bash
#!/bin/bash
# run_weekly_stream.sh
DATE=$(date +%Y%m%d)
./streams_run \
  --iterations 10 \
  --results_dir /data/benchmarks/stream_${DATE} \
  --host_config production_server_1
```

### Before/After Tuning Comparison
```bash
# Baseline
./streams_run --tuned_setting baseline --results_dir baseline_results

# Apply tuning changes...
tuned-adm profile throughput-performance

# Compare
./streams_run --tuned_setting optimized --results_dir optimized_results
```

### Multi-System Comparison
```bash
# Run on each system
for host in server1 server2 server3; do
  ssh $host "cd streams-wrapper/streams && \
    ./streams_run --host_config $host --results_dir /shared/results_$host"
done

# Compare results
diff /shared/results_*/streams_results/results_streams_opt_O3.csv
```

## Getting Help

### View all options
```bash
./streams_run --usage
```

### Check script version
```bash
grep streams_wrapper_version ./streams_run
```

### Report issues
https://github.com/redhat-performance/streams-wrapper/issues

## Key Files Reference

| File | Purpose |
|------|---------|
| `streams_run` | Main wrapper script |
| `stream_omp_5_10.c` | STREAM benchmark source code |
| `streams.json` | Package dependencies by OS |
| `results_schema.py` | Pydantic validation schema |
| `streams_extra/run_stream` | Helper script that compiles and runs STREAM |
| `README.md` | Full documentation |
| `DEVELOPMENT.md` | Internal architecture docs |

## Next Steps

1. Run a basic test: `./streams_run`
2. Review results in the generated CSV files
3. Experiment with different array sizes and thread counts
4. Compare O2 vs O3 optimization results
5. Integrate into your performance testing workflow
