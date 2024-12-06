
rule trim:
    input:
        read =  get_fq_list
    output:
        trimmed_read = (
            "{trim_out}/{sample}_trimmed.fastq.gz"
            if config["dt"] == "SE"
            else [
                "{trim_out}/{sample}_1_val_1.fq.gz",
                "{trim_out}/{sample}_2_val_2.fq.gz"
            ]
        )
    conda:
        config["conda_env"]
    group: "processing_group"
    params:
        option = config["trim"]["params"],
        trim_out = directories["trim_out"]
    shell:
        """
        if [ "{config[dt]}" == "SE" ]; then
           trim_galore {params.option} {input.read} -o {params.trim_out}
        else
           trim_galore {params.option} --paired {input.read[0]} {input.read[1]} -o {params.trim_out}
        fi
       """
