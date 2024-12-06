#!/bin/bash
# download_sra.sh: 用于处理单端和双端数据并调用 Snakemake 运行流程
# 用法: bash download_sra.sh <work_dir> <fq_dir>

# 如果是sra文件请执行 bash ./scripts/download_sra.sh <srr_list_file>

# 默认工作目录为上一级目录
work_dir="${1:-../}"
echo "工作目录设置为: $work_dir"

# 原始数据目录
fq_dir="${2:-${work_dir}/rawdata}"
echo "原始数据目录: $fq_dir"

# 激活 Snakemake 的 Conda 环境
source ~/.bashrc
conda activate snakemake_env

# 调用脚本生成单端和双端数据列表
bash ./scripts/get_SE_PE_list.sh "$work_dir"

# 检查并显示生成的 JSON 文件
if [[ -f single_end.json ]]; then
    echo "即将处理如下单端数据："
    cat single_end.json
    json_output_se=$(cat single_end.json)
else
    echo "未生成单端数据 JSON"
    json_output_se="[]"
fi

if [[ -f paired_end.json ]]; then
    echo "即将处理如下双端数据："
    cat paired_end.json
    json_output_pe=$(cat paired_end.json)
else
    echo "未生成双端数据 JSON"
    json_output_pe="[]"
fi

# 初次运行时使用 -np 模式进行预览
echo "第一次运行时将使用 -np 选项进行预览，不会实际执行任务。"

# 运行 Snakemake 工作流（双端数据）- 使用 -np 模式
echo "运行 Snakemake 处理双端数据（仅预览）..."
snakemake \
    -np \
    --executor cluster-generic \
    --cluster-generic-submit-cmd 'qsub -q slst_pub -N rna_pe.pbs -l nodes=1:ppn=4' \
    --latency-wait 60 \
    --jobs 4 \
    --use-conda \
    --group-components processing=4 \
    --config fq_dir="$fq_dir" work_dir="$work_dir" \
    --config dt="PE" reads="$json_output_pe"

# 运行 Snakemake 工作流（单端数据）- 使用 -np 模式
echo "运行 Snakemake 处理单端数据（仅预览）..."
snakemake \
    -np \
    --executor cluster-generic \
    --cluster-generic-submit-cmd 'qsub -q slst_pub -N rna_se.pbs -l nodes=1:ppn=4' \
    --latency-wait 60 \
    --jobs 4 \
    --use-conda \
    --group-components processing=4 \
    --config fq_dir="$fq_dir" work_dir="$work_dir" \
    --config dt="SE" reads="$json_output_se"

# 提示用户确认是否继续执行
read -p "是否确认执行任务（实际提交作业）？(y/n): " confirm
if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    echo "确认执行，移除 -np 选项，开始实际执行任务..."

    # 运行 Snakemake 工作流（双端数据）- 移除 -np 选项
    echo "开始处理双端数据..."
    snakemake \
        --executor cluster-generic \
        --cluster-generic-submit-cmd 'qsub -q slst_pub -N rna_pe.pbs -l nodes=1:ppn=4' \
        --latency-wait 60 \
        --jobs 4 \
        --use-conda \
        --group-components processing=4 \
        --config fq_dir="$fq_dir" work_dir="$work_dir" \
        --config dt="PE" reads="$json_output_pe"

    # 运行 Snakemake 工作流（单端数据）- 移除 -np 选项
    echo "开始处理单端数据..."
    snakemake \
        --executor cluster-generic \
        --cluster-generic-submit-cmd 'qsub -q slst_pub -N rna_se.pbs -l nodes=1:ppn=4' \
        --latency-wait 60 \
        --jobs 4 \
        --use-conda \
        --group-components processing=4 \
        --config fq_dir="$fq_dir" work_dir="$work_dir" \
        --config dt="SE" reads="$json_output_se"

    echo "任务已提交！"
else
    echo "任务已取消！"
fi
