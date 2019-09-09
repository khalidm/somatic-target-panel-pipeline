#!/usr/bin/env bash
#
# usage:
# $0 input_vcf output_vcf reference threads

set -e

echo "starting vt at $(date)"

#module load perl/5.18.0
module load SAMtools/1.8-intel-2016.u3-HTSlib-1.8
module load Vt/0.5772-spartan_gcc-6.2.0

INPUT=$1
OUTPUT=$2
VAF_THRESHOLD=$3
DEPTH_N=$4
DEPTH_T=$5

THREADS=1 # ignore threads parameter due to vep errors

#tools/vt-0.577/vt view -h -f "INFO.DP_N>=10&&INFO.DP_T>=20&&INFO.VAF>=0.075" ${INPUT} | bgzip > ${OUTPUT}
tools/vt-0.577/vt view -h -f "INFO.DP_N>=${DEPTH_N}&&INFO.DP_T>=${DEPTH_T}&&INFO.VAF>=${VAF_THRESHOLD}" ${INPUT} | bgzip > ${OUTPUT}

echo "finishing vep at $(date)"
