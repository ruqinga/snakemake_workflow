def get_directories(config):
    """
    根据配置文件中的 work_dir 和目录结构返回所有目录的路径。
    """
    work_dir = config["work_dir"]

    # 使用 Python 字符串格式化来获取目录
    directories = {
        "sra_dir": config["directories"]["sra_dir"].format(work_dir=work_dir),
        "trim_out": config["directories"]["trim_out"].format(work_dir=work_dir),
        "clean_out": config["directories"]["clean_out"].format(work_dir=work_dir),
        "bis_out": config["directories"]["bis_out"].format(work_dir=work_dir),
        "dedu_out": config["directories"]["dedu_out"].format(work_dir=work_dir),
        "extract_out": config["directories"]["extract_out"].format(work_dir=work_dir),
        "log_out": config["directories"]["log_out"].format(work_dir=work_dir),
    }

    return directories

# 获取输入文件的basename（不带路径和扩展名）
def get_sample_name(filepath):
    return filepath.split("/")[-1].replace("_1.fastq.gz", "").replace("_2.fastq.gz", "")

def get_all(directories, config):
    results = []

    # Handle different processing steps based on the "process" key in the config
    if config["process"] == "download_sra":
        results = expand("{sra_dir}/{srr}/{srr}.sra",
            sra_dir=directories["sra_dir"],
            srr=[entry["srrid"] for entry in config["sra"]])

    elif config["process"] == "sra2fq":
        samples = {sample["srrid"]: sample["rename"] for sample in config["sra"]}
        results = expand("{sra_dir}/{srrid}/{rename}.sra",
            sra_dir=directories["sra_dir"],
            srrid=samples.keys(),
            rename=samples.values())

    elif config["process"] == "wgbs":
        reads = config.get("reads", [])
        # Extract unique sample names from the "reads" list
        samples = set(get_sample_name(read["read1"]) for read in reads)

        results = expand(
            "{extract_out}/{sample}/{sample}_1_val_1_bismark_bt2_pe.deduplicated.bedGraph.gz",
            extract_out=directories["extract_out"],
            sample=samples
        )

    return results
    # return expand(
    #     "{dedu_out}/{sample}_1_val_1_bismark_bt2_pe.deduplicated.bam",
    #     dedu_out=directories["dedu_out"], sample=samples
    # )


# Create input file list based on configuration
def get_srr_by_rename(rename, sra_dir, config):
    try:
        srrid = next(entry['srrid'] for entry in config['sra'] if entry.get('rename','') == rename)
        return f"{sra_dir}/{srrid}/{srrid}.txt"
    except StopIteration:
        raise ValueError(f"Could not find a matching SRA file for rename: {rename}")

def get_fq_list(wildcards):
    if config["dt"] == "SE":
        return f"{config['fq_dir']}/{wildcards.sample}.fastq.gz"
    elif config["dt"] == "PE":
        return [
            f"{config['fq_dir']}/{wildcards.sample}_1.fastq.gz",
            f"{config['fq_dir']}/{wildcards.sample}_2.fastq.gz"
        ]
    else:
        raise ValueError(f"Invalid 'dt' configuration: {config['dt']}")

def get_trimmed_list(wildcards):
    if config["dt"] == "SE":
        return f"{directories['trim_out']}/{wildcards.sample}_trimmed.fq.gz"
    elif config["dt"] == "PE":
        return [
            f"{directories['trim_out']}/{wildcards.sample}_1_val_1.fq.gz",
            f"{directories['trim_out']}/{wildcards.sample}_2_val_2.fq.gz"
        ]
    else:
        raise ValueError(f"Invalid 'dt' configuration: {config['dt']}")

def get_cutted_list(wildcards):
    if config["dt"] == "SE":
        return f"{directories['cut_out']}/{wildcards.sample}.fq.gz"
    elif config["dt"] == "PE":
        return [
            f"{directories['cut_out']}/{wildcards.sample}_1.fq.gz",
            f"{directories['cut_out']}/{wildcards.sample}_1.fq.gz"
        ]
    else:
        raise ValueError(f"Invalid 'dt' configuration: {config['dt']}")

def get_bismark_out(wildcards):
    if config["dt"] == "SE":
        return f"{directories['bis_out']}/{wildcards.sample}_trimmed_bismark_bt2_se.bam"
    elif config["dt"] == "PE":
        return f"{directories['bis_out']}/{wildcards.sample}_1_val_1_bismark_bt2_pe.bam"
    else:
        raise ValueError(f"Invalid 'dt' configuration: {config['dt']}")

# def get_dedu_out(wildcards):
#     if config["dt"] == "SE":
#         return f"{directories['dedu_out']}/{wildcards.sample}_trimmed_bismark_bt2_se.deduplicated.bam"
#     else:
#         return f"{directories['dedu_out']}/{wildcards.sample}_1_val_1_bismark_bt2_pe.deduplicated.bam"

def get_dedu_out(wildcards):
    if config["dt"] == "SE":
        return f"{directories['dedu_out']}/{wildcards.sample}_trimmed_bismark_bt2_se.deduplicated.bam"
    elif config["dt"] == "PE":
        return f"{directories['dedu_out']}/{wildcards.sample}_1_val_1_bismark_bt2_pe.deduplicated.bam"
    else:
        raise ValueError(f"Invalid 'dt' configuration: {config['dt']}")