Automation wrapper for streams

Description:
           This wrapper runs the streams program written by
		John D. McCalpin
		Joe R. Zagar
	    The program being executed, measures memory transfer
            rates in MB/s and provides a rough idea of memory rates
            of the machine. However it is a bit outdated
	    and does not deal with numa.
  
Location of underlying workload: part of the github kit

Packages required: gcc,bc

To run:
```
[root@hawkeye ~]# git clone https://github.com/redhat-performance/streams-wrapper
[root@hawkeye ~]# streams-wrapper/streams/streams_run
```

The script will set the buffer sizes based on the hardware it is being executed on.

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
--result_dir <string>:  Directory to place results into.  Default is
    results_streams_tuned_<tuned using>_<date>
--size_list <x,y...>:  List of array sizes in byte
--threads_multiple <value>: Multiply number threads by <value>. Default is 2
--tools_git <value>: git repo to retrieve the required tools from, default is https://github.com/redhat-performance/test_tools-wrappers

General options
  --home_parent <value>: Our parent home directory.  If not set, defaults to current working directory.
  --host_config <value>: default is the current host name.
  --iterations <value>: Number of times to run the test, defaults to 1.
  --pbench: use pbench-user-benchmark and place information into pbench, defaults to do not use.
  --pbench_user <value>: user who started everything. Defaults to the current user.
  --pbench_copy: Copy the pbench data, not move it.
  --pbench_stats: What stats to gather. Defaults to all stats.
  --run_label: the label to associate with the pbench run. No default setting.
  --run_user: user that is actually running the test on the test system. Defaults to user running wrapper.
  --sys_type: Type of system working with, aws, azure, hostname.  Defaults to hostname.
  --sysname: name of the system running, used in determining config files.  Defaults to hostname.
  --tuned_setting: used in naming the tar file, default for RHEL is the current active tuned.  For non
    RHEL systems, default is none.
  --usage: this usage message.
```

Note: The script does not install pbench for you.  You need to do that manually.
