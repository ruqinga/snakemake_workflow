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
bash ./scripts/get_SE_PE_list.sh "$work_dir"

# 初始化变量以记录是否需要运行单端或双端数据
run_pe=false
run_se=false

# 检查并显示生成的 JSON 文件
if [[ -f paired_end.json && -s paired_end.json ]]; then
    echo "即将处理如下双端数据："
    cat paired_end.json
    json_output_pe=$(cat paired_end.json)
    run_pe=true
else
    echo "未检测到双端数据或文件为空"
    json_output_pe="[]"
fi

if [[ -f single_end.json && -s single_end.json ]]; then
    echo "即将处理如下单端数据："
    cat single_end.json
    json_output_se=$(cat single_end.json)
    run_se=true
else
    echo "未检测到单端数据或文件为空"
    json_output_se="[]"
fi

# 提示是否确认执行任务
read -p "是否确认运行 Snakemake 流程（预览模式）？(y/n): " confirm_preview
if [[ "$confirm_preview" != "y" && "$confirm_preview" != "Y" ]]; then
    echo "任务已取消！"
    exit 0
fi

# 运行 Snakemake 工作流（预览模式）
if [[ "$run_pe" == true ]]; then
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

if [[ "$run_se" == true ]]; then
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
if [[ "$run_pe" == true ]]; then
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

if [[ "$run_se" == true ]]; then
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
