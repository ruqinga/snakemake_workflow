rule cut:
    input:
        trimmed_read1 = lambda wildcards: f"{config['trim_out']}/{wildcards.sample}_1_val_1.fq.gz",
        trimmed_read2 = lambda wildcards: f"{config['trim_out']}/{wildcards.sample}_2_val_2.fq.gz"
    output:
        cutted_read1 = "{cut_out}/{sample}_1.fq.gz",
        cutted_read2 = "{cut_out}/{sample}_2.fq.gz"
    params:
        cutadapt_params = config["cutadapt_params"],
        cut_out = config["cut_out"]
    shell:
        """
        cutadapt {params.cutadapt_params} -o {output.cutted_read1} -p {output.cutted_read2} {input.trimmed_read1} {input.trimmed_read2}
        """

rule bismark:
    input:
        cutted_read1 = lambda wildcards: f"{config['cut_out']}/{wildcards.sample}_1.fq.gz",
        cutted_read2 = lambda wildcards: f"{config['cut_out']}/{wildcards.sample}_2.fq.gz"
    output:
        bam = "{bis_out}/{sample}_bismark_bt2_pe.bam"
    params:
        genome = config["bismark_index"],
        bis_out = config["directories"]["bis_out"],
        strategy = config["strategy"]
    shell:
        """
        if [ "{params.strategy}" = "WGBS" ]; then
            echo "bismark wgbs"
            bismark --genome {params.genome} -1 {input.cutted_read1} -2 {input.cutted_read2} -o {params.bis_out}
        elif [ "{params.strategy}" = "PBAT" ]; then
            echo "bismark pbat"
            bismark --pbat --genome {params.genome} -1 {input.cutted_read1} -2 {input.cutted_read2} -o {params.bis_out}
        fi
        """