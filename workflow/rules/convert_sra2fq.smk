rule convert_sra2fq:
    input:
        sra_file = lambda wildcards: f"{directories['sra_dir']}/{wildcards.srr}/{wildcards.srr}.sra"
    output:
        fq_file = (
            "{fq_dir}/{sample}.fastq.gz"
            if config["dt"] == "SE"
            else [
                "{fq_dir}/{sample}_1.fastq.gz",
                "{fq_dir}/{sample}_2.fastq.gz"
            ]
)
    conda:
        config["conda_env"]
    params:
        srrid = config["srrid"],
        expected_md5 = config["expected_md5"],
        sra_dir = directories["sra_dir"]
    shell:
        """
        # 重命名 SRA 文件
        mv {input} "{params.sra_dir}/{params.rename}/{params.rename}.sra"
        echo "重命名成功"
        
        # 使用 fasterq-dump 进行解压并输出到指定目录
        fasterq-dump --threads 10 --split-3 --outdir {params.fq_dir} {input.sra_file}
        
        # 压缩生成的 FASTQ 文件
        pigz -p 20 {params.fq_dir}/*.fastq
        """