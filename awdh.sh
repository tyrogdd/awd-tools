#!/bin/bash

#Author: gdd
#Email: gdd@cumt.edu.cn
#Date: 2024-11-1
#Filename: awdh.sh
#Description: The small script of AWD match

LOG_FILE="./awdh.log"
REQUIRE_FILE='./requirement.yml'
COLOR_WARNING="echo -en \\033[1;33m"
COLOR_SUCCESS="echo -en \\033[1;32m"
COLOR_FAILURE="echo -en \\033[1;31m"
COLOR_NORMAL="echo -en \\033[m"

color () {
    echo -n "$1"
    echo -n "["
    if [ $2 = "success" -o $2 = "0" ]; then
        ${COLOR_SUCCESS}
        echo -n $" OK "    
    elif [ $2 = "failure" -o $2 = "1"  ]; then 
        ${COLOR_FAILURE}
        echo -n $"FAILED"
    elif [ $2 = "normal" -o $2 = "-1"  ]; then 
        ${COLOR_NORMAL}
        echo -n $"INFO"
    else
        ${COLOR_WARNING}
        echo -n $"WARNING"
    fi
    ${COLOR_NORMAL}
    echo -n "]"
    echo
}

logs() {
    time=`date "+%H:%M:%S"`
    echo -en "$time " >> $LOG_FILE
    color "$1" "$2" >> $LOG_FILE
}

readyml() {
    logs "开始读取配置文件" -1
    # REQUIRE_FILE的格式为"database: my_database"
    declare -a params
    count=0
    while IFS=": " read -r key value; do
        ((count++))
        if [[ -z $key ]]; then 
            logs "Used Empty Line $count!" 2
        elif [[ !(-z $key) && -z $value ]]; then
            logs "Value Empty!" 1
            eval "${key}='${value}'"
        else
            logs "Set Success!" 0
            # eval可以全局访问
            eval "${key}='${value}'"
        fi
    done < $REQUIRE_FILE

    # 设置webpath路径规范
    if [ ${webPath:-1} != "/" ]; then
        # webPath=${webPath:0:-1}
        webPath+="/"
    fi

    # echo "All parameters: ${params[@]}"
    # for param in "${params[@]}"; do
    #     echo "$param"   
    # done

    logs "读取配置文件完成" -1
}

getinfo() {
    if [ $1 = "sysi" ]; then
        # 获取系统信息
        systemVerRaw=$(head -n 1 /etc/os-release | cut -d'=' -f2 | tr -d '"')
        case "$systemVerRaw" in
            *"Ubuntu"*)
                systemVersion="Ubuntu"
                ;;
            *"CentOS"*)
                systemVersion="CentOS"
                ;;
            *"Debian"*)
                systemVersion="Debian"
                ;;
            *"Red Hat"*)
                systemVersion="RedHat"
                ;;
            *"Fedora"*)
                systemVersion="Fedora"
                ;;
            *"SUSE"*)
                systemVersion="SUSE"
                ;;
            *)
                systemVersion="Unknown"
                ;;
        esac
        logs "系统发行版为：$systemVersion" -1
    elif [ $1 = "webr" ]; then
        # 获取web服务
        webServices=("httpd" "apache2" "nginx")
        serviceRoot=("/etc/httpd/conf/httpd.conf" "/etc/apache2/sites-available/000-default.conf" "/etc/nginx/sites-available/default")
        pathName=("DocumentRoot" "DocumentRoot" "root")
        finService=""
        for service in "${webServices[@]}"; do
            if which $service &> /dev/null; then
                # webRoot=$(grep -i "^DocumentRoot" /etc/httpd/conf/httpd.conf | awk '{print $2}' | tr -d '"')
                finService=$service
                logs "web服务使用的是: $finService" -1
            fi
        done    
    elif [ $1 = "dbi" ]; then
        # 获取数据库版本
        mysql --version &> /dev/null
        if [ $? -eq 0 ]; then
            if [[ $(mysql --version) == *"Distrib"* ]]; then
                dbVersion=$(mysql --version | sed -n 's/.*Distrib \([0-9]*\.[0-9]*\).*/\1/p')
            else
                dbVersion=$(mysql --version | sed -n 's/.*Ver \([0-9]*\.[0-9]*\).*/\1/p')
            fi
        else
            logs "未安装mysql数据库!" 1 
        fi
        logs "数据库版本为: $dbVersion" -1
    else
        logs "获取信息失败！" 1
    fi
}

backupall() {
    logs "正在进行文件夹备份..." -1
    # 检查是否存在文件夹
    if [ -d $webPath ]; then
        # /var/www/html/*
        tar -zcvf ~/backup.tar.gz "$webPath" &>> $LOG_FILE
        logs "文件夹备份成功！" 0
        echo "文件夹备份成功！"
    elif [ -f $webPath ]; then
        logs "这是一个文件而不是web文件目录!" 2
    else
        logs "web文件目录错误!" 1
    fi
    
    logs "正在进行数据库备份..." -1
    if [ -z "$dbUser" ]; then 
        logs "找不到配置的数据库User信息,默认为root" -1
        dbUser=root
    fi
    if [ -z "$dbPassOld" ]; then 
        logs "找不到配置的数据库密码信息,默认为空" -1
        dbPassOld=""
    fi
    mysqldump -u$dbUser --password="$dbPassOld" --all-databases --skip-lock-tables > ~/backup.sql
    if [ $? -eq 0 ]; then
        logs "数据库备份成功！" 0
        echo "数据库备份成功！"
    else
        logs "数据库备份失败！" 1
    fi
}

changeall() {
    logs "正在用户修改密码..." -1
    # 直接echo输入进去
    echo "$userPass" | passwd $(whoami) --stdin &>> $LOG_FILE
    if [ $? -eq 0 ]; then
        logs "用户密码修改成功！" 0
        echo "用户密码修改成功！"
    else
        logs "用户密码修改失败！" 1
    fi

    # echo $dbVersion
    logs "正在用户修改密码..." -1
    if [ -z "$dbPassOld" ]; then 
        logs "找不到配置的数据库密码信息,默认为空" -1
        dbPassOld=""
    fi
    mysqladmin -u$dbUser -p$dbPassOld password $dbPassNew
    if [ $? -eq 0 ]; then
        logs "用户密码修改成功！" 0
        echo "用户密码修改成功！"
    else
        logs "用户密码修改失败！" 1
    fi
    echo "切记要修改web应用对应的数据库密码!!!"
    logs "切记要修改web应用对应的数据库密码!!!" -1 
}

checkall() {
    logs "正在排查可疑用户..." -1
    # 排查可疑用户
    # 使用awk的-F进行分割，筛选pid大等于1000的用户
    local userList=$(cat /etc/passwd | awk -F ':' '$3 >= 1000 { print $1 }' | tr '\n' ' ')
    logs "可疑用户为：$userList" 1
    echo "可疑用户为：$userList"
    # 排查可疑登录
    local loginW=$(w | awk 'NR > 2 { print $1 "/" $3 }' | sort | uniq)
    if [ $? -eq 0 ]; then
        for login in $loginW; do
            # 用sed替换为空，用#分隔不然/不好分
            # 也可以用cut命令分别赋值
            local user=$(echo "$login" | sed 's#/.*##')
            local from=$(echo "$login" | sed 's#.*/##')
            local evilIP=""
            # 记得修改.yml的白名单
            if [[ "$user" != "root" ]]; then
                for allowIP in $whitelist; do
                    if [[ "$from" != "$allowIP" ]]; then
                        evilIP+="$from "
                    fi
                done
            fi
            if [[ -n "$evilIP" ]]; then
                logs "可疑IP为: $evilIP" 1
                echo "可疑IP为: $evilIP"
            fi
        done
        logs "排查可疑用户成功！" 0
    else
        logs "排查可疑用户修改失败！" 1
    fi
    

    logs "正在排查可疑进程..." -1
    local evilPid=$(ps -aux | awk '$1!="root" {print $1 " " $11}')
    if [[ -n "$evilPid" ]]; then
        logs "可疑进程为:\n$evilPid" -1
        echo -e "可疑进程为:\n$evilPid"
        logs "排查可疑进程成功！" 0
    else
        logs "排查可疑进程失败！" 1
    fi

    logs "正在排查可疑端口..." -1
    local evilPort=$(netstat -tulnp | awk 'NR > 2 {print $4":"$NF}' | awk -F ':' '$2 > 10000 {print $2 " "$3}')
    if [[ -n "$evilPort" ]]; then
        logs "可疑端口为:\n$evilPort" -1
        echo -e "可疑端口为:\n$evilPort"
        logs "排查可疑端口成功！" 0
    else
        logs "排查可疑端口失败！" 1
    fi
}

findevil() {
    # 包括php jsp asp危险函数
    local blacklist=("eval" "exec" "system" "shell_exec" "passthru" "proc_open" "popen" "curl_exec" "curl_multi_exec" "assert" "include" "include_once" "require" "require_once" "register_globals" "magic_quotes_gpc" "filter_input" 
               "Runtime.getRuntime().exec" "ProcessBuilder" "System.exec" "getClass().getClassLoader().getResourceAsStream" "getResource" 
               "Execute" "Eval" "Server.Execute" "Response.Write" "Response.Redirect" "Request.ServerVariables" "Server.CreateObject" 
               "preg_replace('/.*$/e" "base64_decode")
    local isBlack=false
    for func in "${blacklist[@]}"; do
        local evilFunc=$(grep -rn "$func" "$webPath")
        if [[ -n "$evilFunc" ]]; then
            isBlack=true
            logs "危险函数为:\n$evilFunc" -1
            echo -e "危险函数为:\n$evilFunc"
            logs "查找危险函数成功！" 0
        fi
    done
    if [[ "$isBlack" = "false" ]]; then
        logs "查找危险函数失败！" 1
    fi
}

# 生成指定长度的随机字符串
random_string() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c ${length}
}

defence() {
    case $1 in
        bak )
            logs "开始备份" -1
            backupall
            logs "备份完成" -1
            ;;
        cha )
            logs "开始修改" -1
            changeall
            logs "修改完成" -1
            ;;
        cek )
            logs "开始检查" -1
            checkall
            logs "检查完成" -1
            ;;
        fe )
            logs "开始查找" -1
            findevil
            logs "查找完成" -1
            ;;
        help )
            echo -e "Usage: [OPTION]... \n \
            bak   备份web目录和数据库文件   \n \
            chp   修改系统密码和数据库密码   \n \
            cek   排查可疑选项              \n \
            fe    查找危险漏洞              \n \
            "
            ;;
        * ) 
            echo -e "Usage: [OPTION]... \n \
            bak   备份web目录和数据库文件   \n \
            chp   修改系统密码和数据库密码   \n \
            cek   排查可疑选项              \n \
            fe    查找危险漏洞              \n \
            "
            ;;
    esac
}

killtorjan() {
    # serUser=""
    # if [[ $finService = "nginx" ]]; then
    #     serUser="www-data"
    # elif [[ $finService = "apache2" ]]; then
    #     serUser="apache"
    # elif [[ $finService = "httpd" ]]; then
    #     serUser="httpd"
    # fi

    echo "<?php system('whoami');" > "$webPath/.conf.php"
    local serUser=$(curl -s "http://127.0.0.1/.conf.php")
    logs "web服务用户名为: $serUser" 0

    kill $(ps -aux | grep "$serUser" | awk '{print $2}' | xargs kill -9) &>> $LOG_FILE
    # 防止给的用户权限不够，再用www-data权限去执行
    echo "<?php system('kill $(ps -aux | grep "$serUser" | awk '{print $2}' | xargs kill -9)');" > "$webPath/.conf.php"
    curl "http://127.0.0.1/.conf.php" &>> $LOG_FILE
    if [[ -z $(ps -aux | grep "$serUser") ]]; then
        logs "克制不死马成功！" 0
        echo "克制不死马成功！" 
    else
        logs "克制不死马失败！" 1
    fi
}

args1=$1
args2=$2

logs "---------- Start ----------" -1
readyml
getinfo "sysi"
getinfo "webr"
getinfo "dbi"

case $args1 in 
    de ) 
        defence $args2
        ;;
    mon )
        monitor $args2
        ;;
    kt )
        killtorjan $args2
        ;;
    help )
        echo -e "Usage: [OPTION]... \n \
        de   加固相关 \n \
        mon  文件监控 \n \
        dnd  克制不死马 \n \
        "
        ;;
    * )
        echo -e "Usage: [OPTION]... \n \
        de   加固相关 \n \
        mon  文件监控 \n \
        dnd  克制不死马 \n \
        "
        ;;
esac

# sleep 2
logs "========== End ==========" -1
