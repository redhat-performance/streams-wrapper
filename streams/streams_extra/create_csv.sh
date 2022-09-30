#!/bin/bash

#
# Copyright (C) 2022  David Valin dvalin@redhat.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#

#
# Create the summary csv file.
#

out_line=""

#
# Retrieve the relevent lines from the file.
# We return the average of all the lines.
#
retrieve_line()
{
	search_for=$1
	file=$2
	items=0
	calc_line=""

	info=`grep "${search_for}" ${file}* | tr -s " " | sed "s/ /:/g" | cut -d: -f  4`

	for i in $info; do
		if [ $items -eq 0 ]; then
			calc_line="("${calc_line}${i}
		else
			calc_line=${calc_line}"+"${i}
		fi
			let items="${items}+1"
	done
	calc_line=$calc_line")/"$items
	out_line=$out_line":"`echo $calc_line | bc`
}

#
# First get the data
#
#
# line format
# buffer size:#threads:#sockets:Copy rate:Scale rate:Add rate:Triad rate
#
retrieve_results()
{
	last_file=""
	#
	# Get all the files to work on.
	#
	ls stream* | sort > files
	for i in `cat files`; do
		file=`echo $i | cut -d'_'  -f 1-5`
		if [[ $file == $last_file ]]; then
			continue
		fi
		last_file=$file
		out_line=`echo $i | cut -d'.' -f 2`
		out_line=$out_line":"`echo $i | cut -d'_' -f 2 | cut -d'.' -f1`
		out_line=$out_line":"`echo $i | cut -d'_' -f 4 | cut -d'.' -f1`
		retrieve_line "^Copy" $file
		retrieve_line "^Scale" $file
		retrieve_line "^Add" $file
		retrieve_line "^Triad" $file
		echo $out_line >> temp_file
	done
	#
	# Header
	#
	echo buffer size:#threads:#sockets:Copy:Scale:Add:Triad >> results_streams.csv
	#
	# Now the actual results
	#
	sort -n temp_file >> results_streams.csv
}

#
# Retrieve the system configuration information
#
retrieve_sys_config()
{
	echo "# kernel_rev "`grep "^kernel:" stream* | cut -d: -f 3 | sort -u` > results_streams.csv
	echo "# numa_nodes "`grep "^NUMA node(s):" stream* | cut -d: -f 3 | sort -u` >> results_streams.csv
	echo "# number_cpus "`grep "^CPU(s):" stream* | cut -d: -f 3 | sort -u`  >> results_streams.csv
	echo "# Thread(s)_per_core "`grep "Thread(s) per core:" stream* | cut -d: -f 3 | sort -u`  >> results_streams.csv
	echo "# Core(s)_per_socket "`grep "Core(s) per socket:" stream* | cut -d: -f 3 | sort -u`  >> results_streams.csv
	echo "# Socket(s) "`grep "Socket(s):" stream* | cut -d: -f 3 | sort -u`  >> results_streams.csv
	echo "# Model_name "`grep "^Model name" stream* | cut -d: -f 3 | sort -u` >> results_streams.csv
	echo "# total_memory "`grep "MemTotal:" /proc/meminfo | cut -d':' -f 2 | sed "s/ //g"` >> results_streams.csv
	echo "# streams_version_# "`grep "^STREAM version" stream* | cut -d':' -f 3 | cut -d' ' -f2 | sort -u` >> results_streams.csv
}

retrieve_sys_config
echo "//Graph: Streams" > results_${test_name}.csv
echo "//Graph_type: bar" >> results_${test_name}.csv
echo "//Title: Streams" >> results_${test_name}.csv
echo "//Subtitle: ${to_configuration}" >> results_${test_name}.csv
echo "//x axis: NONE" >>results_${test_name}.csv
echo "//y axis: Throughput (MB/s)" >>results_${test_name}.csv

retrieve_results

