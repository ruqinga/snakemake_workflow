configfile: "config.yaml"

# 加载规则
include: "rules/trim.smk"
include: "rules/bismark.smk"
#include: "rules/cut_bismark.smk"
include: "rules/deduplicate.smk"
include: "rules/extract.smk"
