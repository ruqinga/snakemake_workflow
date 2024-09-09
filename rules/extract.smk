
rule extract_methylation:
    input:
        deduplicated_bam = lambda wildcards: f"{config['dedu_out']}/{wildcards.sample}_bismark_bt2_pe.deduplicated.bam"
    output:
        cytosine_report = "{extract_out}/{sample}/{sample}_bismark_bt2_pe.deduplicated.bedGraph.gz"
    params:
        genome_folder = config["bismark_index"],
        extract_out = config["extract_out"],
        output_folder="{extract_out}/{sample}"
    shell:
        """
        bismark_methylation_extractor --paired-end --gzip --bedGraph --counts --report --comprehensive --cytosine_report --genome_folder {params.genome_folder} {input.deduplicated_bam} -o {params.output_folder}
        """
