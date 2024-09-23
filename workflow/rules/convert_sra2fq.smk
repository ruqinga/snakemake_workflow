rule convert_sra2fq:
    output:
        renamed_sra_file = "{sra_dir}/{srrid}/{rename}.sra"
    conda:
        config["conda_env"]
    params:
        sra_dir = directories["sra_dir"],
        fq_dir = config["fq_dir"],
        fq_file= "fq_list.txt"
    shell:
        """
        # 重命名 SRA 文件
        mv "{params.sra_dir}/{wildcards.srrid}/{wildcards.srrid}.sra" "{output.renamed_sra_file}"

        # 使用 fasterq-dump 进行解压并输出到指定目录
        fasterq-dump --threads 5 --split-3 --outdir {params.fq_dir} "{output.renamed_sra_file}"

        # 统计解压后的文件数量 因为不是所有原始sra都会提供测序类型，所以只能根据sra解压得到的fq的数量来判断
        file_count=$(ls "{params.fq_dir}/{wildcards.rename}"*.fastq 2>/dev/null | wc -l)

        if [[ $file_count -eq 2 ]]; then
            echo "双端数据"

            # 压缩
            pigz -p 20 "{params.fq_dir}/{wildcards.rename}_1.fastq"
            pigz -p 20 "{params.fq_dir}/{wildcards.rename}_2.fastq"

            read1="{params.fq_dir}/{wildcards.rename}_1.fastq.gz"
            read2="{params.fq_dir}/{wildcards.rename}_2.fastq.gz"

            # 保存到 fq_list.txt
            echo "PE\t${{read1}}\t${{read2}}" >> {params.fq_dir}/{params.fq_file}

        elif [[ $file_count -eq 1 ]]; then
            echo "单端数据"

            # 压缩
            pigz -p 20 "{params.fq_dir}/{wildcards.rename}.fastq"

            read1="{params.fq_dir}/{wildcards.rename}.fastq.gz"

            # 保存到 fq_list.txt
            echo "SE\t${{read1}}" > {params.fq_dir}/{params.fq_file}

        else
            echo "未检测到 FASTQ 文件。"
            exit 1
        fi
        """



