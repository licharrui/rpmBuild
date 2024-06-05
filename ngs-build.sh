#!/bin/bash

function print_usage(){
    PROGNAME=$(basename $0)
    echo ""
    echo "${PROGNAME} - 解析编译参数；设置环境变量；编译、打包前必须处理的依赖编译部分等（填补各项目编译脚本未考虑到的坑）"
    echo ""
    echo "  Usage: ${PROGNAME} <--version x.x.x> [--cpu_platform CodeName简写] [--project 项目名] [--dpiv3 dpiv3的svn地址]  [--user svn用户名/密码] <编译宏1 [编译宏2 [... [编译宏n]]]>"
    echo ""
    echo -n "   --version"
    version_description
    echo ""
    echo -n "   --project"
    project_description
    echo ""
    echo -n "   --dpiv3"
    dpiv3_description
    echo ""
    # echo -n "   --dpiv5_platform"
    # dpiv5_description
    # echo ""
    echo -n "   --user"
    user_description
    echo ""
    echo -n "   --cpu_platform"
    cpu_description
    echo ""
    echo "  编译宏为： build.sh 脚本所需要带的参数。根据'build.sh'脚本的需要进行传参
        此脚本调用了'build_reform.sh'，请修改'build.sh'脚本时，同步修改'build_reform.sh'"
    echo ""
}

function version_description(){
    echo " 说明： 版本号只能用数字表示，各部分以点（.）连接 
        例如：DPI程序现存版本有三个，分别是V3、V5、V6。
             V3的版本号为: 3.x.x ;
             V5的版本号为: 5.x.x; 
             V6的版本号为 6.x.x
        1. 一级版本号，通常表示系统架构变更
        2. 二级版本号，通常表示新增开发需求，系统功能变更
        3. 三级版本号，通常表示BUG修复，或者极小的改动"
}

function cpu_description(){
    echo " 说明： 需要通过cpu平台（简写）指定DPDK的编译平台。
        目前广东移动部分服务器使用的不是Xeon系统列的CPU，编译时，需提供些参数。
        可到https://ark.intel.com/content/www/us/en/ark.html 上通过cpu型号查询到相应的平台。
        目前收集到的intel平台的如下：
        |-------------------------|
        | 简写 |  全称(Code Name) |
        |-------------------------|
        | wsm |  Westmere         |
        |-------------------------|
        | nhm |  Nehalem          |
        |-------------------------|
        | snb |  Sandy Bridge     |
        |-------------------------|
        | ivb |  Ivy Bridge       |
        |-------------------------|
        | hsw |  Haswell          |
        |-------------------------|"
}

function project_description(){
    echo " 说明： 可选参数。用于编译、安装依赖，以下项目必须带项目名 
        |----------------------------------------------------|
        | 项目名           |  描述                           |
        |----------------------------------------------------|
        | ngs-dpi          | 包含dpiv3、dpiv5、dpiv6(4g、5g) |
        |----------------------------------------------------|
        | ngs-astd         | astd项目                        |
        |----------------------------------------------------|
        | ngs-netlog       | 上网日志项目                    |
        |----------------------------------------------------|"
}

function dpiv3_description(){
    echo " 说明： 所有对DPIV3有依赖的项目都需带此参数。此参数须与'--user'一起使用"
}

function dpiv5_description(){
    echo " 说明： 所有对DPIV5平台有依赖的项目都需带此参数（目前只有dpiv5使用）。此参数须与'--user'一起使用"
}

function user_description(){
    echo " 说明： 所有需要依赖SVN其他项目时都需带此参数，单独使用无意义。
        格式： svn_user/svn_password
        示例： brd/123456789
        示例说明： 'brd'为svn用户名；'123456789'为该用户的svn密码"
}

function check_opt(){
    local flag=0
    if [[ "--" == ${1:0:2} ]];then
        flag=2
    elif [[ "-" == ${1:0:1} ]];then
        flag=1
    fi
    return ${flag}
}

function assignment(){
    case $1 in
        --version)
            version=$2
            ;;
        --cpu_platform)
            cpu_platform=$2
            ;;
        --project)
            project=$2
            ;;
        --dpiv3)
            dpiv3=$2
            ;;
        --user)
            user=$2
            ;;
        --batch)
            batch=$2
            ;;
        *)
            return
            ;;
    esac
}

function get_opt(){
    var_length=$#
    if [[ ${var_length} -lt 3 ]];then
        print_usage
    fi
    build_args=""
    for ((i=1;i<=${var_length};i++))
    do
        opt=${@:$i:1}
        if [[ ${opt} == "-h" || ${opt} == "--help" ]];then
            print_usage
            exit 0
        fi
        check_opt ${opt}
        flag=$?
        if [[ ${flag} == 0 ]];then
            build_args="${build_args} ${opt}"
            continue
        elif [[ ${flag} == 1 ]];then
            continue
        fi
        value=${@:$i+1:1}
        check_opt ${value}
        if [[ $? == 2 || $? == 1 ]];then
            continue
        fi
        ((i++))
        assignment ${opt} ${value}
    done
}

function check_project(){
    if [[ -z ${project} || "${project}" == "" ]];then
        echo -e "\033[31m 请指定正常项目名。 \033[0m"
        exit 1
    else
        export project
    fi
}

function check_version(){
    if [[ "${version}" =~ ^[0-9]{1,}\.[0-9]{1,}\.[0-9]{1,}$ ]];then
        export version
    else
        echo -e "\033[31m 请指定正常的打包版本号。 \033[0m"
        version_description
        exit 1
    fi
}

function set_batch(){
    if [[ -z ${batch} || "${batch}" == "" ]];then
        export batch=$(date +%Y%m%d%H%M%S)
    else
        export batch
    fi
}

function check_cpu(){
    if [[ -z ${cpu_platform} ]];then
        cpu_platform="native"
    fi
    export cpu_platform
    export RTE_TARGET="x86_64-${cpu_platform}-linuxapp-gcc" 
}

function dpiv3_depend(){
    # 当不为dpiv3时直接返回
    if [[ ! (${version} =~ ^3\.[0-9]{1,}\.[0-9]{1,}$ && ${project::7} == "ngs-dpi") ]];then
        return
    fi
    # 病毒库编译所需
    if [[ -d src/se-clamav-scan/libclamav/lib64 ]];then
        cp -a /usr/local/clamav/lib64/* src/se-clamav-scan/libclamav/lib64/ || exit 1
    else
        echo "Warning: not found se-clamav-scan"
    fi

    # 编译pf_ring
    cd src/common/pf_c++ || exit 1
    make libpfring_cpp.a libpcap_cpp.a || exit 1
    \cp libpcap_cpp.a  libpfring_cpp.a /usr/local/lib/ || exit 1
    cd - || exit 1

    # 编译free_hash
    if [[ -d src/se-dpi/free_hash ]];then
        cd src/se-dpi/free_hash || exit 1
        make && \cp libfreehash.so /usr/local/lib  || exit 1
        cd -
    fi
}

function netlog_depend(){
    if [[ ${project} != "ngs-netlog" ]];then
        return
    fi
    svn co ${dpiv3%:*}/src/se-xdr2file -r ${dpiv3##*:} \
    --username ${user%%/*} --password ${user#*/} \
    --no-auth-cache lib2fileintf || exit 1
    cd lib2fileintf && \
    make clean && \
    cd 2fileintf && \
    make && cd - \
    && \cp bin/lib2fileintf.so ../3rd/lib/lib2fileintf.so && \
    cd .. || exit 1
    echo "lib2fileintf:
    url: ${dpiv3%:*}/src/se-xdr2file
    rversion: ${dpiv3##*:}
    time: $(date +'%Y-%m-%d %H:%M:%S')
    "
}

function astd_depend(){
    if [[ ${project} != "ngs-astd" ]];then
        return
    fi
    svn co ${dpiv3%:*}/src/common/byinc -r ${dpiv3##*:} \
    --username ${user%%/*} --password ${user#*/} \
    --no-auth-cache byinc || exit 1
    echo "byinc:
    url: ${dpiv3%:*}/src/common/byinc
    rversion: ${dpiv3##*:}
    time: $(date +'%Y-%m-%d %H:%M:%S')
    "
}

function build(){
    # 检查编译宏
    if [[ $# == 0 ]];then
        echo -e "\033[31m 请提供编译宏 \033[0m"
        exit 1
    fi

    # 调用打包脚本
    find . -name "*.sh" | xargs chmod +x
    if [[ -f build_reform.sh ]];then
        bash build_reform.sh clean && bash build_reform.sh $* || exit 1
    elif [[ -f build.sh ]];then
        bash build.sh clean && bash build.sh $* || exit 1
    else
        echo "未找到编译脚本"
        exit 1
    fi
}

function main(){
    # 解析脚本参数
    get_opt "$@"

    # 检查项目名
    check_project

    # 检查版本号规则
    check_version

    # 配置打包时间
    set_batch

    # 检查cpu平台参数
    check_cpu

    # dpiv3依赖编译
    dpiv3_depend

    # 上网日志依赖处理
    netlog_depend

    # astd依赖处理
    astd_depend

    # 项目编译
    build ${build_args}
}

main $*
