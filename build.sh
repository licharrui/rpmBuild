#!/bin/bash

set -e

source ./build_tools.sh

# 常量定义
APP_NAME='ngs-oplatform'
VENV_PATH=${APPS_PATH}/${APP_NAME}/${VENV_NAME}
GRAFANA_PACKAGE="http://192.168.254.75:8081/api/public/dl/KRosj0kr/grafana/grafana-10.2.6.linux-amd64.tar.gz"


function copy_files() {
    cd "${WORK_ROOT}"
    mkdir -p "${DIST_PATH}"/${APP_NAME}
    # curl -s http://192.168.254.75/resource/scripts/boyun_local_yum.sh | sh
    # 安装uwsgi编译需要的libyaml开发库, 第三方库，官方镜像中没有
    yum install -y libyaml libyaml-devel
    # 重新编译uwsgi，加入libyaml库，uwsgi自带的yaml解析库无法识别可重复参数。
    pip uninstall -y uwsgi
    if [[ ${ID} == "CentOS" ]];then
        CFLAGS="-I/opt/ngs/tools/openssl/include" LDFLAGS="-L/opt/ngs/tools/openssl/lib" UWSGI_PROFILE_OVERRIDE=yaml=libyaml ${PIP_CMD} uwsgi==2.0.23
    else
        UWSGI_PROFILE_OVERRIDE=yaml=libyaml ${PIP_CMD} uwsgi==2.0.23
    fi
    cp "${APPS_PATH}"/${APP_NAME}/venv/bin/uwsgi "${DIST_PATH}"/${APP_NAME}/ngs-oplatform
    
    chmod 777 "${DIST_PATH}"/${APP_NAME}/ngs-oplatform
    
    # 复制虚拟环境
    cp -r "${APPS_PATH}"/${APP_NAME}/venv "${DIST_PATH}"/${APP_NAME}/
    
    # 复制程序文件
    cp -r apps/               "${DIST_PATH}"/${APP_NAME}
    cp -r initial_data/       "${DIST_PATH}"/${APP_NAME}
    cp -r oplatform/          "${DIST_PATH}"/${APP_NAME}
    cp -r utils/              "${DIST_PATH}"/${APP_NAME}
    cp -r version_migrations  "${DIST_PATH}"/${APP_NAME}
    cp -r static              "${DIST_PATH}"/${APP_NAME}
    cp ./*.py                 "${DIST_PATH}"/${APP_NAME}
    
    mkdir -p                  "${DIST_PATH}"/${APP_NAME}/configs
    # 只复制配置文件模板
    cp ./*.tpl.yaml           "${DIST_PATH}"/${APP_NAME}/
    # 复制 supervisor 配置文件
    cp -r supervisor          ${DIST_PATH}/${APP_NAME}/
    
    # grafana config
    cp ./defaults.tpl.ini     ${DIST_PATH}/${APP_NAME}/
    wget ${GRAFANA_PACKAGE} -O grafana.tar.gz
    mkdir -p ${DIST_PATH}/grafana/grafana
    tar -zxvf grafana.tar.gz -C ${DIST_PATH}/grafana/grafana
    rm -f ${DIST_PATH}/grafana/grafana/conf/defaults.ini
    rm -fr grafana.tar.gz
    # grafana 插件
    wget http://192.168.254.75:8081/api/public/dl/KRosj0kr/grafana/agenty-flowcharting-panel-1.0.0e.zip -O agenty-flowcharting-panel.zip
    unzip agenty-flowcharting-panel.zip -d agenty-flowcharting-panel
    mv agenty-flowcharting-panel/ ${DIST_PATH}/grafana/
    rm -fr agenty-flowcharting-panel.zip

    wget http://192.168.254.75:8081/api/public/dl/KRosj0kr/grafana/ngs-variable-panel-2.3.2.zip -O ngs-variable-panel.zip
    unzip ngs-variable-panel.zip -d ngs-variable-panel
    mv ngs-variable-panel/ ${DIST_PATH}/grafana/
    rm -fr ngs-variable-panel.zip

    wget http://192.168.254.75:8081/api/public/dl/KRosj0kr/grafana/ngs-grafanaantv6-panel-1.0.0.zip -O ngs-grafanaantv6-panel.zip
    unzip ngs-grafanaantv6-panel.zip -d ngs-grafanaantv6-panel
    mv ngs-grafanaantv6-panel/ ${DIST_PATH}/grafana/
    rm -fr ngs-grafanaantv6-panel.zip

    wget http://192.168.254.75:8081/api/public/dl/KRosj0kr/grafana/marcusolsson-json-datasource-1.3.9.zip -O marcusolsson-json-datasource.zip
    unzip marcusolsson-json-datasource.zip -d marcusolsson-json-datasource
    mv marcusolsson-json-datasource/ ${DIST_PATH}/grafana/
    rm -fr marcusolsson-json-datasource.zip
}

main "$@"
