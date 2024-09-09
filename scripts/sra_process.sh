sra_dir="${work_dir}/sra"
fq_dir="${work_dir}/rawdata"

sra_download(){
    local srrid=$1
    local expected_md5=$2
    local rename=$3

    # 切换到目标目录
    cd "$sra_dir" || { echo "无法切换到目录 $sra_dir"; return 1; }

    # 使用 prefetch 下载 SRA 文件
    echo -e "\nDownloading Sra: $srrid"
    prefetch --max-size 50G "$srrid" || { echo "prefetch 下载失败"; return 1; }
    local sra_file="${sra_dir}/${srrid}/${srrid}.sra"

    # MD5 校验
    calculated_md5=$(md5sum "$sra_file" | awk '{print $1}')
    if [[ $calculated_md5 != $expected_md5 ]]; then
        echo "MD5 校验不匹配，下载可能出错。"
        return 1
    fi
    echo "MD5 校验通过。"

    # 重命名 SRA 文件
    mv "${sra_dir}/${srrid}/${srrid}.sra" "${sra_dir}/${rename}/${rename}.sra"
    echo "重命名成功"

}

sra_process() {
  local srrid=$1
  local expected_md5=$2
  local rename=$3
  local strategy=$4

  # download sra
  sra_download $srrid $expected_md5 $rename

  # 解压为 FASTQ 格式
  fasterq-dump --threads 10 --split-3 --outfile "${fq_dir}/${rename}.fastq" "${sra_dir}/${rename}/${rename}.sra"
  echo "文件 "${sra_dir}/${rename}/${rename}.sra" 解压成功。"

  # 统计解压后的文件数量
  local file_count
  file_count=$(ls "${fq_dir}/${rename}"*.fastq 2>/dev/null | wc -l)

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
      snakemake -s Snakefile --configfile config.yaml  strategy read1
      my_qsub "${strategy}" "${read1}"

  else
      echo "未检测到 FASTQ 文件。"
      exit 1
  fi

}