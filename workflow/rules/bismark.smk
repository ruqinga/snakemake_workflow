
rule bismark:
    input:
        trimmed_read1=lambda wildcards: f"{config['trim_out']}/{wildcards.sample}_1_val_1.fq.gz",
        trimmed_read2=lambda wildcards: f"{config['trim_out']}/{wildcards.sample}_2_val_2.fq.gz"
    output:
        bam = "{bis_out}/{sample}_bismark_bt2_pe.bam"
    params:
        genome = config["bismark_index"],
        bis_out = config["bis_out"],
        strategy = config["strategy"]
    shell:
        """
        if [ "{params.strategy}" = "WGBS" ]; then
            echo "bismark wgbs"
            bismark --genome {params.genome} -1 {input.trimmed_read1} -2 {input.trimmed_read1} -o {params.bis_out}
        elif [ "{params.strategy}" = "PBAT" ]; then
            echo "bismark pbat"
            bismark --pbat --genome {params.genome} -1 {input.trimmed_read1} -2 {input.trimmed_read1} -o {params.bis_out}
        fi
        """
