###############################################################################
#rpm安装包描述

Name: brd-%{appname}
Version: %{ver}
Release: %{release}
Summary: oplatform install

Group: Development/Languages
License: GPL
URL: http://www.broadtech.com.cn/
Buildarch: %{arch}
BuildRoot: %(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)
Source1: service
Requires: ngs-python3 >= 3.10.0
AutoReqProv: no

%define debug_package %{nil}
%define __os_install_post %{nil}

###############################################################################
#定义rpm包文件安装目录

%define rpmbulid      %{_topdir}/BUILD
%define pakectpath    %{_topdir}/../../dist
%define appspath      /opt/ngs/application
%define superpath     %{appspath}/supervisor
%define servicepath   %{superpath}/conf.d
%define toolspath     /opt/ngs/tools
%define datapath      %{appspath}/%{appname}/data
%define configpath    %{appspath}/%{appname}/configs
%define versionpath   /opt/ngs/version
%define systemdpath   /usr/lib/systemd/system
%define rsyslogpath   /etc/rsyslog.d
%define librarypath   /usr/lib64/
%define grafana_plugin_path /opt/ngs/application/grafana/data/plugins/

###############################################################################
#软件功能简介
%description
This package can be used to install script file for ngs service
###############################################################################
#预处理脚本, 如解压工作
%prep
echo `pwd`"setp prep"
rm -rf %{_topdir}/RPMS/%{buildroot}/*
rm -rf %{_topdir}/BUILDROOT/*
rm -rf %{rpmbulid}/*
###############################################################################
#开始构建包, 如make工作
%build
echo `pwd`"setp build"
mkdir -p %{buildroot}
###############################################################################
#开始把软件安装到虚拟根目录中, 如make install工作
%install
echo `pwd`"setp install"
#拷贝服务文件
mkdir -p ${RPM_BUILD_ROOT}%{appspath}
mkdir -p ${RPM_BUILD_ROOT}%{versionpath}
mkdir -p ${RPM_BUILD_ROOT}%{systemdpath}
mkdir -p ${RPM_BUILD_ROOT}%{rsyslogpath}
mkdir -p ${RPM_BUILD_ROOT}%{librarypath}

cp -a %{pakectpath}/%{appname}    ${RPM_BUILD_ROOT}%{appspath}/
cp %{SOURCE1}/%{appname}.daily    ${RPM_BUILD_ROOT}%{appspath}/%{appname}
cp %{SOURCE1}/%{appname}.hourly   ${RPM_BUILD_ROOT}%{appspath}/
cp %{SOURCE1}/%{appname}.service  ${RPM_BUILD_ROOT}%{systemdpath}/
cp %{SOURCE1}/%{appname}.rsyslog  ${RPM_BUILD_ROOT}%{rsyslogpath}/%{appname}.conf

# cp grafana files
mv %{pakectpath}/grafana/grafana    ${RPM_BUILD_ROOT}%{appspath}/
cp %{SOURCE1}/grafana.daily         ${RPM_BUILD_ROOT}%{appspath}/grafana
cp %{SOURCE1}/grafana.hourly        ${RPM_BUILD_ROOT}%{appspath}/grafana
cp %{SOURCE1}/grafana.service       ${RPM_BUILD_ROOT}%{systemdpath}/
cp %{SOURCE1}/grafana.rsyslog       ${RPM_BUILD_ROOT}%{rsyslogpath}/grafana.conf


# 创建grafana插件目录
mkdir -p ${RPM_BUILD_ROOT}%{grafana_plugin_path}
mv %{pakectpath}/grafana/agenty-flowcharting-panel    ${RPM_BUILD_ROOT}%{grafana_plugin_path}
mv %{pakectpath}/grafana/volkovlabs-variable-panel    ${RPM_BUILD_ROOT}%{grafana_plugin_path}
mv %{pakectpath}/grafana/marcusolsson-json-datasource ${RPM_BUILD_ROOT}%{grafana_plugin_path}
mv %{pakectpath}/grafana/ngs-grafanaantv6-panel       ${RPM_BUILD_ROOT}%{grafana_plugin_path}

# 复制libyaml库
mkdir -p ${RPM_BUILD_ROOT}%{appspath}/%{appname}/libs
cp %{librarypath}/libyaml-0.so.2  ${RPM_BUILD_ROOT}%{appspath}/%{appname}/libs

if [[ -f /etc/Version.yaml ]];then
    cp /etc/Version.yaml ${RPM_BUILD_ROOT}%{versionpath}/%{name}-%{version}-%{release}.%{arch}.yaml
else
    touch ${RPM_BUILD_ROOT}%{versionpath}/%{name}-%{version}-%{release}.%{arch}.yaml
fi

###############################################################################
#安装前执行的脚本
%pre
# Systemctl不存在时，检查、创建 supervisor 服务配置目录
if [[ ! -x /usr/bin/systemctl && ! -d %{servicepath} ]];then
    mkdir -p %{servicepath}
fi

###############################################################################
#卸载前执行的脚本
%preun

if [[ $1 == 0 ]];then
    if [[ -x /usr/bin/systemctl ]];then
        # 使用 systemctl 命令停止服务
        /usr/bin/systemctl disable %{appname} grafana 2>&1>>/dev/null
        /usr/bin/systemctl stop %{appname} grafana
    else
        # 使用 supervisorctl 命令停止服务
        %{toolspath}/python/bin/supervisorctl -c \
        %{superpath}/supervisord.conf stop %{appname} grafana 2>/dev/null || \
        echo "supervisor not start"
    fi

    # 备份配置文件目录、本地缓存数据目录
    if [[ -e %{datapath}_save && -d %{datapath} ]];then
        rm -fr %{datapath}_save
    fi

    if [[ -e %{configpath}_save && -d %{configpath} ]];then
        rm -fr %{configpath}_save
    fi

    if [[ -d %{datapath} ]];then
        cp -a %{datapath} %{datapath}_save
    fi

    if [[ -d %{configpath} ]];then
        cp -a %{configpath} %{configpath}_save
    fi
fi
###############################################################################
#安装后执行脚本
%post

# /etc/cron.hourly执行的时间是每小时的第一分钟，不满足要求
# 添加logrotate定时任务，默认的logrotate任务每天执行一次，这里自定义每小时执行一次的任务
echo "remove ngs-oplatform logrotate cron"
crontab -l | grep -vE "(%{appname}/%{appname}.hourly)|(%{appname}/%{appname}.daily)" | crontab -

echo "add ngs-oplatform logrotate cron"
echo "0 1-23 * * * /usr/sbin/logrotate %{appspath}/%{appname}/%{appname}.hourly > /dev/null 2>&1" >> /var/spool/cron/root
echo "0 0 * * * /usr/sbin/logrotate %{appspath}/%{appname}/%{appname}.daily > /dev/null 2>&1" >> /var/spool/cron/root

# grafana日志
echo "remove grafana logrotate cron"
crontab -l | grep -vE "(grafana/grafana.hourly)|(grafana/grafana.daily)" | crontab -

echo "add grafana logrotate cron"
echo "0 1-23 * * * /usr/sbin/logrotate %{appspath}/grafana/grafana.hourly > /dev/null 2>&1" >> /var/spool/cron/root
echo "0 0 * * * /usr/sbin/logrotate %{appspath}/grafana/grafana.daily > /dev/null 2>&1" >> /var/spool/cron/root

###############################################################################
#卸载后执行脚本
%postun


case "$1" in
  0)
    # This is an un-installation.
    # 更新 supervisor 配置
    rm -rf %{appspath}/nginx/conf.d/oplatform.conf
    # 删除nginx配置文件
    rm -rf %{appspath}/nginx/conf.d/%{appname}.conf
    # 更新 supervisor 配置
    rm -fr %{servicepath}/%{appname}.cfg
    # 清除运行残留
    find %{appspath}/%{appname}/ -maxdepth 1 ! -name "*_save" | \
    grep -vw %{appspath}/%{appname}/ | xargs rm -fr
    # 清理logrotate定时任务

    echo "remove ngs-oplatform logrotate cron"
    crontab -l | grep -vE "(%{appname}/%{appname}.hourly)|(%{appname}/%{appname}.daily)" | crontab -
    echo "remove grafana logrotate cron"
    crontab -l | grep -vE "(grafana/grafana.hourly)|(grafana/grafana.daily)" | crontab -
  ;;
  1)
    # This is an upgrade.
    # Do nothing.
  ;;
esac


###############################################################################
# 在事务开始时执行脚本
%pretrans
if [[ $1 == 0 ]];then
    # 备份配置文件目录、本地缓存数据目录
    if [[ -e %{datapath}_save && -d %{datapath} ]];then
        rm -fr %{datapath}_save
    fi
    
    if [[ -e %{configpath}_save && -d %{configpath} ]];then
        rm -fr %{configpath}_save
    fi

    if [[ -d %{datapath} ]];then
        cp -a %{datapath} %{datapath}_save
    fi

    if [[ -d %{configpath} ]];then
        cp -a %{configpath} %{configpath}_save
    fi
fi

###############################################################################
# 在事务结束时执行脚本
%posttrans
if [[ $1 == 0 ]];then
    ln -sf %{toolspath}/python/bin/python* %{appspath}/%{appname}/venv/bin/
    # 使用备份的配置和本地缓存数据
    if [[ -e %{datapath}_save ]];then
        rm -fr %{datapath}
        mv %{datapath}_save %{datapath}
    fi

    if [[ -e %{configpath}_save ]];then
        rm -fr %{configpath}
        mv %{configpath}_save %{configpath}
    fi
    # 创建 supervisor 日志目录
    if [[ ! -x /usr/bin/systemctl && ! -d /opt/ngs/log/supervisor ]];then
        mkdir -p /opt/ngs/log/supervisor
    fi
    # 创建应用日志目录
    if [[ ! -d /opt/ngs/log/%{appname} ]];then
        mkdir -p /opt/ngs/log/%{appname}
    fi
fi

if [[ -x /usr/bin/systemctl ]];then
    /usr/bin/systemctl restart rsyslog
    /usr/bin/systemctl daemon-reload
    /usr/bin/systemctl enable %{appname} grafana 2>&1>>/dev/null
else
    cp %{appspath}/%{appname}/supervisor/%{appname}.cfg %{servicepath}/
    service rsyslog restart
fi

###############################################################################
#清理临时文件
%clean
echo `pwd`"setp clean"
mv %{_topdir}/RPMS/%{arch}/*.rpm  %{pakectpath}/../
###############################################################################
#文件段, 定义软件包要包含的文件
%files
%defattr(-,root,root,-)
%{appspath}/*
%{versionpath}/*
%{systemdpath}
%{rsyslogpath}