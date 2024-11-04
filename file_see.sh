#!/bin/bash

# FileMonitor V1.1
# Author: 7i4n2h3n9
# Team: PolarDay Cyberspace Security LAB

# 生成指定长度的随机字符串
generate_random_str() {
    local length=${1:-16}
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c ${length}
}

# 获取文件列表
get_filelist() {
    local dir=$1
    local file_list=()
    while IFS= read -r -d '' file; do
        file_list+=("$file")
    done < <(find "$dir" -type f -print0)
    echo "${file_list[@]}"
}

# 备份文件
backupfiles() {
    local source_list=("$@")
    local target_dir="./bak"
    if [ -d "$target_dir" ]; then
        echo 'Notice: target_dir is already exist!'
        rm -rf "$target_dir"
        backupfiles "${source_list[@]}"
    else
        mkdir -p "$target_dir"
        echo 'Notice: target_dir created successful!'
        for source in "${source_list[@]}"; do
            target_file_dir="$target_dir/${source#./}"
            mkdir -p "$(dirname "$target_file_dir")"
            cp "$source" "$target_file_dir"
        done
    fi
}

# 检查新文件
check_newfiles() {
    local old_list=("$@")
    local drop_dir="./bak/drop"
    mkdir -p "$drop_dir"
    
    local new_list=($(get_filelist "."))
    for file in "${new_list[@]}"; do
        if [[ ! " ${old_list[@]} " =~ " ${file} " ]]; then
            local tmp_str=$(generate_random_str)
            local tmp_name="${file}.drop${tmp_str}"
            mv "$file" "$tmp_name"
            mv "$tmp_name" "$drop_dir"
        fi
    done
}

# 主程序
main() {
    local path="./"
    local a_list=($(get_filelist "$path"))
    
    backupfiles "${a_list[@]}"

    while true; do
        check_newfiles "${a_list[@]}"
        sleep 2
    done
}

main "$@"
