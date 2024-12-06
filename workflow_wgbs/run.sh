#!/bin/bash
# download_sra.sh: 用于处理单端和双端数据并调用 Snakemake 运行流程
# 用法: bash download_sra.sh <work_dir> <fq_dir>

# 默认工作目录为上一级目录
work_dir="${1:-../}"
echo "工作目录设置为: $work_dir"

# 默认fq目录为工作目录下的01_rawdata目录
fq_dir="${2:-${work_dir}/01_rawdata}"
echo "原始数据目录: $fq_dir"

# 激活 Snakemake 的 Conda 环境
source ~/.bashrc
conda activate snakemake_env

# 调用脚本生成单端和双端数据列表
json_output_se=$(python ./scripts/generate_json.py "$fq_dir" | awk '/^Single End JSON:/ {flag=1; next} /^Paired End JSON:/ {flag=0} flag {print}')
json_output_pe=$(python ./scripts/generate_json.py "$fq_dir" | awk '/^Paired End JSON:/ {flag=1; next} flag {print}')

# 检查 JSON 数据是否为空并输出相应的提示信息
if [[ -z "$json_output_se" || "$json_output_se" == "[]" ]]; then
    echo "没有单端数据"
    json_output_se=""
else
    echo "即将处理如下单端数据:"
    echo "$json_output_se"
fi

if [[ -z "$json_output_pe" || "$json_output_pe" == "[]" ]]; then
    echo "没有双端数据"
    json_output_pe=""
else
    echo "即将处理如下双端数据:"
    echo "$json_output_pe"
fi


# 运行 Snakemake 工作流（预览模式）
if [[ -n "$json_output_pe" ]]; then
    echo "运行 Snakemake 处理双端数据（仅预览）..."
    snakemake \
        -np \
        --executor cluster-generic \
        --cluster-generic-submit-cmd 'qsub -q slst_pub -N rna_pe.pbs -l nodes=1:ppn=4' \
        --latency-wait 60 \
        --jobs 4 \
        --use-conda \
        --group-components processing=4 \
        --config fq_dir="$fq_dir" work_dir="$work_dir" dt="PE" reads="$json_output_pe"
fi

if [[ -n "$json_output_se" ]]; then
    echo "运行 Snakemake 处理单端数据（仅预览）..."
    snakemake \
        -np \
        --executor cluster-generic \
        --cluster-generic-submit-cmd 'qsub -q slst_pub -N rna_se.pbs -l nodes=1:ppn=4' \
        --latency-wait 60 \
        --jobs 4 \
        --use-conda \
        --group-components processing=4 \
        --config fq_dir="$fq_dir" work_dir="$work_dir" dt="SE" reads="$json_output_se"
fi

# 提示是否确认实际执行任务
read -p "是否确认执行任务（实际提交作业）？(y/n): " confirm_run
if [[ "$confirm_run" != "y" && "$confirm_run" != "Y" ]]; then
    echo "任务已取消！"
    exit 0
fi

# 实际运行 Snakemake 工作流
if [[ -n "$json_output_pe" ]]; then
    echo "开始处理双端数据..."
    snakemake \
        --executor cluster-generic \
        --cluster-generic-submit-cmd 'qsub -q slst_pub -N rna_pe.pbs -l nodes=1:ppn=4' \
        --latency-wait 60 \
        --jobs 4 \
        --use-conda \
        --group-components processing=4 \
        --config fq_dir="$fq_dir" work_dir="$work_dir" dt="PE" reads="$json_output_pe"
fi

if [[ -n "$json_output_se" ]]; then
    echo "开始处理单端数据..."
    snakemake \
        --executor cluster-generic \
        --cluster-generic-submit-cmd 'qsub -q slst_pub -N rna_se.pbs -l nodes=1:ppn=4' \
        --latency-wait 60 \
        --jobs 4 \
        --use-conda \
        --group-components processing=4 \
        --config fq_dir="$fq_dir" work_dir="$work_dir" dt="SE" reads="$json_output_se"
fi

echo "任务已完成！"
