
VERSION="0.1"

configfile: "cfg/config.yaml"
cluster = json.load(open("cfg/cluster.json"))

import yaml
samples = yaml.load(open("cfg/config.yaml"))

# NOTE: no mitochondria MT because they aren't in our exome
GATK_CHROMOSOMES=('1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21', '22', 'X', 'Y')

### helper functions ###
def read_group(wildcards):
  '''
    determine read group from sample name
  '''
  # in/0656045001_BC_H5CNYDSXX_GTGTTCTA_L004_R1.fastq.gz
  # 0757079003_T_A_H5CNYDSXX_ACGTATCA_L004_R1.fastq.gz
  suffix = config["samples"][wildcards.sample][0].replace("in/{}_".format(wildcards.sample), "") # in/S1_RG_2_R1.fastq.gz
  fields = suffix.split("_") # H5CNYDSXX_GTGTTCTA_L004_R1
  flowcell = fields[0]
  barcode = fields[1]
  lane = fields[2]
  return "@RG\tID:{sample}.{flowcell}.{barcode}.{lane}\tSM:{sample}\tPU:{flowcell}.{barcode}.{lane}\tPL:Illumina".format(flowcell=flowcell, sample=wildcards.sample, lane=lane, barcode=barcode)

def tumour_germline_dup_bams(wildcards):
  tumour_bam = 'out/{}.sorted.dups.bam'.format(wildcards.tumour)
  normal_bam = 'out/{}.sorted.dups.bam'.format(config["tumours"][wildcards.tumour])
  return [tumour_bam, normal_bam]

def tumour_germline_bams(wildcards):
  tumour_bam = 'out/{}.sorted.dups.bam'.format(wildcards.tumour)
  normal_bam = 'out/{}.sorted.dups.bam'.format(config["tumours"][wildcards.tumour])
  return [tumour_bam, normal_bam]

def germline_samples():
  samples = set(config['samples'])
  tumours = set(config['tumours'])
  return list(samples.difference(tumours))

def germline_sample(wildcards):
  return config["tumours"][wildcards.tumour]

### final outputs ###
rule all:
  input:
    expand("out/vardict/{tumour}.vardict.vcf", tumour=config['tumours']),
    expand("out/{tumour}.strelka.somatic.snvs.af.dp.filtered.vep.vcf.gz", tumour=config['tumours']), # somatic snvs strelka
    expand("out/{tumour}.strelka.somatic.indels.af.dp.filtered.vep.vcf.gz", tumour=config['tumours']), # somatic indels strelka
    expand("out/{sample}.oxo_metrics.txt", sample=config['samples']),
    expand("out/{sample}.artifact_metrics.txt.error_summary_metrics", sample=config['samples']),
    expand("out/{tumour}.mutect2.filter.bias.vcf.gz", tumour=config['tumours']), # somatic mutect2 with dkfz bias annotation
    expand("out/{sample}.hc.gt.indels.vcf.gz", sample=config['samples']),
    expand("out/fastqc/{sample}/completed", sample=config['samples']), # fastqc
    expand("out/mosdepth/{sample}.mosdepth.completed", sample=config['samples']), # mosdepth
    expand("out/mosdepth_exons/{sample}.mosdepth.completed", sample=config['samples']), # mosdepth
    expand("out/peddy/peddy.completed"), # mosdepth
    expand("out/{sample}.metrics.insertsize", sample=config['samples']),
    expand("out/{sample}.metrics.alignment", sample=config['samples']),
    expand("out/{sample}.metrics.target", sample=config['samples']),
    expand("out/{tumour}.mutect2.filter.norm.af.dp.filter.vep.vcf.gz", tumour=config['tumours']),
    expand("out/{tumour}.loh.bed", tumour=samples['tumours']), # loh regions

    expand("tmp/{tumour}.intersect.vep.vcf", tumour=config['tumours']),
    expand("out/mafs/{tumour}.intersect.maf", tumour=config['tumours']),
    expand("out/mafs/{tumour}.intersect.mmr.maf", tumour=config['tumours']),
    expand("out/mafs/{tumour}.intersect.pol.maf", tumour=config['tumours']),
    expand("out/mafs/{tumour}.intersect.braf_kras.maf", tumour=config['tumours']),
    expand("out/mafs/{tumour}.intersect.other.maf", tumour=config['tumours']),
    expand("out/mafs/{tumour}.intersect.vaf.png", tumour=config['tumours']),

    expand("out/vardict/{tumour}.vardict.annotated.vcf.gz", tumour=config['tumours']),
    expand("out/vardict/{tumour}.vardict.maf", tumour=config['tumours']),

    expand("out/{sample}.sorted.dups.bam.bai", sample=config['samples']),

    # expand("out/{tumour}.mutect2_no_pon.vcf.gz", tumour=config['tumours']),

    # msi
    "out/aggregate/msisensor.tsv",
    expand("out/{tumour}.mantis.status", tumour=config['tumours']),
    # "out/aggregate/mantis.tsv",

    # combined results
    #"out/aggregate/mutect2.genes_of_interest.combined.tsv",
    #"out/aggregate/mutect2.combined.tsv",
    "out/aggregate/mutational_signatures.combined",
    "out/aggregate/mutational_signatures.filter.combined",

    "out/aggregate/mutational_signatures_v3_sbs.filter.combined.tsv",
    "out/aggregate/mutational_signatures_v3_dbs.filter.combined.tsv",
    "out/aggregate/mutational_signatures_v3_dbs.combined.tsv",
    "out/aggregate/mutational_signatures_v3_id.combined.tsv",
    "out/aggregate/mutational_signatures_v3_id_strelka.filter.combined.tsv",

    "out/aggregate/germline_joint.hc.normalized.vep.vcf.gz", # gatk calls for all germline samples

    "out/aggregate/max_coverage.tsv",
    "out/aggregate/ontarget.tsv",
    "out/aggregate/qc.summary.tsv",
    "out/aggregate/multiqc.html", # overall general qc

    "out/aggregate/ontarget.png", # combined ontarget coverage plots
    "out/aggregate/ontarget_tumour.png", # somatic ontarget coverage plots
    "out/aggregate/ontarget_germline.png", # germline ontarget coverage plots
    "out/aggregate/mutation_rate.tsv",
    "out/aggregate/mutation_rate_vardict.tsv",
    "out/aggregate/msi_burden.tsv",

### aggregate ###

# write out all tool versions (TODO)
rule make_versions:
  output:
    versions="out/aggregate/versions.txt"
  shell:
    "src/make_tsv.py --columns Tool Version --rows "
    "Pipeline,{VERSION} "
    ">{output.versions}"

rule report_md:
  input:
    versions="out/aggregate/versions.txt",
    signatures="out/aggregate/mutational_signatures.filter.combined",
    burden="out/aggregate/mutation_rate.tsv",
    msi_burden="out/aggregate/msi_burden.tsv",
    qc="out/aggregate/qc.summary.tsv",
    selected_variants="out/aggregate/mutect2.filter.genes_of_interest.combined.tsv",
    all_variants="out/aggregate/mutect2.filter.combined.tsv"
  output:
    md="out/aggregate/final.md",
    html="out/aggregate/final.html"
  log:
    stderr="log/make_report.stderr"
  shell:
    "src/make_report.py --versions {input.versions} --signatures {input.signatures} --burden {input.burden} --msi_burden {input.msi_burden} --qc {input.qc} --selected_variants {input.selected_variants} --all_variants {input.all_variants} > {output.md} 2>{log.stderr} && "
    "{config[module_pandoc]} && "
    "pandoc {output.md} | src/style_report.py > {output.html}"

### QC ###
rule qc_summary:
  input:
    expand("out/{sample}.artifact_metrics.txt.error_summary_metrics", sample=config['samples'])
  output:
    "out/aggregate/qc.summary.tsv"
  log:
    stderr="log/make_summary.stderr"
  shell:
    "python src/make_summary.py --verbose --samples {input} > {output} 2>{log.stderr}"

rule fastqc:
  input:
    fastqs=lambda wildcards: config["samples"][wildcards.sample]
  output:
    "out/fastqc/{sample}/completed"
  shell:
    "{config[module_java]} && "
    "mkdir -p out/fastqc/{wildcards.sample} && "
    "tools/FastQC/fastqc --extract --outdir out/fastqc/{wildcards.sample} {input.fastqs} && "
    "touch {output}"

rule make_sequence_dict:
  input:
    reference=config["genome"]
  output:
    config["genome_dict"]
  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar CreateSequenceDictionary REFERENCE={input.reference} OUTPUT={output}"

rule make_intervals:
  input:
    bed=config["regions"],
    dict=config["genome_dict"]
  output:
    "out/regions.intervals"
  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar BedToIntervalList INPUT={input.bed} OUTPUT={output} SEQUENCE_DICTIONARY={input.dict}"

rule qc_target:
  input:
    reference=config["genome"],
    bam="out/{sample}.sorted.dups.bam",
    intervals="out/regions.intervals"
  output:
    "out/{sample}.metrics.target"
  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar CollectHsMetrics REFERENCE_SEQUENCE={input.reference} INPUT={input.bam} OUTPUT={output} BAIT_INTERVALS={input.intervals} TARGET_INTERVALS={input.intervals}"

rule qc_alignment:
  input:
    reference=config["genome"],
    bam="out/{sample}.sorted.dups.bam"
  output:
    "out/{sample}.metrics.alignment"
  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar CollectAlignmentSummaryMetrics REFERENCE_SEQUENCE={input.reference} INPUT={input.bam} OUTPUT={output}"

rule qc_insertsize:
  input:
    bam="out/{sample}.sorted.dups.bam"
  output:
    "out/{sample}.metrics.insertsize"
  shell:
    "{config[module_java]} && "
    "{config[module_R]} && "
    "java -jar tools/picard-2.8.2.jar CollectInsertSizeMetrics INPUT={input.bam} OUTPUT={output} HISTOGRAM_FILE={output}.pdf"

rule qc_conpair:
  input:
    reference=config["genome"],
    reference_dict=config["genome_dict"],
    bams=tumour_germline_bams
  output:
    "out/{tumour}.concordance",
    "out/{tumour}.contamination"
  log:
    stderr="log/{tumour}.conpair.stderr",
    stdout="log/{tumour}.conpair.stdout"
  shell:
    "( "
    "{config[module_java]} && "
    "mkdir -p tmp/conpair_$$ && "
    "python tools/Conpair/scripts/run_gatk_pileup_for_sample.py --reference {input.reference} --conpair_dir tools/Conpair --gatk tools/GenomeAnalysisTK-3.8-1-0-gf15c1c3ef/GenomeAnalysisTK.jar -B {input.bams[0]} -O tmp/conpair_$$/tumour.pileup && "
    "python tools/Conpair/scripts/run_gatk_pileup_for_sample.py --reference {input.reference} --conpair_dir tools/Conpair --gatk tools/GenomeAnalysisTK-3.8-1-0-gf15c1c3ef/GenomeAnalysisTK.jar -B {input.bams[1]} -O tmp/conpair_$$/normal.pileup && "
    "PYTHONPATH=tools/Conpair/modules CONPAIR_DIR=tools/Conpair python tools/Conpair/scripts/verify_concordance.py -T tmp/conpair_$$/tumour.pileup -N tmp/conpair_$$/normal.pileup --outfile {output[0]} --normal_homozygous_markers_only && "
    "PYTHONPATH=tools/Conpair/modules CONPAIR_DIR=tools/Conpair python tools/Conpair/scripts/estimate_tumor_normal_contamination.py -T tmp/conpair_$$/tumour.pileup -N tmp/conpair_$$/normal.pileup --outfile {output[1]} && "
    "rm -r tmp/conpair_$$ "
    ") 1>{log.stdout} 2>{log.stderr}"

rule qc_verifybamid_tumour:
  input:
    vcf="out/{tumour}.strelka.somatic.snvs.af.vcf.gz",
    bam="out/{tumour}.sorted.dups.bam",
    bai="out/{tumour}.sorted.dups.bai",
  output:
    "out/{tumour}.verifybamid.somatic.completed"
  log:
    stderr="log/{tumour}.verifybamid.stderr"
  shell:
    "tools/verifyBamID_1.1.3/verifyBamID/bin/verifyBamID --vcf {input.vcf} --bam {input.bam} --bai {input.bai} --out out/{wildcards.tumour}.verifybamid --verbose 2>{log.stderr} && touch {output}"

rule qc_depth_of_coverage:
  input:
    reference=config["genome"],
    bed=config["regions"],
    bam="out/{sample}.sorted.dups.bam"
  output:
    "out/{sample}.depth_of_coverage.sample_summary"
  log:
    "log/{sample}.depth_of_coverage.stderr"
  params:
    prefix="out/{sample}.depth_of_coverage"
  shell:
    "{config[module_java]} && "
    "java -jar tools/GenomeAnalysisTK-3.7.0.jar -T DepthOfCoverage -R {input.reference} -o {params.prefix} -I {input.bam} -L {input.bed} && rm {params.prefix} "
    "2>{log}"

rule mosdepth:
  input:
    #fastqs=lambda wildcards: config["samples"][wildcards.sample]
    bam="out/{sample}.sorted.dups.bam",
    bed=config["regions"]
  output:
    "out/mosdepth/{sample}.mosdepth.completed"
  params:
    prefix="out/mosdepth/{sample}"
  shell:
    "{config[module_R]} && "
    "tools/mosdepth --by {input.bed} -n --thresholds 10,50,100,150,200,500,1000 {params.prefix} {input.bam} && "
    "touch {output}"

rule mosdepth_exon:
  input:
    #fastqs=lambda wildcards: config["samples"][wildcards.sample]
    bam="out/{sample}.sorted.dups.bam",
    bed=config["regions_exons"]
  output:
    "out/mosdepth_exons/{sample}.mosdepth.completed"
  params:
    prefix="out/mosdepth_exons/{sample}_exons"
  shell:
    "{config[module_R]} && "
    "tools/mosdepth --by {input.bed} -n --thresholds 10,50,100,150,200,500,1000 {params.prefix} {input.bam} && "
    "touch {output}"

rule peddy:
  input:
    vcf="out/aggregate/germline_joint.hc.normalized.vep.vcf.gz",
    reference=config['genome'],
    ped=config['ped']
    # bam="out/{sample}.sorted.dups.bam",
    # bed=config["regions_exons"]
  output:
    "out/peddy/peddy.completed"
  # params:
  #   prefix="out/mosdepth_exons/{sample}_exons"
  shell:
    "{config[module_R]} && "
    #"peddy --plot -p 2 --prefix out/peddy/mystudy {input.vcf} {input.ped} && "
    "peddy --plot --prefix out/peddy/mystudy {input.vcf} {input.ped} && "
    "touch {output}"

rule multiqc:
  input:
    expand("out/fastqc/{sample}/completed", sample=config['samples']),
    expand("out/{sample}.metrics.alignment", sample=config['samples']),
    expand("out/{sample}.metrics.insertsize", sample=config['samples']),
    expand("out/{sample}.metrics.target", sample=config['samples']),
    expand("out/{tumour}.concordance", tumour=config['tumours']), # TODO
    expand("out/{tumour}.contamination", tumour=config['tumours']), # TODO
    #expand("out/{tumour}.verifybamid.somatic.completed", tumour=config['tumours']),
    expand("out/{sample}.depth_of_coverage.sample_summary", sample=config['samples']),
    # expand("out/peddy/"),
    expand("out/mosdepth/{sample}.mosdepth.completed", sample=config['samples']),
    "out/aggregate/qc.summary.tsv"

  output:
    "out/aggregate/multiqc.html"
  shell:
    "multiqc --force --filename {output} out"

rule qc_on_target_coverage_hist:
  input:
    bed=config["regions"],
    bam="out/{sample}.sorted.dups.bam"
  output:
    hist="out/{sample}.ontarget.hist",
  shell:
    "{config[module_bedtools]} && "
    #"bedtools sort -g reference/genome.lengths -i {input.bed} | bedtools merge -i - | bedtools coverage -sorted -hist -b {input.bam} -a stdin -g reference/genome.lengths | grep ^all > {output.hist}" # 2.27
    "bedtools sort -faidx reference/genome.lengths -i {input.bed} | bedtools merge -i - | bedtools coverage -sorted -hist -b {input.bam} -a stdin -g reference/genome.lengths | grep ^all > {output.hist}"

rule qc_on_target_coverage:
  input:
    reference=config["genome"],
    bed=config["regions"],
    bam="out/{sample}.sorted.dups.bam"
  output:
    summary="out/{sample}.ontarget.summary"
  shell:
    "{config[module_bedtools]} && "
    #"bedtools sort -g reference/genome.lengths -i {input.bed} | bedtools merge -i - | bedtools coverage -sorted -a stdin -b {input.bam} -d -g reference/genome.lengths | cut -f5 | src/stats.py > {output.summary}" # 2.27
    "bedtools sort -faidx reference/genome.lengths -i {input.bed} | bedtools merge -i - | bedtools coverage -sorted -a stdin -b {input.bam} -d -g reference/genome.lengths | cut -f5 | src/stats.py > {output.summary}"

rule qc_on_target_coverage_plot:
  input:
    expand("out/{sample}.ontarget.hist", sample=config['samples']),
  output:
    "out/aggregate/ontarget.png"
  shell:
    "{config[module_samtools]} && "
    "src/plot_coverage.py --target {output} --files {input} --max 10000"

rule qc_on_target_coverage_plot_germline:
  input:
    expand("out/{germline}.ontarget.hist", germline=germline_samples()),
  output:
    "out/aggregate/ontarget_germline.png"
  shell:
    "{config[module_samtools]} && "
    "src/plot_coverage.py --target {output} --files {input} --max 10000"

rule qc_on_target_coverage_plot_tumour:
  input:
    expand("out/{tumour}.ontarget.hist", tumour=config['tumours']),
  output:
    "out/aggregate/ontarget_tumour.png"
  shell:
    "{config[module_samtools]} && "
    "src/plot_coverage.py --target {output} --files {input} --max 10000"

rule qc_on_target_coverage_combined:
  input:
    expand("out/{sample}.ontarget.summary", sample=config['samples']),
  output:
    "out/aggregate/ontarget.tsv"
  shell:
    "echo \"Filename    n       Mean    Min     Max     Total\" >{output} && "
    "for f in {input}; do echo \"$f     $(tail -1 $f)\" >> {output}; done"

### alignment ###
rule align:
  input:
    reference=config["genome"],
    fastqs=lambda wildcards: config["samples"][wildcards.sample]

  output:
    "tmp/{sample}.paired.bam"

  log:
    "log/{sample}.paired.bwa.log"

  params:
    cores=cluster["align"]["n"],
    read_group=read_group

  shell:
    "{config[module_bwa]} && {config[module_samtools]} && "
    "(bwa mem -M -t {params.cores} -R \"{params.read_group}\" {input.reference} {input.fastqs} | samtools view -b -h -o {output} -) 2>{log}"

# sort the bam
rule sort:
  input:
    "tmp/{sample}.paired.bam"

  output:
    bam="tmp/{sample}.sorted.bam",
    bai="tmp/{sample}.sorted.bai"

  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar SortSam INPUT={input} OUTPUT={output.bam} VALIDATION_STRINGENCY=LENIENT SORT_ORDER=coordinate MAX_RECORDS_IN_RAM=2000000 CREATE_INDEX=True"

# duplicates
rule gatk_duplicates:
  input:
    "tmp/{sample}.sorted.bam"
  output:
    "out/{sample}.sorted.dups.bam",
    "out/{sample}.sorted.dups.bai",
    "out/{sample}.markduplicates.metrics"
  log:
    "log/{sample}.markduplicates.stderr"
  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar MarkDuplicates INPUT={input} OUTPUT={output[0]} METRICS_FILE={output[2]} VALIDATION_STRINGENCY=LENIENT ASSUME_SORTED=True CREATE_INDEX=True MAX_RECORDS_IN_RAM=2000000"

# index bam file
rule index_bam_file:
  input:
    "out/{sample}.sorted.dups.bam"
  output:
    "out/{sample}.sorted.dups.bam.bai"
  log:
    "log/{sample}.bamindex.stderr"
  shell:
    "samtools index {input} {output}"

### germline variant calling ###
rule gatk_haplotype_caller:
  input:
    bam="out/{germline}.sorted.dups.bam",
    reference=config["genome"],
    regions=config["regions"],
    #regions_chr=config["regions_name"] + "_{chromosome}.bed"
  output:
    recal="out/{germline}.recal_table",
    bqsr="out/{germline}.sorted.dups.bqsr.bam",
    gvcf="out/{germline}.hc.gvcf.gz",
    gvcfindel="out/{germline}.hc.forindels.gvcf.gz"
  log:
    "log/{germline}.hc.log"
  shell:
    "({config[module_java]} && "
    "tools/gatk-4.1.2.0/gatk BaseRecalibrator --input {input.bam} --output {output.recal} -R {input.reference} --known-sites reference/gatk-4-bundle-b37/dbsnp_138.b37.vcf.bgz --known-sites reference/gatk-4-bundle-b37/Mills_and_1000G_gold_standard.indels.b37.vcf.bgz --known-sites reference/gatk-4-bundle-b37/1000G_phase1.indels.b37.vcf.bgz && "
    "tools/gatk-4.1.2.0/gatk ApplyBQSR -R {input.reference} -I {input.bam} -bqsr {output.recal} -O {output.bqsr} && "
    "tools/gatk-4.1.2.0/gatk HaplotypeCaller -R {input.reference} -I {output.bqsr} -L {input.regions} --emit-ref-confidence GVCF --dbsnp reference/gatk-4-bundle-b37/dbsnp_138.b37.vcf.bgz -O {output.gvcf} && "
    "tools/gatk-4.1.2.0/gatk HaplotypeCaller -R {input.reference} -I {output.bqsr} -L {input.regions} -stand-call-conf 2 --output-mode EMIT_ALL_CONFIDENT_SITES -A BaseQualityRankSumTest -A ClippingRankSumTest -A Coverage -A FisherStrand -A MappingQuality -A RMSMappingQuality -A ReadPosRankSumTest -A StrandOddsRatio -A TandemRepeat --emit-ref-confidence GVCF --dbsnp reference/gatk-4-bundle-b37/dbsnp_138.b37.vcf.bgz -O {output.gvcfindel}"
    ") 2>{log}"

rule gatk_genotype_hc_indels:
  input:
    bam="out/{germline}.sorted.dups.bam",
    vcf="out/{germline}.hc.gvcf.gz",
    reference=config["genome"],
    regions=config["regions"],
    #regions_chr=config["regions_name"] + "_{chromosome}.bed"
  output:
    #gvcf="out/{germline}.hc.gvcf.gz",
    tmp_vcf="tmp/{germline}.hc.gt.vcf",
    tmp_vcfindel="tmp/{germline}.hc.gt.indels.vcf",
    vcfindel="out/{germline}.hc.gt.indels.vcf.gz"
  log:
    "log/{germline}.hc.gt.indels.log"
  shell:
    "({config[module_java]} && "
    "tools/gatk-4.1.2.0/gatk GenotypeGVCFs -R {input.reference} --dbsnp reference/gatk-4-bundle-b37/dbsnp_138.b37.vcf.bgz -V {input.vcf} -L {input.regions} --use-new-qual-calculator true --output {output.tmp_vcf} && "
    "tools/gatk-4.1.2.0/gatk SelectVariants -R {input.reference} -V {output.tmp_vcf} --output {output.tmp_vcfindel} --select-type-to-include INDEL --min-indel-size 19 && "
    "bgzip -c {output.tmp_vcfindel} > {output.vcfindel}"
    ") 2>{log}"

rule gatk_joint_genotype:
  input:
    gvcfs=expand("out/{germline}.hc.gvcf.gz", germline=germline_samples()),
    reference=config["genome"],
    regions=config["regions"],
    regions_chr=config["regions_name"] + "_{chromosome}.bed"
  output:
    "out/germline_joint_{chromosome}.vcf"
  log:
    "log/gatk_joint_{chromosome}.stderr"
  params:
    variant_list=' '.join(['--variant {}'.format(gvcf) for gvcf in expand("out/{germline}.hc.gvcf.gz", germline=germline_samples())])
  shell:
    "({config[module_java]} && "
    "java -jar tools/GenomeAnalysisTK-3.7.0.jar -T CombineGVCFs -R {input.reference} {params.variant_list} -L {input.regions_chr} -o tmp/germline_combined_{wildcards.chromosome}.gvcf -A DepthPerSampleHC -A DepthPerAlleleBySample -A QualByDepth -A RMSMappingQuality -A MappingQualityRankSumTest -A FisherStrand -A StrandOddsRatio && "
    "tools/gatk-4.1.2.0/gatk GenotypeGVCFs -R {input.reference} --dbsnp reference/gatk-4-bundle-b37/dbsnp_138.b37.vcf.bgz -V tmp/germline_combined_{wildcards.chromosome}.gvcf -L {input.regions_chr} --use-new-qual-calculator true --output out/germline_joint_{wildcards.chromosome}.vcf"
    ") 2>{log}"

# notes:
# VariantRecalibrator removed due to large cohort size requirements
rule gatk_post_genotype:
  input:
    gvcfs=expand("out/germline_joint_{chromosome}.vcf", chromosome=GATK_CHROMOSOMES),
    reference=config["genome"]
  output:
    "out/germline_joint.hc.normalized.vcf"
  log:
    "log/gatk_post.stderr"
  params:
    inputs=' '.join(['--INPUT={}'.format(gvcf) for gvcf in expand("out/germline_joint_{chromosome}.vcf", chromosome=GATK_CHROMOSOMES)])
  shell:
    "({config[module_java]} && {config[module_R]} && {config[module_samtools]} && "
    "{config[module_htslib]} && "
    "tools/gatk-4.1.2.0/gatk GatherVcfs -R {input.reference} --OUTPUT=tmp/germline_joint.vcf {params.inputs} && "
    "bgzip -c < tmp/germline_joint.vcf > tmp/germline_joint.vcf.bgz && tabix -p vcf tmp/germline_joint.vcf.bgz && "
    "tools/gatk-4.1.2.0/gatk CalculateGenotypePosteriors -R {input.reference} --supporting reference/gatk-4-bundle-b37/1000G_phase3_v4_20130502.sites.vcf.bgz -V tmp/germline_joint.vcf.bgz -O tmp/germline_joint.cgp.vcf && "
    "tools/gatk-4.1.2.0/gatk VariantFiltration -R {input.reference} -V tmp/germline_joint.cgp.vcf -O tmp/germline_joint.cgp.filter.vcf --filter-expression \"QUAL < 30.0\" --filter-name \"VeryLowQual\" --filter-expression \"QD < 2.0\" --filter-name \"LowQD\" --filter-expression \"DP < 10\" --filter-name \"LowCoverage\" --filter-expression \"MQ < 40.0\" --filter-name \"LowMappingQual\" --filter-expression \"SOR > 4.0\" --filter-name \"StrandBias\" --filter-expression \"HRun > 5.0\" --filter-name \"HRun5\" --cluster-size 3 && "
    "tools/vt-0.577/vt normalize -n -r {input.reference} tmp/germline_joint.cgp.filter.vcf -o tmp/germline_joint.cgp.normalized.vcf && "
    "tools/vt-0.577/vt decompose -s tmp/germline_joint.cgp.normalized.vcf | tools/vt-0.577/vt normalize -r {input.reference} - -o {output}"
    ") 2>{log}"

### qc ###
rule qc_max_coverage_combine:
  input:
    expand("out/{sample}.max_coverage", sample=config['samples']),
  output:
    "out/aggregate/max_coverage.tsv"
  shell:
    ">{output} && "
    "for f in {input}; do echo \"$f $(grep \"Max coverage\" $f)\" >> {output}; done"

rule qc_max_trimmed_coverage_combine:
  input:
    expand("out/{sample}.max_trimmed_coverage", sample=config['samples']),
  output:
    "out/aggregate/max_trimmed_coverage.tsv"
  shell:
    ">{output} && "
    "for f in {input}; do echo \"$f $(grep \"Max coverage\" $f)\" >> {output}; done"

rule qc_max_coverage:
  input:
    bed=config["regions"],
    fastqs=lambda wildcards: config["samples"][wildcards.sample]
  output:
    "out/{sample}.max_coverage"
  log:
    "log/{sample}.max_coverage.stderr"
  shell:
    "src/max_coverage.py --verbose --bed {input.bed} --fastqs {input.fastqs} >{output} 2>{log}"

rule qc_max_trimmed_coverage:
  input:
    bed=config["regions"],
    fastqs=("out/{sample}_R1.trimmed.paired.fq.gz", "out/{sample}_R1.trimmed.unpaired.fq.gz", "out/{sample}_R2.trimmed.paired.fq.gz", "out/{sample}_R2.trimmed.unpaired.fq.gz")

  output:
    "out/{sample}.max_trimmed_coverage"
  log:
    "log/{sample}.max_trimmed_coverage.stderr"
  shell:
    "src/max_coverage.py --verbose --bed {input.bed} --fastqs {input.fastqs} >{output} 2>{log}"

rule qc_sequencing_artifacts:
  input:
    bam="out/{sample}.sorted.dups.bam",
    reference=config["genome"]

  output:
    "out/{sample}.artifact_metrics.txt.error_summary_metrics"

  params:
    prefix="out/{sample}.artifact_metrics.txt"

  log:
    stderr="log/{sample}.artifact.err",
    stdout="log/{sample}.artifact.out"

  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar CollectSequencingArtifactMetrics I={input.bam} O={params.prefix} R={input.reference} 2>{log.stderr} 1>{log.stdout}"

rule qc_oxidative_artifacts:
  input:
    bam="out/{sample}.sorted.dups.bam",
    reference=config["genome"]

  output:
    "out/{sample}.oxo_metrics.txt"

  log:
    stderr="log/{sample}.oxo.err",
    stdout="log/{sample}.oxo.out"

  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar CollectOxoGMetrics I={input.bam} O={output} R={input.reference} 2>{log.stderr} 1>{log.stdout}"

### simple germline variant calling using GATK ###



### somatic variant calling ###
rule strelka_somatic:
  input:
    reference=config["genome"],
    bams=tumour_germline_bams,
    regions=config["regions_strelka"]

  output:
    "out/{tumour}.strelka.somatic.snvs.vcf.gz",
    "out/{tumour}.strelka.somatic.indels.vcf.gz",

  log:
    "log/{tumour}.strelka.somatic.log"

  params:
    cores=cluster["strelka_somatic"]["n"]

  shell:
    "(mkdir -p tmp/strelka_{wildcards.tumour}_$$ && "
    "{config[module_intel]} && "
    "{config[module_python2]} && "
    "tools/strelka-2.9.10.centos6_x86_64/bin/configureStrelkaSomaticWorkflow.py "
    "--ref {input.reference} "
    "--tumorBam {input.bams[0]} "
    "--normalBam {input.bams[1]} "
    "--runDir tmp/strelka_{wildcards.tumour}_$$ "
    "--exome "
    "--callRegions {input.regions} && "
    "tmp/strelka_{wildcards.tumour}_$$/runWorkflow.py -m local -j {params.cores} && "
    "mv tmp/strelka_{wildcards.tumour}_$$/results/variants/somatic.snvs.vcf.gz {output[0]} && "
    "mv tmp/strelka_{wildcards.tumour}_$$/results/variants/somatic.indels.vcf.gz {output[1]} && "
    "rm -r tmp/strelka_{wildcards.tumour}_$$ ) 2>{log}"

rule annotate_af_somatic:
  input:
    "out/{tumour}.strelka.somatic.snvs.norm.vcf.gz",
  output:
    temp="tmp/{tumour}.strelka.somatic.snvs.af.vcf",
    vcf="out/{tumour}.strelka.somatic.snvs.af.vcf.gz"
  log:
    stderr="log/{tumour}.annotate_af.stderr"
  shell:
    #"src/annotate_af.py TUMOR {input} > {output.temp}"
    #"{config[module_samtools]} && "
    "{config[module_htslib]} && "
    "src/annotate_af.py TUMOR {input} > {output.temp} && "
    "bgzip -c {output.temp} > {output.vcf} 2>{log.stderr}"

rule annotate_af_indels_somatic:
  input:
    "out/{tumour}.strelka.somatic.indels.norm.vcf.gz",
  output:
    temp="tmp/{tumour}.strelka.somatic.indels.af.vcf",
    vcf="out/{tumour}.strelka.somatic.indels.af.vcf.gz"
  log:
    stderr="log/{tumour}.annotate_af_indels.stderr"
  shell:
    #"{config[module_samtools]} && "
    "{config[module_htslib]} && "
    "src/annotate_af_indels.py TUMOR {input} > {output.temp} && "
    "bgzip -c {output.temp} > {output.vcf} 2>{log.stderr}"

# FIXING ERRORS HERE
rule annotate_dps_strelka_somatic:
  input:
    "out/{tumour}.strelka.somatic.snvs.af.vcf.gz",
  output:
    temp="tmp/{tumour}.strelka.somatic.snvs.af.dp.vcf",
    vcf="out/{tumour}.strelka.somatic.snvs.af.dp.vcf.gz",
  log:
    stderr="log/{tumour}.annotate_dps_strelka_somatic.stderr"
  shell:
    #"{config[module_samtools]} && "
    #"{config[module_htslib]} && "
    "src/annotate_depth.py {input} > {output.temp} && "
    "bgzip -c {output.temp} > {output.vcf} 2>{log.stderr}"
    #"src/annotate_depth.py {input} | bgzip >{output} 2>{log.stderr}"

rule annotate_dps_strelka_somatic_indels:
  input:
    "out/{tumour}.strelka.somatic.indels.af.vcf.gz",
  output:
    temp="tmp/{tumour}.strelka.somatic.indels.af.dp.vcf",
    vcf="out/{tumour}.strelka.somatic.indels.af.dp.vcf.gz",
  log:
    stderr="log/{tumour}.annotate_dps_strelka_somatic_indels.stderr"
  shell:
    #"{config[module_samtools]} && "
    #"{config[module_htslib]} && "
    "src/annotate_depth.py {input} > {output.temp} && "
    "bgzip -c {output.temp} > {output.vcf} 2>{log.stderr}"
    #"src/annotate_depth.py {input} | bgzip >{output} 2>{log.stderr}"

rule annotate_dps_strelka_somatic_filter:
  input:
    "out/{tumour}.strelka.somatic.snvs.af.dp.vcf.gz",
  output:
    "out/{tumour}.strelka.somatic.snvs.af.dp.filtered.vcf.gz",
  log:
    stderr="log/{tumour}.annotate_dps_strelka_somatic_filter.stderr"
  shell:
    "src/vtfilter.sh {input} {output} {config[af_threshold]} {config[depth_n]} {config[depth_t]} 2>{log.stderr}"

rule annotate_dps_strelka_somatic_filter_indels:
  input:
    "out/{tumour}.strelka.somatic.indels.af.dp.vcf.gz",
  output:
    "out/{tumour}.strelka.somatic.indels.af.dp.filtered.vcf.gz",
  log:
    stderr="log/{tumour}.annotate_dps_strelka_somatic_filter_indels.stderr"
  shell:
    "src/vtfilter.sh {input} {output} {config[af_threshold]} {config[depth_n]} {config[depth_t]} 2>{log.stderr}"

# tumour only for each germline
rule mutect2_sample_pon:
  input:
    reference=config["genome"],
    bam="out/{germline}.sorted.dups.bam",
    regions=config["regions"],
  output:
    "out/{germline}.mutect2.pon.vcf.gz",
  log:
    stderr="log/{germline}.mutect2.pon.stderr"
  shell:
    "{config[module_java]} && "
    "tools/gatk-4.1.2.0/gatk Mutect2 -R {input.reference} -I {input.bam} -O {output} --disable-read-filter MateOnSameContigOrNoMappedMateReadFilter --max-mnp-distance 0 2>{log.stderr}"
    #"tools/gatk-4.1.2.0/gatk Mutect2 -R {input.reference} -I {input.bam} --tumor-sample {wildcards.germline} -L {input.regions} -O {output} --interval-padding 1000 --disable-read-filter MateOnSameContigOrNoMappedMateReadFilter 2>{log.stderr}"

# Create a GenomicsDB from the normal Mutect2 calls
rule mutect2_GenomicsDBImport:
  input:
    reference=config["genome"],
    regions=config["regions"],
    vcfs=expand("out/{germline}.mutect2.pon.vcf.gz", germline=germline_samples()),
  output:
    directory("out/pon_db/{chromosome}")
  params:
    vcfs=' '.join(['-V {}'.format(vcf) for vcf in expand("out/{germline}.mutect2.pon.vcf.gz", germline=germline_samples())]),
    cores=cluster["mutect2_GenomicsDBImport"]["n"]
  log:
    stderr="log/mutect2.gdb.{chromosome}.stderr"
  shell:
    #"mkdir -p out/pon_db && "
    "{config[module_java]} && "
    #"tools/gatk-4.1.2.0/gatk GenomicsDBImport -R {input.reference} -L {input.regions} --max-num-intervals-to-import-in-parallel {params.cores} --genomicsdb-workspace-path {output} {params.vcfs} 2>{log.stderr}"
    "tools/gatk-4.1.2.0/gatk --java-options '-Xmx12g -Xms12g' GenomicsDBImport -R {input.reference} -L {wildcards.chromosome} --reader-threads {params.cores} --genomicsdb-workspace-path {output} {params.vcfs} 2>{log.stderr}"

# Create a pon VCF per chromosome
rule mutect2_GenomicsDBImport_vcf:
  input:
    reference=config["genome"],
    pon_db="out/pon_db/{chromosome}",
    #regions=config["regions"],
    #vcfs=expand("out/{germline}.mutect2.pon.vcf.gz", germline=germline_samples()),
  output:
    "tmp/mutect2.pon.{chromosome}.vcf.gz"
  params:
    vcfs=' '.join(['-V {}'.format(vcf) for vcf in expand("out/{germline}.mutect2.pon.vcf.gz", germline=germline_samples())]),
    cores=cluster["mutect2_GenomicsDBImport"]["n"]
  log:
    stderr="log/mutect2.gdb.vcf.{chromosome}.stderr"
  shell:
    "{config[module_java]} && "
    #"tools/gatk-4.1.2.0/gatk GenomicsDBImport -R {input.reference} -L {input.regions} --max-num-intervals-to-import-in-parallel {params.cores} --genomicsdb-workspace-path {output} {params.vcfs} 2>{log.stderr}"
    "tools/gatk-4.1.2.0/gatk --java-options '-Xmx12g -Xms12g' CreateSomaticPanelOfNormals -R {input.reference} -V gendb://out/pon_db/{wildcards.chromosome} -O {output} 2>{log.stderr}"
    #"tools/gatk-4.1.2.0/gatk --java-options '-Xmx12g -Xms12g' GenomicsDBImport -R {input.reference} -L {wildcards.chromosome} --reader-threads {params.cores} --genomicsdb-workspace-path {output} {params.vcfs} 2>{log.stderr}"

# mutect2 somatic calls
rule mutect2_somatic_chr:
  input:
    reference=config["genome"],
    dbsnp="reference/gatk-4-bundle-b37/dbsnp_138.b37.vcf.bgz",
    regions=config["regions"],
    regions_chr=config["regions_name"] + "_{chromosome}.bed",
    #pon="out/mutect2.pon.vcf.gz",
    pon_chr="tmp/mutect2.pon.{chromosome}.vcf.gz",
    #pon_chr=expand("out/mutect2.pon.{chromosome}.vcf.gz", chromosome=GATK_CHROMOSOMES),
    gnomad="reference/af-only-gnomad.raw.sites.b37.vcf.gz",
    bams=tumour_germline_dup_bams
  output:
    vcf="tmp/{tumour}.{chromosome}.mutect2.vcf.gz",
    f1r2="tmp/{tumour}.{chromosome}.f1r2.tar.gz",
  log:
    stderr="log/{tumour}.{chromosome}.mutect2.stderr"
  params:
    germline=lambda wildcards: config["tumours"][wildcards.tumour]
  shell:
    "{config[module_java]} && "
    # "tools/gatk-4.1.2.0/gatk --java-options '-Xmx30G' Mutect2 -R {input.reference} -I {input.bams[0]} -I {input.bams[1]} --tumor-sample {wildcards.tumour} --normal-sample {params.germline} --output {output} --germline-resource {input.gnomad} --af-of-alleles-not-in-resource 0.0000025 -pon {input.pon_chr} --interval-padding 1000 -L {input.regions} -L {wildcards.chromosome} --interval-set-rule INTERSECTION --disable-read-filter MateOnSameContigOrNoMappedMateReadFilter"
    "tools/gatk-4.1.2.0/gatk --java-options '-Xmx30G' Mutect2 -R {input.reference} -I {input.bams[0]} -I {input.bams[1]} --tumor-sample {wildcards.tumour} --normal-sample {params.germline} --output {output.vcf} --germline-resource {input.gnomad} --af-of-alleles-not-in-resource 0.0000025 -pon {input.pon_chr} --interval-padding 1000 -L {input.regions_chr} --interval-set-rule INTERSECTION --f1r2-tar-gz {output.f1r2} --disable-read-filter MateOnSameContigOrNoMappedMateReadFilter"

# new mutect2filter before merging
rule mutect2_filter:
  input:
    reference=config["genome"],
    # vcf="out/{tumour}.mutect2.vcf.gz",
    vcf="tmp/{tumour}.{chromosome}.mutect2.vcf.gz",
    bam="out/{tumour}.sorted.dups.bam",
    regions=config["regions"],
    regions_chr=config["regions_name"] + "_{chromosome}.bed",
    gnomad="reference/af-only-gnomad.raw.sites.b37.vcf.gz",
    f1r2="tmp/{tumour}.{chromosome}.f1r2.tar.gz"
  output:
    pileup="tmp/{tumour}.{chromosome}.mutect2.pileup.table",
    contamination="tmp/{tumour}.{chromosome}.mutect2.contamination.table",
    vcf="tmp/{tumour}.{chromosome}.mutect2.filter.vcf.gz",
    orientation="tmp/{tumour}.{chromosome}.read-orientation-model.tar.gz",
  log:
    stderr="log/{tumour}.{chromosome}.mutect2-filter.stderr",
    stdout="log/{tumour}.{chromosome}.mutect2-filter.stdout"
  shell:
    "({config[module_java]} && "
    "tools/gatk-4.1.2.0/gatk LearnReadOrientationModel -I {input.f1r2} -O {output.orientation} && "
    "tools/gatk-4.1.2.0/gatk GetPileupSummaries -I {input.bam} -V {input.gnomad} -O {output.pileup} --intervals {input.regions_chr} && "
    "tools/gatk-4.1.2.0/gatk CalculateContamination -I {output.pileup} -O {output.contamination} && "
    "tools/gatk-4.1.2.0/gatk FilterMutectCalls -V {input.vcf} -R {input.reference} --ob-priors {output.orientation} -O {output.vcf}) 1>{log.stdout} 2>{log.stderr}"
    # don't need contamination table for small gene panels "tools/gatk-4.1.2.0/gatk FilterMutectCalls -V {input.vcf} -R {input.reference} --contamination-table {output.contamination} -O {output.vcf}) 1>{log.stdout} 2>{log.stderr}"

# # run mutect without pon
# rule mutect2_somatic_no_pon:
#   input:
#     reference=config["genome"],
#     dbsnp="reference/gatk-4-bundle-b37/dbsnp_138.b37.vcf.bgz",
#     regions=config["regions"],
#     gnomad="reference/af-only-gnomad.raw.sites.b37.vcf.gz",
#     bams=tumour_germline_dup_bams
#     #vcfs=expand("tmp/{{tumour}}.{chromosome}.mutect2.vcf.gz", chromosome=GATK_CHROMOSOMES)
#   output:
#     "out/{tumour}.mutect2_no_pon.vcf.gz"
#   log:
#     stderr="log/{tumour}.mutect2.no_pon.stderr"
#   params:
#     germline=lambda wildcards: config["tumours"][wildcards.tumour]
#   shell:
#     "{config[module_java]} && "
#     "tools/gatk-4.1.2.0/gatk --java-options '-Xmx30G' Mutect2 -R {input.reference} -L {input.regions} -I {input.bams[0]} -I {input.bams[1]} --normal {params.germline} --output {output} --germline-resource {input.gnomad} 2>{log.stderr}"

rule mutect2_somatic:
  input:
    # vcfs=expand("tmp/{{tumour}}.{chromosome}.mutect2.vcf.gz", chromosome=GATK_CHROMOSOMES)
    vcfs=expand("tmp/{{tumour}}.{chromosome}.mutect2.filter.vcf.gz", chromosome=GATK_CHROMOSOMES) # filtered
  output:
    "out/{tumour}.mutect2.filter.vcf.gz"
    # "out/{tumour}.mutect2.vcf.gz"
  log:
    stderr="log/{tumour}.mutect2.mergevcfs.stderr"
  params:
    inputs=' '.join(['I={}'.format(vcf) for vcf in expand("tmp/{{tumour}}.{chromosome}.mutect2.filter.vcf.gz", chromosome=GATK_CHROMOSOMES)])
  shell:
    "{config[module_java]} && "
    "java -jar tools/picard-2.8.2.jar MergeVcfs {params.inputs} O={output} 2>{log.stderr}"

### platypus ###
# rule platypus_somatic:
#   input:
#     reference=config["genome"],
#     bams=tumour_germline_bams
#
#   output:
#     joint="out/{tumour}.platypus.joint.vcf.gz",
#     somatic="out/{tumour}.platypus.somatic.vcf.gz"
#
#   log:
#     "log/{tumour}.platypus.somatic.log"
#
#   params:
#     germline=germline_sample
#
#   shell:
#     # platypus has to run from build directory
#     "({config[module_python2]} && "
#     "{config[module_htslib]} && "
#     "{config[module_samtools]} && "
#     "tools/Platypus_0.8.1/Platypus.py callVariants --bamFiles={input.bams[0]},{input.bams[1]} --refFile={input.reference} --output=tmp/platypus_{wildcards.tumour}.vcf && "
#     "bgzip < tmp/platypus_{wildcards.tumour}.vcf > {output.joint} && "
#     "python tools/Platypus/extensions/Cancer/somaticMutationDetector.py --inputVCF tmp/platypus_{wildcards.tumour}.vcf --outputVCF {output.somatic} --tumourSample {wildcards.tumour}.sorted.dups --normalSample {params.germline}.sorted.dups) 2>{log}"

### pindel ###
#rule pindel_somatic:


### annotation ###
rule annotate_vep_somatic_snvs:
  input:
    vcf="out/{tumour}.strelka.somatic.snvs.af.dp.filtered.vcf.gz",
    reference=config['genome']
  output:
    "out/{tumour}.strelka.somatic.snvs.af.dp.filtered.vep.vcf.gz"
  log:
    "log/{tumour}.vep.log"
  params:
    cores=cluster["annotate_vep_somatic_snvs"]["n"]
  shell:
    "{config[module_samtools]} && "
    "src/annotate.sh {input.vcf} {output} {input.reference} {params.cores} 2>{log}"

rule annotate_vep_somatic_indels:
  input:
    vcf="out/{tumour}.strelka.somatic.indels.af.dp.filtered.vcf.gz",
    reference=config['genome']
  output:
    "out/{tumour}.strelka.somatic.indels.af.dp.filtered.vep.vcf.gz"
  log:
    "log/{tumour}.vep.log"
  params:
    cores=cluster["annotate_vep_somatic_indels"]["n"]
  shell:
    "{config[module_samtools]} && "
    "src/annotate.sh {input.vcf} {output} {input.reference} {params.cores} 2>{log}"

rule annotate_vep_hc:
  input:
    vcf="out/germline_joint.hc.normalized.vcf",
    reference=config['genome']
  output:
    "out/aggregate/germline_joint.hc.normalized.vep.vcf.gz"
  log:
    "log/hc.vep.log"
  params:
    cores=cluster["annotate_vep_germline"]["n"]
  shell:
    "{config[module_samtools]} && "
    "src/annotate.sh {input.vcf} {output} {input.reference} {params.cores} 2>{log}"

rule annotate_vep_hc_tumours:
  input:
    vcf="out/tumour_joint.hc.normalized.vcf",
    reference=config['genome']
  output:
    "out/aggregate/tumour_joint.hc.normalized.vep.vcf.gz"
  log:
    "log/hc.vep.log"
  params:
    cores=cluster["annotate_vep_germline"]["n"]
  shell:
    "{config[module_samtools]} && "
    "src/annotate.sh {input.vcf} {output} {input.reference} {params.cores} 2>{log}"

rule annotate_vep_intersect:
  input:
    vcf="out/intersect.vcf.gz",
    reference=config['genome']
  output:
    "out/aggregate/intersect.vep.vcf.gz"
  log:
    "log/hc.vep.log"
  params:
    cores=cluster["annotate_vep_intersect"]["n"]
  shell:
    "{config[module_samtools]} && "
    "src/annotate.sh {input.vcf} {output} {input.reference} {params.cores} 2>{log}"

rule annotate_vardict:
  input:
    vcf="out/vardict/{tumour}.vardict.vcf",
    reference=config['genome']
  output:
    tmp="tmp/{tumour}.vardict.filtered.vcf",
    vcf="out/vardict/{tumour}.vardict.annotated.vcf.gz",
  log:
    "log/{tumour}.vardict.annotate.log"
  params:
    cores=cluster["annotate_vardict"]["n"]
  shell:
    "{config[module_samtools]} && "
    #vt view -h -f "PASS&&INFO.AF>0.07&&INFO.STATUS!='Germline'" 0636321001_T.vardict.annotated.vcf.gz
    # "vt view -h -f "PASS&&INFO.AF>0.07&&INFO.STATUS!='Germline'" {input.vcf} "
    # "src/annotate.sh {input.vcf} {output.vcf} {input.reference} {params.cores} 2>{log}"
    "vt view -h -f \"PASS&&INFO.AF>{config[af_threshold]}&&INFO.DP>{config[dp_threshold]}&&INFO.STATUS!='Germline'\" {input.vcf} -o {output.tmp} && "
    "src/annotate.sh {output.tmp} {output.vcf} {input.reference} {params.cores} 2>{log}"
    # "rm {output.tmp}"

#rule annotate_vep_mutect2:
#  input:
#    vcf="out/{tumour}.mutect2.filter.vcf.gz",
#    reference=config['genome']
#  output:
#    "out/{tumour}.mutect2.filter.norm.vep.vcf.gz"
#  log:
#    "log/{tumour}.mutect2.vep.log"
#  params:
#    cores=cluster["annotate_vep_mutect2"]["n"]
#  shell:
#    "{config[module_samtools]} && "
#    "{config[module_htslib]} && "
#    "{config[module_bedtools]} && "
#    "tools/vt-0.577/vt decompose -s {input.vcf} | tools/vt-0.577/vt normalize -n -r {input.reference} - -o out/{wildcards.tumour}.mutect2.filter.norm.vcf.gz && "
#    "src/annotate.sh out/{wildcards.tumour}.mutect2.filter.norm.vcf.gz {output} {input.reference} {params.cores} 2>{log}"

###MUTECT2 - workflow################
rule annotate_afdp_mutect2_filter:
  input:
    vcf="out/{tumour}.mutect2.filter.vcf.gz",
    reference=config['genome']
  output:
    "out/{tumour}.mutect2.filter.norm.af.dp.vcf.gz"
  log:
    stderr="log/{tumour}.annotate_afdp_mutect2_filter.log"
  shell:
    "{config[module_samtools]} && "
    "{config[module_htslib]} && "
    "tools/vt-0.577/vt decompose -s {input.vcf} | tools/vt-0.577/vt normalize -n -r {input.reference} - -o out/{wildcards.tumour}.mutect2.filter.norm.vcf.gz && "
    "src/annotate_dp_vaf_mutect2.py {wildcards.tumour} out/{wildcards.tumour}.mutect2.filter.norm.vcf.gz | bgzip >{output} 2>{log.stderr}"

rule mutect2_vt_filter:
  input:
    "out/{tumour}.mutect2.filter.norm.af.dp.vcf.gz",
  output:
    "out/{tumour}.mutect2.filter.norm.af.dp.filter.vcf.gz",
  log:
    stderr="log/{tumour}.mutect2_vt_filter.stderr"
  shell:
    "src/vtfilter.sh {input} {output} {config[af_threshold]} {config[depth_n]} {config[depth_t]} 2>{log.stderr}"

rule annotate_vep_mutect2:
  input:
    vcf="out/{tumour}.mutect2.filter.norm.af.dp.filter.vcf.gz",
    reference=config['genome']
  output:
    "out/{tumour}.mutect2.filter.norm.af.dp.filter.vep.vcf.gz"
  log:
    "log/{tumour}.annotate_vep_mutect2.log"
  params:
    cores=cluster["annotate_vep_mutect2"]["n"]
  shell:
    "{config[module_samtools]} && "
    "{config[module_htslib]} && "
    "{config[module_bedtools]} && "
    "src/annotate.sh {input.vcf} {output} {input.reference} {params.cores} 2>{log}"

rule annotate_vep_germline:
  input:
    vcf="out/{germline}.strelka.germline.filter_gt.vcf.gz",
    reference=config['genome']
  output:
    "out/{germline}.strelka.germline.filter_gt.vep.vcf.gz"
  log:
    "log/{germline}.strelka.vep.log"
  params:
    cores=cluster["annotate_vep_germline"]["n"]
  shell:
    "{config[module_samtools]} && "
    "src/annotate.sh {input.vcf} {output} {input.reference} {params.cores} 2>{log}"

rule intersect_somatic_callers:
  input:
    reference=config["genome"],
    mutect2="out/{tumour}.mutect2.filter.norm.af.dp.vcf.gz",
    strelka_snvs="out/{tumour}.strelka.somatic.snvs.af.dp.vcf.gz",
    strelka_indels="out/{tumour}.strelka.somatic.indels.af.dp.vcf.gz"
  output:
    "out/{tumour}.intersect.vcf.gz",
    "tmp/{tumour}.intersect.vcf"
  log:
    stderr="log/{tumour}.intersect.log"
  shell:
    #.mutect2.filter.norm.af.dp.filter.vep.vcf.gz
    #.strelka.somatic.snvs.af.dp.filtered.vep.vcf.gz
    #"({config[module_samtools]} && "
    #"{config[module_htslib]} && "
    #"{config[module_bedtools]} && "
    "python src/vcf_intersect.py --allowed_filters str_contraction LowDepth --inputs {input.strelka_snvs} {input.mutect2} > tmp/{wildcards.tumour}.intersect.unsorted.vcf && "
    "python src/vcf_intersect.py --allowed_filters str_contraction LowDepth --inputs {input.strelka_indels} {input.mutect2} | sed -n '/^#/!p' >> tmp/{wildcards.tumour}.intersect.unsorted.vcf && "
    "grep '^#' tmp/{wildcards.tumour}.intersect.unsorted.vcf > tmp/{wildcards.tumour}.intersect.vcf && "
    "bedtools sort < tmp/{wildcards.tumour}.intersect.unsorted.vcf >> tmp/{wildcards.tumour}.intersect.vcf && "
    "src/vtfilter.sh tmp/{wildcards.tumour}.intersect.vcf tmp/{wildcards.tumour}.intersect.filter.vcf {config[af_threshold]} {config[depth_n]} {config[depth_t]} && "
    "bgzip < tmp/{wildcards.tumour}.intersect.filter.vcf > {output[0]}"
    " 2>{log.stderr}"

#######
#######
#######
rule intersect_to_maf:
  input:
    vcf="out/{tumour}.intersect.vcf.gz",
    vcf_unfiltered="tmp/{tumour}.intersect.vcf",
    reference=config['genome'],
    bams=tumour_germline_dup_bams
  output:
    vep="tmp/{tumour}.intersect.vep.vcf",
    maf="out/mafs/{tumour}.intersect.maf"
  log:
    stderr="log/{tumour}.intersect.maf.log"
  params:
    cores=cluster["annotate_vep_intersect"]["n"],
    #germline=germline_sample
    germline=lambda wildcards: samples["tumours"][wildcards.tumour]
  shell:
    #"{config[module_samtools]} && "
    "{config[module_perl]} && "
    "{config[module_intel]} && "
    #"src/vcf_to_maf.sh {input.vcf} {output.vep} {input.reference} {output.maf} {wildcards.tumour} 2>{log}"
    "src/vcf_to_maf.sh {input.vcf_unfiltered} {output.vep} {input.reference} {output.maf} {wildcards.tumour} {params.germline} 2>{log}"
    #"src/vcf_to_maf.sh {input.vcf} {output.vep} {input.reference} {output.maf} {params.cores} 2>{log}"

rule vardict_to_maf:
  input:
    vcf="out/vardict/{tumour}.vardict.annotated.vcf.gz",
    vcf_filtered="tmp/{tumour}.vardict.filtered.vcf",
    reference=config['genome'],
    #bams=tumour_germline_dup_bams
  output:
    vep="tmp/{tumour}.vardict.filtered.vep.vcf",
    maf="out/vardict/{tumour}.vardict.maf"
  log:
    stderr="log/{tumour}.vardict.maf.log"
  params:
    cores=cluster["annotate_vardict"]["n"],
    #germline=germline_sample
    germline=lambda wildcards: samples["tumours"][wildcards.tumour]
  shell:
    #"{config[module_samtools]} && "
    "{config[module_perl]} && "
    "{config[module_intel]} && "
    #"src/vcf_to_maf.sh {input.vcf} {output.vep} {input.reference} {output.maf} {wildcards.tumour} 2>{log}"
    "src/vcf_to_maf.sh {input.vcf_filtered} {output.vep} {input.reference} {output.maf} {wildcards.tumour} {params.germline} 2>{log}"
    #"src/vcf_to_maf.sh {input.vcf} {output.vep} {input.reference} {output.maf} {params.cores} 2>{log}"

rule filter_maf:
  input:
    maf = "out/mafs/{tumour}.intersect.maf",
  output:
    maf_mmr = "out/mafs/{tumour}.intersect.mmr.maf",
    maf_pol = "out/mafs/{tumour}.intersect.pol.maf",
    maf_braf_kras = "out/mafs/{tumour}.intersect.braf_kras.maf",
    maf_other = "out/mafs/{tumour}.intersect.other.maf",
  log:
    stderr="log/{tumour}.filter.maf.log"
  shell:
    "python src/filter_maf.py --maf {input.maf} 2>{log}"

rule maf_vaf_plot:
  input:
    maf = "out/mafs/{tumour}.intersect.maf",
  output:
    maf_vaf_plot = "out/mafs/{tumour}.intersect.vaf.png",
  log:
    stderr="log/{tumour}.maf.vaf.log"
  shell:
    "python src/plot_vaf.py --maf {input.maf} --sample {wildcards.tumour} --target {output.maf_vaf_plot} --vaf 0.1 2>{log}"
#######
#######
#######

rule strelka_normalise:
  input:
    reference=config["genome"],
    #mutect2="out/{tumour}.mutect2.filter.norm.vep.vcf.gz",
    strelka_snvs="out/{tumour}.strelka.somatic.snvs.vcf.gz",
    strelka_indels="out/{tumour}.strelka.somatic.indels.vcf.gz"
  output:
    snvs_norm="out/{tumour}.strelka.somatic.snvs.norm.vcf.gz",
    indels_norm="out/{tumour}.strelka.somatic.indels.norm.vcf.gz"
  shell:
    "{config[module_samtools]} && "
    "{config[module_htslib]} && "
    "tools/vt-0.577/vt decompose -s {input.strelka_snvs} | tools/vt-0.577/vt normalize -n -r {input.reference} - -o {output.snvs_norm} && "
    "tools/vt-0.577/vt decompose -s {input.strelka_indels} | tools/vt-0.577/vt normalize -n -r {input.reference} - -o {output.indels_norm}"

rule bias_filter_strelka_indels:
  input:
    reference=config["genome"],
    bam="out/{tumour}.sorted.dups.bam",
    vcf="out/{tumour}.strelka.somatic.indels.vcf.gz"
  output:
    "out/{tumour}.strelka.somatic.indels.bias.vcf.gz"
  log:
    stderr="log/{tumour}.bias_filter.indels.bias.err",
    stdout="log/{tumour}.bias_filter.indels.bias.out"
  shell:
    "{config[module_htslib]} && "
    "gunzip < {input.vcf} | egrep '(^#|PASS)' > tmp/{wildcards.tumour}_bias_filter_strelka.vcf && "
    "python tools/DKFZBiasFilter/scripts/biasFilter.py --tempFolder tmp tmp/{wildcards.tumour}_bias_filter_strelka_indels.vcf {input.bam} {input.reference} tmp/{wildcards.tumour}_bias_filter_out_strelka_indels.vcf 2>{log.stderr} 1>{log.stdout} && "
    "bgzip < tmp/{wildcards.tumour}_bias_filter_out_strelka_indels.vcf > {output} && "
    "rm tmp/{wildcards.tumour}_bias_filter_strelka_indels.vcf tmp/{wildcards.tumour}_bias_filter_out_strelka_indels.vcf"

rule bias_filter_strelka:
  input:
    reference=config["genome"],
    bam="out/{tumour}.sorted.dups.bam",
    vcf="out/{tumour}.strelka.somatic.snvs.vcf.gz"
  output:
    "out/{tumour}.strelka.somatic.snvs.bias.vcf.gz"
  log:
    stderr="log/{tumour}.bias_filter.snvs.bias.err",
    stdout="log/{tumour}.bias_filter.snvs.bias.out"
  shell:
    "{config[module_htslib]} && "
    "gunzip < {input.vcf} | egrep '(^#|PASS)' > tmp/{wildcards.tumour}_bias_filter_strelka.vcf && "
    "python tools/DKFZBiasFilter/scripts/biasFilter.py --tempFolder tmp tmp/{wildcards.tumour}_bias_filter_strelka.vcf {input.bam} {input.reference} tmp/{wildcards.tumour}_bias_filter_out_strelka.vcf 2>{log.stderr} 1>{log.stdout} && "
    "bgzip < tmp/{wildcards.tumour}_bias_filter_out_strelka.vcf > {output} && "
    "rm tmp/{wildcards.tumour}_bias_filter_strelka.vcf tmp/{wildcards.tumour}_bias_filter_out_strelka.vcf"

rule bias_filter_mutect2:
  input:
    reference=config["genome"],
    bam="out/{tumour}.sorted.dups.bam",
    vcf="out/{tumour}.mutect2.filter.vcf.gz"
  output:
    "out/{tumour}.mutect2.filter.bias.vcf.gz"
  log:
    stderr="log/{tumour}.bias_filter.mutect2.bias.err",
    stdout="log/{tumour}.bias_filter.mutect2.bias.out"
  shell:
    "{config[module_htslib]} && "
    "gunzip < {input.vcf} | egrep '(^#|PASS)' > tmp/{wildcards.tumour}_bias_filter_mutect2.vcf && "
    "python tools/DKFZBiasFilter/scripts/biasFilter.py --tempFolder tmp tmp/{wildcards.tumour}_bias_filter_mutect2.vcf {input.bam} {input.reference} tmp/{wildcards.tumour}_bias_filter_out_mutect2.vcf 2>{log.stderr} 1>{log.stdout} && "
    "bgzip < tmp/{wildcards.tumour}_bias_filter_out_mutect2.vcf > {output} && "
    "rm tmp/{wildcards.tumour}_bias_filter_mutect2.vcf tmp/{wildcards.tumour}_bias_filter_out_mutect2.vcf"

rule combine_mutect2_tsv:
  input:
    expand("out/{tumour}.mutect2.filter.norm.af.dp.filter.vep.tsv", tumour=config['tumours'])
  output:
    "out/aggregate/mutect2.combined.tsv"
  shell:
    "src/combine_tsv_raw.py {input} | sed 's/^out\\/\\([^.]*\\)\\.[^\\t]*/\\1/' > {output}"

rule mutect2_tsv:
  input:
    vcf="out/{tumour}.mutect2.filter.norm.af.dp.filter.vep.vcf.gz"
  output:
    "out/{tumour}.mutect2.filter.norm.af.dp.filter.vep.tsv"
  shell:
    "src/vcf2tsv.py {input.vcf} | "
    "src/extract_vep.py --header 'Consequence|IMPACT|Codons|Amino_acids|Gene|SYMBOL|Feature|EXON|PolyPhen|SIFT|Protein_position|BIOTYPE|HGVSc|HGVSp|cDNA_position|CDS_position|HGVSc|HGVSp|cDNA_position|CDS_position|gnomAD_AF|gnomAD_AFR_AF|gnomAD_AMR_AF|gnomAD_ASJ_AF|gnomAD_EAS_AF|gnomAD_FIN_AF|gnomAD_NFE_AF|gnomAD_OTH_AF|gnomAD_SAS_AF|MaxEntScan_alt|MaxEntScan_diff|MaxEntScan_ref|PICK' >{output}"

rule combine_genes_of_interest:
  input:
    expand("out/{tumour}.mutect2.filter.genes_of_interest.tsv", tumour=config['tumours']),
  output:
    "out/aggregate/mutect2.genes_of_interest.combined.tsv"
  shell:
    "src/combine_tsv_raw.py {input} | sed 's/^out\\/\\([^.]*\\)\\.[^\\t]*/\\1/' > {output}"

# filter on genes of interest and convert to tsv
rule filter_genes_of_interest_tumour:
  input:
    vcf="out/{tumour}.mutect2.filter.norm.af.dp.filter.vep.vcf.gz"
  output:
    "out/{tumour}.mutect2.filter.genes_of_interest.tsv"
  log:
    stderr="log/{tumour}.filter_genes_of_interest_tumour.err"
  params:
    gene_list=' '.join(config["genes_of_interest"])
  shell:
    "src/vcf2tsv.py {input.vcf} | "
    "src/extract_vep.py --header 'Consequence|IMPACT|Codons|Amino_acids|Gene|SYMBOL|Feature|EXON|PolyPhen|SIFT|Protein_position|BIOTYPE|HGVSc|HGVSp|cDNA_position|CDS_position|HGVSc|HGVSp|cDNA_position|CDS_position|gnomAD_AF|gnomAD_AFR_AF|gnomAD_AMR_AF|gnomAD_ASJ_AF|gnomAD_EAS_AF|gnomAD_FIN_AF|gnomAD_NFE_AF|gnomAD_OTH_AF|gnomAD_SAS_AF|MaxEntScan_alt|MaxEntScan_diff|MaxEntScan_ref|PICK' | "
    "src/filter_tsv.py --column vep_SYMBOL --values {params.gene_list} > {output}"

# VarDict
rule vardict:
  input:
    reference=config["genome"],
    bams=tumour_germline_bams,
    bed=config["regions"]
    # interval=rules.genome_interval.output
  output:
    "out/vardict/{tumour}.vardict.vcf"
  params:
    cores=cluster["vardict"]["n"],
    # mem=cluster["mem"]["n"]
  shell:
    "{config[module_R]} && "
    "{config[module_java]} && "
    "tools/VarDict-{config[vardict_version]}/bin/VarDict \
    -G {input.reference} \
    -f {config[af_threshold]} \
    -b '{input.bams[0]}|{input.bams[1]}' \
    -Q 1 \
    -c 1 \
    -S 2 \
    -E 3 \
    -g 4 \
    -th {params.cores} \
    {input.bed} | tools/VarDict-{config[vardict_version]}/bin/testsomatic.R | tools/VarDict-{config[vardict_version]}/bin/var2vcf_paired.pl -N 'TUMOR|NORMAL' -f {config[af_threshold]} > {output}"

#msi sensor
rule msisensor_prep:
  input:
    reference=config["genome"]
  output:
    "out/msisensor.list"
  log:
    stderr="log/msisensor.list.log"
  shell:
    "tools/msisensor-{config[msisensor_version]}/binary/msisensor.linux scan -d {input.reference} -l 8 -m 35 -o {output}"

rule msisensor:
  input:
    microsatellites="out/msisensor.list",
    bed=config["regions_msi"],
    bams=tumour_germline_bams
  output:
    "out/{tumour}.msisensor.tsv"
  log:
    stderr="log/{tumour}.msisenser.stderr"
  params:
    tumour="{tumour}",
  shell:
    "tools/msisensor-{config[msisensor_version]}/binary/msisensor.linux msi -d {input.microsatellites} -n {input.bams[1]} -t {input.bams[0]} -e {input.bed} -o tmp/{params.tumour}.msisensor && "
    "mv tmp/{params.tumour}.msisensor out/{params.tumour}.msisensor.tsv"

rule msisensor_combine:
  input:
    expand("out/{tumour}.msisensor.tsv", tumour=config['tumours']),
  output:
    "out/aggregate/msisensor.tsv"
  shell:
    "src/combine_msisensor.py {input} > {output}"

# MANTIS (Microsatellite Analysis for Normal-Tumor InStability)
rule mantis:
  input:
    reference=config["genome"],
    bed=config["regions_mantis"],
    bams=tumour_germline_bams
  output:
    # "out/{tumour}.mantis.tsv"
    tmp="tmp/{tumour}.mantis",
    tsv="out/{tumour}.mantis.status"
    # tsv="out/aggregate/mantis.tsv"
  log:
    stderr="log/{tumour}.mantis.stderr"
  params:
    tumour="{tumour}",
  shell:
    # "python tools/MANTIS-master/mantis.py --bedfile {config[msisensor_version]} --genome {input.reference} -n {input.bams[1]} -t {input.bams[0]} -o tmp/{params.tumour}.mantis && "
    # "grep '^Step-Wise' tmp/{params.tumour}.mantis.status | awk 'BEGIN {FS=\"\t\"; OFS=\"\t\"} { print {params.tumour}\"\t\"$2 }' >> {output}"
    "python tools/MANTIS-master/mantis.py --bedfile {input.bed} --genome {input.reference} -n {input.bams[1]} -t {input.bams[0]} -o {output.tmp} && "
    "grep '^Step-Wise' {output.tmp}.status > {output.tsv} "
    # "mv {output.tmp}.status {output.tsv}"
    # "mv {output.tmp}.status {output.tsv} "
    # "grep '^Step-Wise' {output.tmp}.status | awk 'BEGIN {FS=\"\t\"; OFS=\"\t\"} { print {params.tumour}\"\t\"$2 }' >> {output.tsv}"

rule mantis_combine:
  input:
    expand("out/{tumour}.mantis.status", tumour=config['tumours']),
  output:
    "out/aggregate/mantis.tsv"
  shell:
    "src/combine_mantis.py {input} > {output}"

# mutational signatures
rule mutational_signature:
  input:
    reference=config["genome"],
    vcf="out/{tumour}.intersect.vcf.gz"
  output:
    "out/{tumour}.mutational_signature.exposures"
  log:
    stderr="out/{tumour}.mutational_signature.stderr", # keep for now
  shell:
    "(python tools/mutational_signature-0.4/mutational_signature/count.py --genome {input.reference} --vcf {input.vcf} > out/{wildcards.tumour}.mutational_signature.counts && "
    "python tools/mutational_signature-0.4/mutational_signature/plot_counts.py out/{wildcards.tumour}.mutational_signature.png < out/{wildcards.tumour}.mutational_signature.counts && "
    "python tools/mutational_signature-0.4/mutational_signature/decompose.py --context_cutoff 0.2 --signatures tools/mutational_signature-0.4/signatures30.txt --counts out/{wildcards.tumour}.mutational_signature.counts > {output}) 2>{log.stderr}"

rule combine_mutational_signatures:
  input:
    expand("out/{tumour}.mutational_signature.exposures", tumour=config['tumours']),
  output:
    "out/aggregate/mutational_signatures.combined"
  shell:
    "python src/combine_tsv.py {input} | sed 's/^out\\/\\(.*\)\\.mutational_signature\\.exposures/\\1/' > {output}"

rule combine_mutational_signatures_filtered:
  input:
    expand("out/{tumour}.mutational_signature.exposures", tumour=config['tumours']),
  output:
    "out/aggregate/mutational_signatures.filter.combined"
  shell:
    "src/combine_tsv.py {input} | sed 's/^out\\/\\(.*\)\\.mutational_signature\\.exposures/\\1/' >{output} && "
    "python tools/mutational_signature-0.4/mutational_signature/plot_components.py --threshold 0.05 --show_signature --target {output}.png --order 'Signature.1' 'Signature.2' 'Signature.3' 'Signature.4' 'Signature.5' 'Signature.6' 'Signature.7' 'Signature.8' 'Signature.9' 'Signature.10' 'Signature.11' 'Signature.12' 'Signature.13' 'Signature.14' 'Signature.15' 'Signature.16' 'Signature.17' 'Signature.18' 'Signature.19' 'Signature.20' 'Signature.21' 'Signature.22' 'Signature.23' 'Signature.24' 'Signature.25' 'Signature.26' 'Signature.27' 'Signature.28' 'Signature.29' 'Signature.30' --descriptions '5-methylcytosine deamination' 'APOBEC' 'double-strand break-repair failure' 'tobacco mutagens' '' 'defective mismatch repair' 'ultraviolet light exposure' '' '' 'POLE mutations' 'alkylating agents' '' 'APOBEC' '' 'defective mismatch repair' '' '' '' '' 'defective mismatch repair' '' '' '' 'aflatoxin exposure' '' 'defective mismatch repair' '' '' 'tobacco' '' < {output}"

# mutational signtarues v3

# mutational signatures with filtered counts
rule mutational_signature_v3:
  input:
    reference=config["genome"],
    vcf="out/{tumour}.intersect.vcf.gz"
  output:
    sbs="out/{tumour}.mutational_signature_v3_sbs.exposures",
    dbs="out/{tumour}.mutational_signature_v3_dbs.exposures",
    id="out/{tumour}.mutational_signature_v3_id.exposures"
  log:
    stderr="out/{tumour}.mutational_signature_v3.stderr" # keep for now
  shell:
    "(python tools/mutational_signature-{config[signature_version]}/mutational_signature/count.py --indels --doublets --genome {input.reference} --vcf {input.vcf} > out/{wildcards.tumour}.mutational_signature_v3.counts && "
    "python tools/mutational_signature-{config[signature_version]}/mutational_signature/decompose.py --signatures tools/mutational_signature-{config[signature_version]}/data/signatures_cosmic_v3_sbs.txt --counts out/{wildcards.tumour}.mutational_signature_v3.counts > {output.sbs} && "
    "python tools/mutational_signature-{config[signature_version]}/mutational_signature/decompose.py --signatures tools/mutational_signature-{config[signature_version]}/data/signatures_cosmic_v3_id.txt --counts out/{wildcards.tumour}.mutational_signature_v3.counts > {output.id} && "
    "python tools/mutational_signature-{config[signature_version]}/mutational_signature/decompose.py --signatures tools/mutational_signature-{config[signature_version]}/data/signatures_cosmic_v3_dbs.txt --counts out/{wildcards.tumour}.mutational_signature_v3.counts > {output.dbs}) 2>{log.stderr}"

# mutational signatures with filtered counts
rule mutational_signature_filtered_v3:
  input:
    reference=config["genome"],
    vcf="out/{tumour}.intersect.vcf.gz"
    #vcf="out/{tumour}.intersect.pass.filter.vcf.gz"
  output:
    sbs="out/{tumour}.mutational_signature_v3_sbs.filter.exposures",
    dbs="out/{tumour}.mutational_signature_v3_dbs.filter.exposures",
    id="out/{tumour}.mutational_signature_v3_id.filter.exposures"
  log:
    stderr="out/{tumour}.mutational_signature_v3_filter.stderr"
  shell:
    "(python tools/mutational_signature-{config[signature_version]}/mutational_signature/count.py --indels --doublets --genome {input.reference} --vcf {input.vcf} > out/{wildcards.tumour}.mutational_signature_v3.filter.counts && "
    "python tools/mutational_signature-{config[signature_version]}/mutational_signature/decompose.py --signatures tools/mutational_signature-{config[signature_version]}/data/signatures_cosmic_v3_sbs.txt --counts out/{wildcards.tumour}.mutational_signature_v3.filter.counts > {output.sbs} && "
    "python tools/mutational_signature-{config[signature_version]}/mutational_signature/decompose.py --signatures tools/mutational_signature-{config[signature_version]}/data/signatures_cosmic_v3_id.txt --counts out/{wildcards.tumour}.mutational_signature_v3.filter.counts > {output.id} && "
    "python tools/mutational_signature-{config[signature_version]}/mutational_signature/decompose.py --signatures tools/mutational_signature-{config[signature_version]}/data/signatures_cosmic_v3_dbs.txt --counts out/{wildcards.tumour}.mutational_signature_v3.filter.counts > {output.dbs}) 2>{log.stderr}"

# mutational signatures with filtered counts
rule mutational_signature_filtered_v3_id:
  input:
    reference=config["genome"],
    #vcf="out/{tumour}.strelka.somatic.indels.norm.vep.pass.af.filter.vcf.gz"
    vcf="out/{tumour}.strelka.somatic.indels.af.dp.filtered.vep.vcf.gz"
  output:
    id="out/{tumour}.mutational_signature_v3_id_strelka.filter.exposures"
  log:
    stderr="out/{tumour}.mutational_signature_v3_strelka.stderr", # keep for now
  shell:
    "(python tools/mutational_signature-{config[signature_version]}/mutational_signature/count.py --indels --just_indels --genome {input.reference} --vcf {input.vcf} > out/{wildcards.tumour}.mutational_signature_v3_strelka_indels.filter.counts && "
    "python tools/mutational_signature-{config[signature_version]}/mutational_signature/decompose.py --signatures tools/mutational_signature-{config[signature_version]}/data/signatures_cosmic_v3_id.txt --counts out/{wildcards.tumour}.mutational_signature_v3_strelka_indels.filter.counts > {output.id}) 2>{log.stderr}"

rule combine_mutational_signatures_filtered_v3:
  input:
    sbs=expand("out/{tumour}.mutational_signature_v3_sbs.filter.exposures", tumour=config['tumours']),
    dbs=expand("out/{tumour}.mutational_signature_v3_dbs.filter.exposures", tumour=config['tumours']),
    dbs2=expand("out/{tumour}.mutational_signature_v3_dbs.exposures", tumour=config['tumours']),
    id=expand("out/{tumour}.mutational_signature_v3_id.exposures", tumour=config['tumours']),
    id2=expand("out/{tumour}.mutational_signature_v3_id_strelka.filter.exposures", tumour=config['tumours'])
  output:
    sbs="out/aggregate/mutational_signatures_v3_sbs.filter.combined.tsv",
    dbs="out/aggregate/mutational_signatures_v3_dbs.filter.combined.tsv",
    dbs2="out/aggregate/mutational_signatures_v3_dbs.combined.tsv",
    id="out/aggregate/mutational_signatures_v3_id.combined.tsv",
    id2="out/aggregate/mutational_signatures_v3_id_strelka.filter.combined.tsv"
  shell:
    "src/combine_tsv.py {input.sbs} | sed 's/^out\\/\\(.*\)\\.mutational_signature_v3_sbs\\.filter\\.exposures/\\1/' >{output.sbs} && "
    "src/combine_tsv.py {input.dbs} | sed 's/^out\\/\\(.*\)\\.mutational_signature_v3_dbs\\.filter\\.exposures/\\1/' >{output.dbs} && "
    "src/combine_tsv.py {input.dbs2} | sed 's/^out\\/\\(.*\)\\.mutational_signature_v3_dbs\\.exposures/\\1/' >{output.dbs2} && "
    "src/combine_tsv.py {input.id} | sed 's/^out\\/\\(.*\)\\.mutational_signature_v3_id\\.exposures/\\1/' >{output.id} && "
    "src/combine_tsv.py {input.id2} | sed 's/^out\\/\\(.*\)\\.mutational_signature_v3_id_strelka\\.filter\\.exposures/\\1/' >{output.id2}"

# burden (currently only exonic snvs)
rule mutation_burden:
  input:
    vcfs=expand("out/{tumour}.intersect.vcf.gz", tumour=config['tumours']),
    regions=config["regions"],
  output:
    "out/aggregate/mutation_rate.tsv"
  log:
    stderr="log/mutation_rate.stderr"
  shell:
    "src/mutation_rate.py --verbose --vcfs {input.vcfs} --bed {input.regions} >{output} 2>{log.stderr}"

rule mutation_burden_vardict:
  input:
    vcfs=expand("out/vardict/{tumour}.vardict.annotated.vcf.gz", tumour=config['tumours']),
    regions=config["regions"],
  output:
    "out/aggregate/mutation_rate_vardict.tsv"
  log:
    stderr="log/mutation_rate_vardict.stderr"
  shell:
    "src/mutation_rate.py --verbose --vcfs {input.vcfs} --bed {input.regions} >{output} 2>{log.stderr}"

# burden (currently only exonic snvs)
rule msi_burden:
  input:
    vcfs=expand("out/{tumour}.intersect.vcf.gz", tumour=config['tumours']),
    regions="reference/msi.regions.bed"
  output:
    "out/aggregate/msi_burden.tsv"
  log:
    stderr="log/msi_burden.stderr"
  shell:
    "src/mutation_rate.py --verbose --vcfs {input.vcfs} --bed {input.regions} --indels_only >{output} 2>{log.stderr}"

# af distribution
rule plot_af_strelka:
  input:
    "out/{tumour}.strelka.somatic.snvs.af.vcf.gz"
  output:
    "out/{tumour}.strelka.somatic.af.png"
  shell:
    "python src/plot_af.py --log --sample TUMOR --target {output} --dp {config[dp_threshold]} --info_af < {input}"

rule plot_af_mutect2:
  input:
    "out/{tumour}.mutect2.filter.norm.af.dp.filter.vep.vcf.gz"
  output:
    "out/{tumour}.mutect2.somatic.af.png"
  shell:
    "python src/plot_af.py --log --sample {wildcards.tumour} --target {output} --dp {config[dp_threshold]} < {input}"

# loh
rule loh:
  input:
    snvs="out/{tumour}.strelka.somatic.snvs.af.dp.filtered.vep.vcf.gz", # loh requires strelka for now
    indels="out/{tumour}.strelka.somatic.indels.af.dp.filtered.vep.vcf.gz"
  output:
    "out/{tumour}.loh.bed"
  log:
    stderr="log/{tumour}.loh.stderr"
  params:
    tumour="{tumour}",
    regions=' '.join(config["loh_regions"]),
    region_names=' '.join(config["loh_region_names"]),
    region_padding=' '.join(config["loh_region_padding"])
  shell:
    "(tools/loh_caller-{config[loh_version]}/loh.py --germline NORMAL --tumour TUMOR --filtered_variants --min_dp_germline 10 --min_dp_tumour 20 --neutral --min_af 0.1 < {input.snvs} > tmp/{params.tumour}.loh.snvs.tsv && "
    "tools/loh_caller-{config[loh_version]}/loh.py --germline NORMAL --tumour TUMOR --filtered_variants --min_dp_germline 10 --min_dp_tumour 20 --neutral --min_af 0.1 < {input.indels} > tmp/{params.tumour}.loh.indels.tsv && "
    "sort -k1,1 -k2,2n tmp/{params.tumour}.loh.snvs.tsv tmp/{params.tumour}.loh.indels.tsv > tmp/{params.tumour}.loh.tsv && "
    "tools/loh_caller-{config[loh_version]}/loh_merge.py --verbose --noheader --min_len 1000 --min_prop 0.1 --plot out/{params.tumour}.loh --regions {params.regions} --region_names {params.region_names} --region_padding {params.region_padding} --plot_chromosomes <tmp/{params.tumour}.loh.tsv >{output}) 2>{log.stderr}"
