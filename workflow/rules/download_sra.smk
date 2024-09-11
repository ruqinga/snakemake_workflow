rule download_sra:
    output:
        sra_file="{sra_dir}/{srr}/{srr}.sra"
    params:
        srr = config["srrid"],
        expected_md5 = config["expected_md5"],
        sra_dir = directories["sra_dir"]
    shell:
        """
        # 切换到目标目录
        cd {params.sra_dir} 

        # 使用 prefetch 下载 SRA 文件
        echo -e "\\nDownloading Sra: {params.srr}"
        prefetch --max-size 50G {params.srr} || {{ echo "prefetch 下载失败"; exit 1; }}
        local sra_file="{params.sra_dir}/{params.srr}/{params.srr}.sra"

        # MD5 校验
        calculated_md5=$(md5sum {output} | awk '{{print $1}}')
        if [[ $calculated_md5 != {params.expected_md5} ]]; then
            echo "MD5 校验不匹配，下载可能出错。"
            exit 1
        fi
        echo "MD5 校验通过。"
        """