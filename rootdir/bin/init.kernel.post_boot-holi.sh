#=============================================================================
# Copyright (c) 2020-2021 Qualcomm Technologies, Inc.
# All Rights Reserved.
# Confidential and Proprietary - Qualcomm Technologies, Inc.
#
# Copyright (c) 2012-2013, 2016-2020, The Linux Foundation. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above
#       copyright notice, this list of conditions and the following
#       disclaimer in the documentation and/or other materials provided
#       with the distribution.
#     * Neither the name of The Linux Foundation nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
# WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
# ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
# BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
# OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
# IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#=============================================================================

function configure_zram_parameters() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}

	# Zram disk - 75% for < 2GB devices .
	# For >2GB devices, size = 50% of RAM size. Limit the size to 4GB.

	let RamSizeGB="( $MemTotal / 1048576 ) + 1"
	diskSizeUnit=M
	if [ $RamSizeGB -le 2 ]; then
		let zRamSizeMB="( $RamSizeGB * 1024 ) * 3 / 4"
	else
		let zRamSizeMB="( $RamSizeGB * 1024 ) / 2"
	fi

	# use MB avoid 32 bit overflow
	if [ $zRamSizeMB -gt 4096 ]; then
		let zRamSizeMB=4096
	fi

	if [ -f /sys/block/zram0/disksize ]; then
		if [ -f /sys/block/zram0/use_dedup ]; then
			echo 1 > /sys/block/zram0/use_dedup
		fi
		echo "$zRamSizeMB""$diskSizeUnit" > /sys/block/zram0/disksize

		# ZRAM may use more memory than it saves if SLAB_STORE_USER
		# debug option is enabled.
		if [ -e /sys/kernel/slab/zs_handle ]; then
			echo 0 > /sys/kernel/slab/zs_handle/store_user
		fi
		if [ -e /sys/kernel/slab/zspage ]; then
			echo 0 > /sys/kernel/slab/zspage/store_user
		fi

		mkswap /dev/block/zram0
		swapon /dev/block/zram0 -p 32758
	fi
}

#/*Add swappiness tunning parameters*/
function oplus_configure_tunning_swappiness() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}

	if [ $MemTotal -le 6291456 ]; then
		echo 0 > /proc/sys/vm/swappiness_threshold1_size
		echo 0 > /proc/sys/vm/swappiness_threshold1_size
		echo 0 > /proc/sys/vm/vm_swappiness_threshold2
		echo 0 > /proc/sys/vm/swappiness_threshold2_size
	elif [ $MemTotal -le 8388608 ]; then
		echo 100 > /proc/sys/vm/vm_swappiness_threshold1
		echo 2000 > /proc/sys/vm/swappiness_threshold1_size
		echo 120 > /proc/sys/vm/vm_swappiness_threshold2
		echo 1500 > /proc/sys/vm/swappiness_threshold2_size
	else
		echo 100 > /proc/sys/vm/vm_swappiness_threshold1
		echo 4096 > /proc/sys/vm/swappiness_threshold1_size
		echo 120 > /proc/sys/vm/vm_swappiness_threshold2
		echo 2048 > /proc/sys/vm/swappiness_threshold2_size
	fi
}

#ifdef OPLUS_FEATURE_ZRAM_OPT
function oppo_configure_zram_parameters() {
    MemTotalStr=`cat /proc/meminfo | grep MemTotal`
    MemTotal=${MemTotalStr:16:8}

    echo lz4 > /sys/block/zram0/comp_algorithm
    echo 160 > /sys/module/zram_opt/parameters/vm_swappiness
    echo 60 > /sys/module/zram_opt/parameters/direct_vm_swappiness
    echo 0 > /proc/sys/vm/page-cluster

    if [ -f /sys/block/zram0/disksize ]; then
        if [ -f /sys/block/zram0/use_dedup ]; then
            echo 1 > /sys/block/zram0/use_dedup
        fi

        if [ $MemTotal -le 524288 ]; then
            #config 384MB zramsize with ramsize 512MB
            echo 402653184 > /sys/block/zram0/disksize
        elif [ $MemTotal -le 1048576 ]; then
            #config 768MB zramsize with ramsize 1GB
            echo 805306368 > /sys/block/zram0/disksize
        elif [ $MemTotal -le 2097152 ]; then
            #config 1GB+256MB zramsize with ramsize 2GB
            echo lz4 > /sys/block/zram0/comp_algorithm
            echo 1342177280 > /sys/block/zram0/disksize
        elif [ $MemTotal -le 3145728 ]; then
            #config 1GB+512MB zramsize with ramsize 3GB
            echo 1610612736 > /sys/block/zram0/disksize
        elif [ $MemTotal -le 4194304 ]; then
            #config 2GB+512MB zramsize with ramsize 4GB
            echo 2684354560 > /sys/block/zram0/disksize
        elif [ $MemTotal -le 6291456 ]; then
            #config 3GB zramsize with ramsize 6GB
            echo 3221225472 > /sys/block/zram0/disksize
        else
            #config 4GB zramsize with ramsize >=8GB
            echo 4294967296 > /sys/block/zram0/disksize
        fi
        mkswap /dev/block/zram0
        swapon /dev/block/zram0 -p 32758
    fi
}

function oplus_configure_hybridswap() {
	kernel_version=`uname -r`

	if [[ "$kernel_version" == "5.10"* ]]; then
		echo 160 > /sys/module/oplus_bsp_zram_opt/parameters/vm_swappiness
	else
		echo 160 > /sys/module/zram_opt/parameters/vm_swappiness
	fi

	echo 0 > /proc/sys/vm/page-cluster

	# FIXME: set system memcg pata in init.kernel.post_boot-lahaina.sh temporary
	echo 500 > /dev/memcg/system/memory.app_score
	echo systemserver > /dev/memcg/system/memory.name
}
#endif /*OPLUS_FEATURE_ZRAM_OPT*/
function configure_read_ahead_kb_values() {
	MemTotalStr=`cat /proc/meminfo | grep MemTotal`
	MemTotal=${MemTotalStr:16:8}

	dmpts=$(ls /sys/block/*/queue/read_ahead_kb | grep -e dm -e mmc)

	# Set 128 for <= 3GB &
	# set 512 for >= 4GB targets.
	if [ $MemTotal -le 3145728 ]; then
		ra_kb=128
	else
		ra_kb=512
	fi
	if [ -f /sys/block/mmcblk0/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0/bdi/read_ahead_kb
	fi
	if [ -f /sys/block/mmcblk0rpmb/bdi/read_ahead_kb ]; then
		echo $ra_kb > /sys/block/mmcblk0rpmb/bdi/read_ahead_kb
	fi
	for dm in $dmpts; do
		echo $ra_kb > $dm
	done
}

function configure_memory_parameters() {
	# Set Memory parameters.

#ifdef OPLUS_FEATURE_ZRAM_OPT
	# For vts test which has replace system.img
	ls -l /product | grep '\-\>'
	if [ $? -eq 0 ]; then
		oplus_configure_zram_parameters
	else
		if [ -f /sys/block/zram0/hybridswap_enable ]; then
			oplus_configure_hybridswap
		else
			oplus_configure_zram_parameters
		fi
	fi
#else
#       configure_zram_parameters
#endif /*OPLUS_FEATURE_ZRAM_OPT*/
	configure_read_ahead_kb_values
	echo 0 > /proc/sys/vm/page-cluster

	echo 16 > /proc/sys/vm/watermark_scale_factor

	echo 0 > /proc/sys/vm/watermark_boost_factor
#ifndef OPLUS_FEATURE_ZRAM_OPT
#	echo 100 > /proc/sys/vm/swappiness
#endif /*OPLUS_FEATURE_ZRAM_OPT*/
}

# Core control parameters for silver
echo 0 0 0 0 1 1 > /sys/devices/system/cpu/cpu0/core_ctl/not_preferred
echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
echo 60 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
echo 40 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
echo 8 > /sys/devices/system/cpu/cpu0/core_ctl/task_thres

# Enable Core control for Silver
echo 1 > /sys/devices/system/cpu/cpu0/core_ctl/enable

# Disable Core control on gold
echo 0 > /sys/devices/system/cpu/cpu6/core_ctl/enable

# Setting b.L scheduler parameters
echo 65 > /proc/sys/kernel/sched_downmigrate
echo 71 > /proc/sys/kernel/sched_upmigrate
echo 85 > /proc/sys/kernel/sched_group_downmigrate
echo 100 > /proc/sys/kernel/sched_group_upmigrate
echo 1 > /proc/sys/kernel/sched_walt_rotate_big_tasks
echo 0 > /proc/sys/kernel/sched_coloc_busy_hysteresis_enable_cpus
echo 0 > /proc/sys/kernel/sched_busy_hysteresis_enable_cpus
echo 5 > /proc/sys/kernel/sched_ravg_window_nr_ticks

# disable unfiltering
echo 20000000 > /proc/sys/kernel/sched_task_unfilter_period

# cpuset parameters
echo 0-5 > /dev/cpuset/background/cpus
echo 0-5 > /dev/cpuset/system-background/cpus

# Turn off scheduler boost at the end
echo 0 > /proc/sys/kernel/sched_boost

# configure governor settings for silver cluster
echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 20000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/down_rate_limit_us
echo 500 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/up_rate_limit_us

# configure governor settings for gold cluster
echo "schedutil" > /sys/devices/system/cpu/cpufreq/policy6/scaling_governor
echo 20000 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/down_rate_limit_us
echo 500 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/up_rate_limit_us

# Colocation V3 settings
echo 680000 > /sys/devices/system/cpu/cpufreq/policy0/schedutil/rtg_boost_freq
echo 0 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/rtg_boost_freq
echo 51 > /proc/sys/kernel/sched_min_task_util_for_boost
echo 35 > /proc/sys/kernel/sched_min_task_util_for_colocation

# sched_load_boost as -6 is equivalent to target load as 85. It is per cpu tunable.
echo -6 > /sys/devices/system/cpu/cpu6/sched_load_boost
echo -6 > /sys/devices/system/cpu/cpu7/sched_load_boost
echo 85 > /sys/devices/system/cpu/cpufreq/policy6/schedutil/hispeed_load

# Enable bus-dcvs
for device in /sys/devices/platform/soc
do
	for cpubw in $device/*cpu-cpu-ddr-bw/devfreq/*cpu-cpu-ddr-bw
	do
		cat $cpubw/available_frequencies | cut -d " " -f 1 > $cpubw/min_freq
		echo "bw_hwmon" > $cpubw/governor
		echo "1144 1720 2086 2929 3879 5931 6881 8137" > $cpubw/bw_hwmon/mbps_zones
		echo 4 > $cpubw/bw_hwmon/sample_ms
		echo 68 > $cpubw/bw_hwmon/io_percent
		echo 20 > $cpubw/bw_hwmon/hist_memory
		echo 0 > $cpubw/bw_hwmon/hyst_length
		echo 80 > $cpubw/bw_hwmon/down_thres
		echo 0 > $cpubw/bw_hwmon/guard_band_mbps
		echo 250 > $cpubw/bw_hwmon/up_scale
		echo 1600 > $cpubw/bw_hwmon/idle_mbps
		echo 40 > $cpubw/polling_interval
	done

	# configure compute settings for silver latfloor
	for latfloor in $device/*cpu0-cpu*latfloor/devfreq/*cpu0-cpu*latfloor
	do
		cat $latfloor/available_frequencies | cut -d " " -f 1 > $latfloor/min_freq
		echo 8 > $latfloor/polling_interval
	done

	# configure compute settings for gold latfloor
	for latfloor in $device/*cpu6-cpu*latfloor/devfreq/*cpu6-cpu*latfloor
	do
		cat $latfloor/available_frequencies | cut -d " " -f 1 > $latfloor/min_freq
		echo 8 > $latfloor/polling_interval
	done

	# configure mem_latency settings for DDR scaling
	for memlat in $device/*lat/devfreq/*lat
	do
		cat $memlat/available_frequencies | cut -d " " -f 1 > $memlat/min_freq
		echo 8 > $memlat/polling_interval
		echo 400 > $memlat/mem_latency/ratio_ceil
	done

	#Gold CPU6 L3 ratio ceil
	for l3gold in $device/*cpu6-cpu-l3-lat/devfreq/*cpu6-cpu-l3-lat
	do
		echo 4000 > $l3gold/mem_latency/ratio_ceil
		echo 25000 > $l3gold/mem_latency/wb_filter_ratio
		echo 60 > $l3gold/mem_latency/wb_pct_thres
	done

	#Gold CPU7 L3 ratio ceil
	for l3gold in $device/*cpu7-cpu-l3-lat/devfreq/*cpu7-cpu-l3-lat
	do
		echo 4000 > $l3gold/mem_latency/ratio_ceil
		echo 25000 > $l3gold/mem_latency/wb_filter_ratio
		echo 60 > $l3gold/mem_latency/wb_pct_thres
	done

done

echo N > /sys/module/lpm_levels/parameters/sleep_disabled

configure_memory_parameters

setprop vendor.post_boot.parsed 1
