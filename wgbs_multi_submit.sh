#!/bin/bash

source ~/.bashrc
conda activate base-omics

input="/home_data/home/slst/leixy2023/data/project/DNMT3C/BS/rawdata"
work_dir="/home_data/home/slst/leixy2023/data/project/DNMT3C/BS/240822_repeats"
export work_dir

# Define the maximum number of parallel jobs
parallel_max=3

sra_dir="${work_dir}/sra"
fq_dir="${work_dir}/rawdata"
mkdir -p "${sra_dir}" "${fq_dir}"
export sra_dir fq_dir work_dir parallel_max


# 并发控制函数，确保 wgbs.pbs 的任务数量不超过 max_jobs
my_qsub() {
    while (( $(qstat | grep "wgbs_repeats.pbs" | grep -E " Q | R " | wc -l) >= ${parallel_max} )); do
        sleep 60  # 等待 60 秒后重新检查
    done
    
    echo "提交作业：strategy=$1,read1=$2,read2=$3"
    # 提交作业
    qsub -v strategy=$1,read1=$2,read2=$3 ${work_dir}/wgbs_submit.sh
}

my_bash() {
    nohup bash ${work_dir}/wgbs_submit.sh $1 $2 > ${work_dir}/nohup_wgbs.log
    pid=$!
    wait $pid
}
export -f my_bash

# sra处理函数
download_sra() {
    local srrid=$1
    local expected_md5=$2
    local rename=$3
    local strategy=$4

    # 切换到目标目录
    cd "$sra_dir" || { echo "无法切换到目录 $sra_dir"; return 1; }

    # 使用 prefetch 下载 SRA 文件
    echo -e "Downloading Sra: $srrid\n"
    prefetch --max-size 50G "$srrid" || { echo "prefetch 下载失败"; return 1; }
    local sra_file="${sra_dir}/${srrid}/${srrid}.sra"

    # MD5 校验
    calculated_md5=$(md5sum "$sra_file" | awk '{print $1}')
    if [[ $calculated_md5 != $expected_md5 ]]; then
        echo "MD5 校验和不匹配，下载可能出错。"
        return 1
    fi
    echo "MD5 校验通过。"

    # 重命名 SRA 文件
    mv "${sra_dir}/${srrid}/${srrid}.sra" "${sra_dir}/${srrid}/${rename}.sra" || { echo "重命名失败"; return 1; }
    
    # 解压为 FASTQ 格式
    fasterq-dump --threads 10 --split-3 --outfile "${fq_dir}/${rename}.fastq" "${sra_dir}/${srrid}/${rename}.sra" || { echo "文件 "${sra_dir}/${srrid}/${rename}.sra" 解压失败。"; return 1; }

    echo "文件 "${sra_dir}/${srrid}/${rename}.sra" 解压成功。"

    # 统计解压后的文件数量
    local file_count
    file_count=$(ls "${fq_dir}/${rename}"*.fastq 2>/dev/null | wc -l)
    file_count=2

    if [[ $file_count -eq 2 ]]; then
        echo "双端数据"

        # 压缩
        pigz -p 20 "${fq_dir}/${rename}_1.fastq"
        pigz -p 20 "${fq_dir}/${rename}_2.fastq"

        read1="${fq_dir}/${rename}_1.fastq.gz"
        read2="${fq_dir}/${rename}_2.fastq.gz"

        # 提交pbs任务
        my_qsub "${strategy}" "${read1}" "${read2}"

    elif [[ $file_count -eq 1 ]]; then
        echo "单端数据"

        # 压缩
        pigz -p 20 "${fq_dir}/${rename}.fastq"

        read1="${fq_dir}/${rename}_1.fastq.gz"

        # 提交pbs任务
        my_qsub "${strategy}" "${read1}"

    else
        echo "未检测到 FASTQ 文件。"
        exit 1
    fi
    sleep 6

}



# fq.gz处理函数 默认为wgbs
process_fqgz(){
    fq_dir=$1
    # 创建样本列表
    find "${fq_dir}" -maxdepth 1 -name '*.gz' -exec realpath {} \; | sort > "${fq_dir}/sample_list.txt"

    # 检查文件是双端还是单端
    single_end_files=()
    paired_end_files_1=()
    paired_end_files_2=()

    while IFS= read -r file; do
        base=$(basename "$file")
        if [[ "$base" =~ _R1_001\.(fastq|fq)(\.gz)?$ ]]; then
            paired_file="${file/_R1_001/_R2_001}"
            if [[ -f "$paired_file" ]]; then
                paired_end_files_1+=("$file")
                paired_end_files_2+=("$paired_file")
            else
                single_end_files+=("$file")
            fi
        fi
    done < "${fq_dir}/sample_list.txt"

    echo "Paired end files (1st end):"
    printf '%s\n' "${paired_end_files_1[@]}"

    echo "Paired end files (2nd end):"
    printf '%s\n' "${paired_end_files_2[@]}"

    echo "Single end files:"
    printf '%s\n' "${single_end_files[@]}"

    # 判断并生成样本列表，启动管道
    if [ ${#single_end_files[@]} -gt 0 ]; then
        # 生成单端测序的样本列表
        printf "%s\n" "${single_end_files[@]}" > "${fq_dir}/sample_list_SE.txt"
        # 处理单端测序数据
        parallel -j 4 --link my_qsub "WGBS" {1} :::: "${fq_dir}/sample_list_SE.txt"
    fi

    if [ ${#paired_end_files_1[@]} -gt 0 ]; then
        # 生成双端测序的样本列表，并合并为并行处理的样本列表
        paste <(printf "%s\n" "${paired_end_files_1[@]}") <(printf "%s\n" "${paired_end_files_2[@]}") > "${fq_dir}/sample_list_parallel_PE.txt"
        # 处理双端测序数据
        #parallel -j ${parallel_max} -k --colsep '\t' --link my_qsub "WGBS" {1} {2} :::: "${fq_dir}/sample_list_parallel_PE.txt"
        parallel -j 2 -k --colsep '\t' my_bash {1} {2} :::: "${fq_dir}/sample_list_parallel_PE.txt"
    fi
}


# Check if input is a file or a directory
if [[ -f "${input}" ]]; then
    echo "Input is a SRA list file"

    # 并行下载并处理 SRA 样本 
    # Adjust the concurrency level (-j) as needed, e.g., -j 3 for 3 concurrent jobs
    export -f my_qsub download_sra
    parallel -j ${parallel_max} -k --halt now,fail=1 --header : --colsep '\t' --link download_sra {run_accession} {sra_md5} {sample_title} {strategy} :::: "${input}"
else
    # If input is a directory, set it to fq_dir
    echo "Input is a directory containing fq files"
    fq_dir="${input}"
    
    # Process files in the specified directory
    export -f my_qsub process_fqgz
    process_fqgz "${fq_dir}"
fi

