rule deduplicate_bismark:
    input:
        bam = lambda wildcards: f"{config['bis_out']}/{wildcards.sample}_bismark_bt2_pe.bam"
    output:
        deduplicated_bam="{dedu_out}/{sample}_bismark_bt2_pe.deduplicated.bam"
    params:
        dedu_out=config["dedu_out"]
    shell:
        """
        deduplicate_bismark --bam {input.bam} --output_dir {params.dedu_out}
        """