#!/bin/bash
# get_SE_PE_list.sh
# 用法: bash get_SE_PE_list.sh <work_dir>

work_dir="${1:-.}"  # 如果未提供参数，默认为当前目录

# 初始化 JSON 数组
single_end_array=()
paired_end_array=()

# 遍历所有 .fastq.gz 文件
for file in $(find "$work_dir" -name "*.fastq.gz" | sort); do
    if [[ "$file" =~ _1\.fastq\.gz$ ]]; then
        # 匹配 _1 文件并查找相应的 _2 文件
        file2="${file/_1.fastq.gz/_2.fastq.gz}"
        if [ -f "$file2" ]; then
            json_entry="{\"read1\": \"$file\", \"read2\": \"$file2\"}"
            paired_end_array+=("$json_entry")
        else
            echo "警告: 找不到 $file2，跳过"
        fi
    elif [[ "$file" =~ _2\.fastq\.gz$ ]]; then
        continue
    else
        json_entry="{\"read\": \"$file\"}"
        single_end_array+=("$json_entry")
    fi
done

# 转换数组为 JSON 格式
single_end_json=$(IFS=,; echo "[${single_end_array[*]}]")
paired_end_json=$(IFS=,; echo "[${paired_end_array[*]}]")

# 输出 JSON
echo "$single_end_json" > single_end.json
echo "$paired_end_json" > paired_end.json

echo "生成完成"
#echo "- 单端数据: single_end.json"
#echo "- 双端数据: paired_end.json"
