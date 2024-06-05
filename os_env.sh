#!/bin/bash

export LANG=en_US.UTF-8

# 获取操作系统信息
function get_os_info(){
    if [[ -n ${OS_VERSION} ]];then
        return
    fi

    if [[ -f /etc/redhat-release ]];then
        eval $(
            awk '{
                split($(NF-1),v,"."); 
                printf "ID=%s\nVERSION_ID=%s.%s\n", $1, v[1], v[2]
            }' /etc/redhat-release
        )
    elif [[ -f /etc/os-release ]];then
        source /etc/os-release
    else
        echo "不支持的操作系统"
        exit 1
    fi

    OS_VERSION="${ID/_/.}${VERSION_ID/_/.}"
}

# 获取CPU厂家
function get_cpu_mf(){
    if [[ -n ${CPUMF} ]];then
        return
    fi

    CPUMF=$(
        lscpu | \
        awk -F':' '{
            gsub(/[\t ]+/,"",$0);
            if($1=="VendorID"){
                if($2=="GenuineIntel"){
                    $2="Intel"
                }else if($2=="HygonGenuine"){
                    $2="Hygon"
                };
                print $2
            }
        }'
    )
}

# 获取CPU架构
function get_arch(){
    if [[ -n ${ARCH} ]];then
        return
    fi

    export ARCH=$(uname -m)
}

# 获取客户信息
function get_customer(){
    if [[ -n ${CUSTOMER} ]];then
        return
    fi

    CUSTOMER="common"
}

# 生成release
function get_release(){
    if [[ -n ${RELEASE} ]];then
        return
    fi
    
    get_os_info
    get_cpu_mf
    get_customer
    export RELEASE="${OS_VERSION}_${CUSTOMER}_${CPUMF}"
    if [[ -n ${batch} ]];then
        export RELEASE="${RELEASE}_${batch}"
    fi
}

function main(){
    get_release
    get_arch

    echo "release: ${RELEASE}"
    echo "cpu arch: ${ARCH}"
}

main
