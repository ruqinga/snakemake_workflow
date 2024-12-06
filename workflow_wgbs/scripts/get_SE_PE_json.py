import os
import json
import glob

def generate_json(fq_dir):
    """
    遍历指定目录生成单端和双端数据的 JSON 数据。
    :param fq_dir: 原始数据目录路径
    :return: single_end_json, paired_end_json
    """
    single_end_array = []
    paired_end_array = []

    # 查找所有 .fastq.gz 文件并排序
    fastq_files = sorted(glob.glob(os.path.join(fq_dir, "*.fastq.gz")))

    for file in fastq_files:
        if "_1.fastq.gz" in file:
            file2 = file.replace("_1.fastq.gz", "_2.fastq.gz")
            if os.path.exists(file2):
                paired_end_array.append({"read1": file, "read2": file2})
            else:
                print(f"Warning: Pair file not found for {file}")
        elif "_2.fastq.gz" in file:
            continue
        else:
            single_end_array.append({"read1": file})

    single_end_json = json.dumps(single_end_array, indent=2)
    paired_end_json = json.dumps(paired_end_array, indent=2)

    return single_end_json, paired_end_json

if __name__ == "__main__":
    import sys

    fq_dir = sys.argv[1] if len(sys.argv) > 1 else "."
    se_json, pe_json = generate_json(fq_dir)
    print("Single End JSON:")
    print(se_json)
    print("Paired End JSON:")
    print(pe_json)


