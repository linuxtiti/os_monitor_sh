#!/usr/bin/env bash 

log_writter()
{
    log_title=$1
    log_content=$2
    echo "${log_title} `date "+%F %T"` : ${log_content}" 
}

check_os_type()
{
    DEBIAN_VERSION=/etc/debian_version  #include ubuntu
    SUSE_RELEASE1=/etc/SuSE-release  
    #this file deprecated and will be removed in the future, use /etc/os-release instead
    SUSE_RELEASE2=/etc/os-release  # suse will use this file in the future
    RHEL_RELEASE=/etc/redhat-release    #this can support RHEL and CentOS, Maybe OEL too, I don't know 
    #decide os version
    if [ -f ${DEBIAN_VERSION} ]; then
        echo "debian"
    elif [ -f ${SUSE_RELEASE1} -o -f ${SUSE_RELEASE1} ]; then
        echo "suse"
    elif [ -f $RHEL_RELEASE ]; then
        echo "redhat"
    else
        echo "not support os type"
    fi
}

get_cpu_status_v1()
{
    func_name="get_cpu_status_v1"
    cpu_raw_data=`top -bn 1|grep -E "^%?[Cc]pu"|awk -F: '{print $2}'|sed 's/%/ /g'|xargs -d, -n 1| \
    awk '$2 ~ /([usiw])([syda])/{print $2":"$1","}'|xargs -n 4|sed 's/,$//'`
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "cmd out: ${cpu_raw_data}"
    cpu_status_data=`echo ${cpu_raw_data}|sed -e 's/us/\"USER\"/' -e 's/id/\"IDLE\"/' -e 's/wa/\"IO_WAIT\"/' -e 's/sy/\"SYSTEM\"/'`
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "return value: ${cpu_status_data}"
    echo "${cpu_status_data}"
}


get_cpu_status_v2()
{
    func_name="get_cpu_status_v2"
    cpu_data_file="/proc/stat"
    cpu_status_data=`grep -w "^cpu" ${cpu_data_file}|awk 'BEGIN{FS=" "; OFS=","} {print "\"USER\":"$2,"\"NICE\":"$3,"\"SYSTEM\":"$4,"\"IDLE\":"$5,"\"IO_WAIT\":"$6,"\"IRQ\":"$7,"\"SOFTIRQ\":"$8,"\"STEAL\":"$9}'`
    echo "${cpu_status_data}"
}

get_mem_status()
{
    func_name="get_mem_status"
    mem_raw_data1=`grep -E "MemTotal|MemFree|Buffers|Cached" /proc/meminfo|grep -v -i swap|tr [a-z] [A-Z]| \
    sed 's/://g'|awk '{print "\""$1"\""":"$2","}'`
    mem_raw_data=`echo ${mem_raw_data1}|sed 's/,$//'`
    #[ $DEBUG_LEVEL -ge 2 ] && echo $mem_status_data
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "cmd out: ${mem_raw_data}"
    mem_status_data=`echo ${mem_raw_data}`
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "return value: ${mem_status_data}"
    echo  "${mem_status_data}"
}

get_netdev_status()
{
    func_name="get_netdev_status"
    RX_BYTES=""
    TX_BYTES=""
    rx_bytes_list=`cat /proc/net/dev|grep -v -E "^Inter|face|lo"|awk '{print $2":"$10}'|xargs`
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "cmd out: ${rx_bytes_list}"
    for rxtx in `echo ${rx_bytes_list}`
    do
        [ $DEBUG_LEVEL -ge 3 ] && log_writter "[func:${func_name}][${log_out_title}]" "rxtx: ${rxtx}"
        rx=`echo $rxtx|awk -F":" '{print $1}'`
        tx=`echo $rxtx|awk -F":" '{print $2}'`
        RX_BYTES=`expr ${RX_BYTES} + ${rx}`
        TX_BYTES=`expr ${TX_BYTES} + ${tx}`
    done    
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "RX_BYTES: ${RX_BYTES}"
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "TX_BYTES: ${TX_BYTES}"
    netdev_status_data="\"RX_BYTES\":${RX_BYTES},\"TX_BYTES\":${TX_BYTES}"
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "return value: ${netdev_status_data}"
    echo ${netdev_status_data}
}

get_disk_usage()
{
    func_name="get_disk_usage"
    total_disk_avai=""
    total_disk_used=""
    disk_usage_list=`df -T|grep -E -v "tmpfs|^[Ff]ilesystem" |awk 'NF>1{print $(NF-3)":"$(NF-2)}'|xargs`
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "cmd out: ${disk_usage_list}"
    for usage_data in `echo ${disk_usage_list}`
    do
        [ $DEBUG_LEVEL -ge 3 ] && log_writter "[func:${func_name}][${log_out_title}]" "inside loop: ${usage_data}"
        disk_used=`echo ${usage_data}|awk -F':' '{print $1}'`
        disk_avai=`echo ${usage_data}|awk -F':' '{print $2}'`
        total_disk_used=`expr ${total_disk_used} + ${disk_used}`
        total_disk_avai=`expr ${total_disk_avai} + ${disk_avai}`
    done
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "disk_avai: ${total_disk_avai}"
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "disk_used: ${total_disk_used}"
    total_disk_space=`expr ${total_disk_avai} + ${total_disk_used}`
    #disk_usage_percent=`echo "${total_disk_used} ${total_disk_space}"|awk 'BEGIN{printf "%.2f%\n",('$t1'/'$t2')*100}'`
    disk_usage_percent=`awk 'BEGIN{printf "%.2f\n",('$total_disk_used'/'$total_disk_space')*100}'`
    [ $DEBUG_LEVEL -ge 2 ] && log_writter "[func:${func_name}][${log_out_title}]" "disk_used_percent: ${disk_usage_percent}"
    #disk_usage_data="DISK_USAGE:${disk_usage_percent}"
    #2016 1103  output change to " DISK_TOTAL DISK_AVAILABLE DISK_USAGE"
    disk_status_data="{\"DISK_TOTAL\":${total_disk_space},\"DISK_AVAILABLE\":${total_disk_avai},\"DISK_USAGE\":${disk_usage_percent}}"
    echo ${disk_status_data}
}

#main function begin here 
#part1 global variables 
DEBUG_LEVEL=0
OS_TYPE=""
#debug code mapping
#0:no debug output
#1:warning
#2:info
#3:debug
#decide debug out title
log_out_title=""
case ${DEBUG_LEVEL} in
    1)log_out_title="warning"
    ;;
    2)log_out_title="info"
    ;;
    3)log_out_title="debug"
esac

#part1 global variables ends 

OS_TYPE=`check_os_type`
[ $DEBUG_LEVEL -ge 1 ] && echo $OS_TYPE

if [ $DEBUG_LEVEL -ge 2 ]
then
    get_cpu_status
    get_mem_status
    get_disk_usage
    get_netdev_status
else
    cpu_str=`get_cpu_status_v2`
    mem_str=`get_mem_status`
    netdev_str=`get_netdev_status`
    disk_usage_str=`get_disk_usage`
    ret_str="{\"CPU\":{$cpu_str},\"MEM\":{$mem_str},\"NETDEV\":{$netdev_str},\"DISK\":$disk_usage_str}"
    echo ${ret_str}
fi
