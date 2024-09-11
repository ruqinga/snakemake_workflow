reads = config["reads"]

# 获取输入文件的basename（不带路径和扩展名）
def get_sample_name(filepath):
    return filepath.split("/")[-1].replace("_1.fastq.gz", "").replace("_2.fastq.gz", "")

rule trim_reads_pe:
    input:
        read1=lambda wildcards: next(
            read["read1"] for read in reads if get_sample_name(read["read1"]) == wildcards.sample),
        read2=lambda wildcards: next(
            read["read2"] for read in reads if get_sample_name(read["read2"]) == wildcards.sample)
    output:
        trimmed_read1="{trim_out}/{sample}_1_val_1.fq.gz",
        trimmed_read2="{trim_out}/{sample}_2_val_2.fq.gz"
    params:
        fq_dir = config["fq_dir"],
        trim_params = config["trim_params"],
        trim_out = config["trim_out"]
    shell:
        """
        trim_galore --paired {input.read1} {input.read2} -o {params.trim_out} {params.trim_params}
        """
