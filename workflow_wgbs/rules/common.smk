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
    try:
        dt = config.get("dt")
        if dt == "PE":
            return filepath.split("/")[-1].replace("_1.fastq.gz", "").replace("_2.fastq.gz", "")
        elif dt == "SE":
            return filepath.split("/")[-1].replace(".fastq.gz", "")
        else:
            raise ValueError(f"Unsupported 'dt': {dt}")
    except Exception as e:
        raise ValueError(f"Error in get_sample_name for {filepath}: {e}")


# Create input file list based on configuration
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

def get_dedu_out(wildcards):
    if config["dt"] == "SE":
        return f"{directories['dedu_out']}/{wildcards.sample}_trimmed_bismark_bt2_se.deduplicated.bam"
    elif config["dt"] == "PE":
        return f"{directories['dedu_out']}/{wildcards.sample}_1_val_1_bismark_bt2_pe.deduplicated.bam"
    else:
        raise ValueError(f"Invalid 'dt' configuration: {config['dt']}")