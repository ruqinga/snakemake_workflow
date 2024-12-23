# zhenglab 使用的wgbs试剂盒会额外添加一个index，需要在trim之后再删除这个index
rule cut:
    input:
        trimmed_read = get_trimmed_list
    output:
        cutted_read = (
            "{clean_out}/cut/{sample}_trimmed.fq.gz"
            if config["dt"] == "SE"
            else [
                "{clean_out}/cut/{sample}_1_val_1.fq.gz",
                "{clean_out}/cut/{sample}_2_val_2.fq.gz"
            ]
        )
    conda:
        config["conda_env"]
    group: "processing_group"
    params:
        options_pe = config["cutadapt"]["pe"],
        options_se = config["cutadapt"]["se"],
        clean_out = directories["clean_out"]
    shell:
        """
        if [ "{config[dt]}" == "SE" ]; then
            cutadapt {params.options_se} -o {output.cutted_read} {input.trimmed_read}
        else
            cutadapt {params.options_pe} -o {output.cutted_read[0]} -p {output.cutted_read[1]} {input.trimmed_read[0]} {input.trimmed_read[1]}
        fi
        """

rule bismark:
    input:
        cutted_read = get_cutted_list
    output:
        bam = (
            "{bis_out}/{sample}_trimmed_bismark_bt2_se.bam"
            if config["dt"] == "SE"
            else [
                "{bis_out}/{sample}_1_val_1_bismark_bt2_pe.bam"
            ]
        )
    conda:
        config["conda_env"]
    group: "processing_group"
    params:
        option = config["bismark"]["params"],
        genome = config["bismark"]["index"],
        bis_out = directories["bis_out"],
        strategy = config["bismark"]["strategy"]
    shell:
        """
        if [ "{config[dt]}" == "SE" ]; then
            bismark {params.option} {params.strategy} --genome {params.genome} {input.cutted_read} -o {params.bis_out}
        else
            bismark {params.option} {params.strategy} --genome {params.genome} -1 {input.cutted_read[0]} -2 {input.cutted_read[1]} -o {params.bis_out}
        fi

        """
