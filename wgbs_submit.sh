# wgbs.sh
#!/bin/bash

#PBS -N wgbs.pbs
#PBS -l nodes=1:ppn=10
#PBS -S /bin/bash
#PBS -j oe
#PBS -q pub_fast
#PBS -o wgbs_pbs_output.log

#read1=${read1}
#read2=${read2}
#strategy=${strategy}


read1="/home_data/home/slst/leixy2023/data/project/DNMT3C/BS/rawdata/DKO-1rep.fastq.gz"
read2="/home_data/home/slst/leixy2023/data/project/DNMT3C/BS/rawdata/DKO-2rep.fastq.gz"
strategy="WGBS"

#read1=$1
#read2=$2

export strategy

# 检查是否只有一个read文件
if [ -z "$read2" ]; then
    dt="SE"
else
    dt="PE"
fi

echo "strategy: ${strategy}, read1: ${read1}, read2: ${read2}, dt: ${dt}"

# 激活对应环境
source ~/.bashrc
conda activate base-omics

# 有报错立马退出
set -euo pipefail

# pre-defined pipeline configuration parameters
work_dir="/home_data/home/slst/leixy2023/data/project/DNMT3C/BS/240822_repeats"
index_dir="/home_data/home/slst/leixy2023/data/database/mm10_rep/young_repeats"        #"/public/slst/home/qushy/toolkit/reference_genome/index/WGBS-index"
genome_dir="/home_data/home/slst/leixy2023/data/database/mm10_rep/young_repeats/mm_rep_young.fa"
RE_basename=".*BS_|_L00.*" # 会去除前缀BS_和后缀_L00，没有匹配的字符串也能正常运行，输出原名称


export work_dir index_dir genome_dir RE_basename

echo "work_dir: $work_dir"

# 默认输出文件夹
# Default directory format
trim_out="${work_dir}/02_cleandata/trim_galore"
cut_out="${work_dir}/02_cleandata"
bis_out="${work_dir}/03_bismark"
dedu_out="${work_dir}/04_dedu"
extract_out="${work_dir}/05_extract"
log="${work_dir}/log"
export trim_out cut_out bis_out dedu_out extract_out log
mkdir -p "${trim_out}" "${cut_out}" "${bis_out}" "${dedu_out}" "${extract_out}" "${log}"

######### 第一次使用此脚本，请检查上面的默认参数 ############
# define function
# Bismark extraction
extract_with_bismark_PE() {
    local base=$1
    bismark_methylation_extractor --paired-end --gzip --bedGraph --counts --report --comprehensive \
        --genome_folder "${index_dir}" \
        "${dedu_out}/${base}_bismark_bt2_pe.deduplicated.bam" \
        -o "${extract_out}/${base}" >> "${log}/bismark_methylation_extractor.log"
}
extract_with_bismark_SE() {
    local base=$1
    bismark_methylation_extractor --gzip --bedGraph --counts --report --comprehensive \
        --genome_folder "${index_dir}" \
        "${dedu_out}/${base}_bismark_bt2.deduplicated.bam" \
        -o "${extract_out}/${base}" >> "${log}/bismark_methylation_extractor.log"
}

# dnmtools (MethPipe) extraction
extract_with_dnmtools() {
    local base=$1
    # Convert to dnmtools format
    dnmtools format -f bismark "${dedu_out}/${id1}_bismark_bt2_pe.deduplicated.bam" "${dedu_out}/${base}_format.sam"
    # Sort
    samtools sort -O sam -o "${dedu_out}/${base}_format_sort.sam" "${dedu_out}/${base}_format.sam"
    # Extract
    dnmtools counts -c "${genome_dir}" -o "${extract_out}/${base}.meth" "${dedu_out}/${base}_format_sort.sam"
}

my_wgbs_pipeline_PE() {
    # Params
    local read1=$1
    local read2=$2
    local id1=$(basename "${read1}" .fastq.gz)
    local id2=$(basename "${read2}" .fastq.gz)
    local base=$(echo "${id1}" | awk -v re="${RE_basename}" '{gsub(re, ""); print}')

    # Redirect stdout and stderr to ${base}.log
    #exec > "${log}/${base}.log" 2>&1

    # Start time
    echo "WGBS Analysis Pipeline started at $(date)"
    echo -e "read1=${read1}, \nread2=${read2}"

    # 1. Trim + cut
    echo -e "\nStep 1: Trim + cut"
    echo -e "------------------------------------"

    # Trim_galore will add _val_1 and _val_2 suffix to all output files
    echo -e "\ntrim"
    { time (trim_galore --paired "${read1}" "${read2}" -o "${trim_out}" --quality 20 --max_n 4 --length 30 --phred33); } 2>&1 | tee -a "${work_dir}/log/trim_galore.log" | grep -E 'real|user|sys'
    # After bisulfite treatment, there is base imbalance, so an extra index needs to be removed with cutadapt
    echo -e "\ncut"
    { time ( { cutadapt -a GGGGGGGGGGGGX -a AGATCGGAAGAG -A AGATCGGAAGAG -A GGGGGGGGGGGGX -g CTCTTCCGATCT -G CTCTTCCGATCT \
    -n 10 --max-n 0.05 -q 20,20 -u -10 -U 10 -m 30 -e 0.2 \
    -o "${cut_out}/${base}.fq.gz" -p "${cut_out}/${id2}.fq.gz" "${trim_out}/${id1}_val_1.fq.gz" "${trim_out}/${id2}_val_2.fq.gz"; } >> "${log}/cut.log" ); } 

    # 2. Bismark
    echo -e "\nStep 2: Bismark"
    echo -e "------------------------------------"
    echo -e "\nbismark"
   
    if [ "$strategy" = "WGBS" ]; then
        # 运行 bismark 处理 WGBS 数据
        echo "wgbs"
        { time (bismark --genome "${index_dir}" -N 0 -1 "${cut_out}/${base}.fq.gz" -2 "${cut_out}/${id2}.fq.gz" -o "${bis_out}" >> "${log}/bismark.log"); } 2>&1 | tee -a "${log}/bismark.log" | grep -E 'real|user|sys'
    elif [ "$strategy" = "PBAT" ]; then
        # 运行 bismark 处理 PBAT 数据
        { time (bismark --pbat --genome "${index_dir}" -N 0 -1 "${trim_out}/${id1}_val_1.fq.gz" -2 "${trim_out}/${id2}_val_2.fq.gz" -o "${bis_out}" >> "${log}/bismark.log"); } 2>&1 | tee -a "${log}/bismark.log" | grep -E 'real|user|sys'
    else
        echo "unknown sequencing strategy"
        exit 1
    fi

    echo -e "\ndeduplicate_bismark"
    { time (deduplicate_bismark --bam "${bis_out}/${base}_bismark_bt2_pe.bam" --output_dir "${dedu_out}" >> "${log}/deduplicate_bismark.log"); } 2>&1 | tee -a "${log}/deduplicate_bisma
rk.log" | grep -E 'real|user|sys'


    # 3. Extract CpG information
    echo -e "\nStep 3: Extract CpG information"
    echo -e "------------------------------------"
    echo -e "\n------Bismark-----------"
    { time ( { extract_with_bismark_PE "${base}"; } >> "${log}/bismark_methylation_extractor_attend.log"); } 2>&1 | tee -a "${log}/bismark_methylation_extractor_attend.log" | grep -E 'real|user|sys'
    #echo -e "\n------dnmtools-----------"
    #time extract_with_dnmtools "${base}"
 
    # 4. delete 中间文件
    #echo -e "\nStep 4: delete rawdata"
    #rm -r "${trim_out}" "${cut_out}" "${bis_out}"     


    # The pipeline ends here
    echo -e "\nWGBS Analysis Pipeline Completed at $(date)"
}

# SE
my_wgbs_pipeline_SE() {
    # Params
    local read=$1
    local id=$(basename "${read}" .fastq.gz)
    local base=$(echo "${id}" | awk -v re="${RE_basename}" '{gsub(re, ""); print}')

    # Redirect stdout and stderr to ${base}.log
    exec > "${work_dir}/log/${base}.log" 2>&1

    # Start time
    echo "WGBS Analysis Pipeline started at $(date)"
    echo "read=${read}"

    # 1. Trim + cut
    echo -e "\nStep 1: Trim + cut"
    echo -e "------------------------------------"

    # Trim_galore will add _trimmed  to all output files
    echo -e "\ntrim"
    { time (trim_galore "${read}" -o "${trim_out}" --quality 20 --max_n 4 --length 30 --phred33  > /dev/null ); } 2>&1 | tee -a "${work_dir}/log/trim_galore.log" | grep -E 'real|user|sys'

    # After bisulfite treatment, there is base imbalance, so an extra index needs to be removed with cutadapt
    #echo -e "\ncut"
    #{ time ( { cutadapt -a GGGGGGGGGGGGX -a AGATCGGAAGAG -g CTCTTCCGATCT  \
    #-n 10 --max-n 0.05 -q 20 -u -10 -m 30 -e 0.2 \
    #-o "${cut_out}/${base}.fq.gz" "${trim_out}/${id}_trimmed.fq.gz" > "${log}/cut.log" ); } >> "${log}/cut.log" ); } 

    # 2. Bismark
    echo -e "\nStep 2: Bismark"
    echo -e "------------------------------------"
    
    echo -e "\nbismark"
    if [ "$strategy" = "WGBS" ]; then
    	{ time (bismark --genome "${index_dir}" -N 0 "${trim_out}/${id}_trimmed.fq.gz" -o "${bis_out}" >> "${log}/bismark.log"); } 2>&1 | tee -a "${log}/bismark.log" | grep -E 'real|user|sys'
    elif [ "$strategy" = "PBAT" ]; then
        { time (bismark --pbat --genome "${index_dir}" -N 0 "${trim_out}/${id}_trimmed.fq.gz" -o "${bis_out}" >> "${log}/bismark.log"); } 2>&1 | tee -a "${log}/bismark.log" | grep -E 'real|user|sys'
    else
        echo "unknown sequencing strategy, please choose WGBS or PBAT"
        exit 1
    fi
    
    echo -e "\ndeduplicate_bismark"
    { time (deduplicate_bismark --bam "${bis_out}/${base}_bismark_bt2.bam" --output_dir "${dedu_out}" > "${log}/deduplicate_bismark.log"); } 2>&1


    # 3. Extract CpG information
    echo -e "\nStep 3: Extract CpG information"
    echo -e "------------------------------------"
    echo -e "\n------Bismark-----------"
    { time (extract_with_bismark_SE "${base}"); } >> "${log}/bismark_methylation_extractor_attend.log" 2>&1 | tee -a "${log}/bismark_methylation_extractor_attend.log" | grep -E 'real|user|sys'

    #echo -e "\n------dnmtools-----------"
    #time extract_with_dnmtools "${base}"

    # 4. delete 中间文件
    echo -e "\nStep 4: delete rawdata"
    tree -h ${work_dir} > ${log}/file_structure.txt
    rm -r "${trim_out}" "${cut_out}" "${bis_out}"

    # The pipeline ends here
    echo -e "\nWGBS Analysis Pipeline Completed at $(date)"
}


# Start pipeline
if [ "$dt" = "SE" ]; then
    echo "Processing single-end sequencing data..."
        export -f extract_with_bismark_SE my_wgbs_pipeline_SE
        my_wgbs_pipeline_SE "${read1}"
else
    echo "Processing paired-end sequencing data..."
        export -f extract_with_bismark_PE my_wgbs_pipeline_PE
        my_wgbs_pipeline_PE "${read1}" "${read2}"
fi


