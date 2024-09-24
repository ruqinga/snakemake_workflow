work_dir=""
fq_dir="${work_dir}/rawdata"

# sra down
metadata=""

export work_dir fq_dir metadata

# 使用方法
source ~/.bashrc
conda activate snakemake_env

sra_download_convert(){
    local srrid="$1"
    local expected_md5="$2"
    local rename="$3"
    local strategy="$4"

    # download
    snakemake --config process="download_sra" sra="[{'srrid': '${srrid}', 'expected_md5': '${expected_md5}'}]"

    # convert to fq.gz
    # 在 cluster 上运行
    snakemake --executor cluster-generic \
        --cluster-generic-submit-cmd 'qsub -q slst_pub -N convert_sra2fq.pbs -l nodes=1:ppn=10' \
        --latency-wait 60 \
        --jobs 2 \
        --use-conda \
        --config process="sra2fq" sra="[{'sraid': '${srrid}', 'rename': '${rename}'}]" work_dir="${work_dir}" fq_dir="${fq_dir}"
}

process_fq(){
    local dt="$1"
    local read1="$2"
    local read2="$3"

    # process wgbs or pbst
    snakemake --forcerun all \
        --executor cluster-generic \
        --cluster-generic-submit-cmd 'qsub -q slst_pub -N wgbs.pbs -l nodes=1:ppn=10 -o ~/snakemake/logs/{wildcards.sample}.out -e ~/snakemake/logs/{wildcards.sample}.err' \
        --latency-wait 60 \
        --jobs 2 \
        --use-conda \
        --group-components processing_group=8 \
        --config reads="[{'read1': '${read1}', 'read2': '${read2}'}]" dt="${dt}" work_dir="${work_dir}" fq_dir="${fq_dir}"
}

parallel --header : --colsep '\t' --link sra_download_convert {srrid} {md5} {sample_title} {strategy} :::: "${metadata}"
parallel --colsep '\t' --link process_fq {1} {2} {3} :::: "${fq_dir}/fq_list.txt"
