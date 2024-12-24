# 基于Snakemake的WGBS数据处理

修改日期：2024.12.24

1. **核心功能**：通过 snakemake 实现了从 `fastq.gz` 到甲基化信息的 wgbs 数据全流程处理，并允许通过修改 config 处理 pbat 数据
2. **sraid 处理**：对于sra数据，在scripts下提供了 `download_sra.sh` 和 `sra2fq.sh` 两个脚本，实现根据sraid下载数据，重命名并解压为fastq.gz

使用方法：

```sh
bash run.sh <work_dir> <fq_dir> -y
```

![image-20241224164713387](https://raw.githubusercontent.com/ruqinga/picture/main/2024/image-20241224164713387.png)

确定没问题则通过nohup提交

```sh
nohup bash run.sh <work_dir> <fq_dir> -y &
```

通过简单三步即可部署成功：

### Step1: install snakemake

使用 conda 或 [mamba](https://github.com/mamba-org/micromamba-releases/releases)（推荐） 安装 snakemake，使 Snakemake 能够处理工作流程的软件依赖 。

1）创建一个新的conda环境并安装snakemake和snakedeploy

```sh
conda create -n snakemake_env -c conda-forge -c bioconda snakemake snakedeploy
# mamba的命令与conda一致，把开头的conda改为mamba就可以了
mamba create -n snakemake_env -c conda-forge -c bioconda snakemake snakedeploy
```

这个命令指定了从 conda-forge 和 bioconda 安装 snakemake

2）激活新创建的环境

```sh
conda activate snakemake_env
```

3）验证 snakemake 的安装。安装完成后你可以通过运行以下命令来检查 snakemake 是否安装正确以及对应的版本号

```sh
snakemake --version
```

4）在8.0版本之后都需要安装 `snakemake-executor-plugin-cluster-generic` 插件用于提交任务到 cluster。 👉[发布的声明](https://snakemake.readthedocs.io/en/stable/getting_started/migration.html#id6)

```shell
pip install snakemake-executor-plugin-cluster-generic
```

### Step2: 下载workflow

从GitHub下载workflow

```sh
git clone https://github.com/ruqinga/snakemake_wgbs
```

其结构如下：

```txt
.
├── config.yaml # <--- 你需要检查的
├── README.md # <--- 使用说明
├── rules # <--- 存放workflow的不同modules，不用修改
│   ├── bismark.smk
│   ├── common.smk
│   ├── cut_bismark.smk
│   ├── deduplicate.smk
│   ├── extract.smk
│   └── trim.smk
├── run.sh # <--- 提交命令的脚本
├── scripts # <--- 存放辅助代码
│   ├── download_sra.sh # <--- 下载并重命名sra
│   └── sra2fq.sh # <--- 解压sra为fastq.gz
└── Snakefile # <--- 流程控制，也需要检查下
```

### Step3: 配置workflow

#### 3.1 配置config.yaml

修改conda环境为你的conda环境名称

```sh
# Environment
conda_env: "base-omics"
```

修改index路径；如果是PBAT则把strategy处改为 `--pbat`

```sh
bismark:
  strategy: "" #--pbat
  params: ""
  index: "/public/slst/home/qushy/toolkit/reference_genome/index/WGBS-index"
```

其它参数可视需求调整

#### 3.2 配置Snakefile

由于zhenglab的WGBS会有额外的接头，所以我单独设置了 cut_bismark，如果不是处理我们自己的数据，需要把这一行注释掉

```sh
#load rules
include: "rules/trim.smk"
include: "rules/cut_bismark.smk" # 处理我们的数据
#include: "rules/bismark.smk" # 处理公开数据
include: "rules/deduplicate.smk" # 去重，无法修改去重阈值
include: "rules/extract.smk" # 提取甲基化信息

```





