# Somatic target panel pipeline
Somatic variant calling pipeline for targeted sequencing for the Colorectal Oncogenomics Group. Based on https://github.com/supernifty/somatic_pipeline.

## Installation
* Python 3 is required.

Additional libraries required:
* curl

```
python -m venv somatic_venv
. ./somatic_venv/bin/activate
pip install -r requirements.txt
```

## Spartan
Before starting:
```
module load Python/3.6.1-intel-2017.u2
module load cURL/7.58.0-intel-2017.u2
module load icc
. ../../../software/venv_somatic_2/bin/activate
```

In config.yaml
```
module_bedtools: 'module load BEDTools/2.26.0-intel-2016.u3'
module_bwa: 'module load BWA/0.7.17-intel-2016.u3'
module_htslib: 'module load HTSlib/1.8-intel-2017.u2'
module_java: 'module load Java/1.8.0_152'
module_python2: 'module load Python/2.7.13-intel-2017.u2'
module_R: 'module load R/3.5.0-GCC-6.2.0'
module_samtools: 'module load SAMtools/1.8-intel-2016.u3-HTSlib-1.8'
module_network: 'module load web_proxy'
```

## Dependencies
* reference/genome.fa: this file needs to be bwa indexed.
* reference/msi.regions.bed: TODO
* reference/regions.bed: this is the target gene panel bed file

Modules
* bwa
* java
* samtools

Tools directory
* picard

## TODO
* list tools and version
