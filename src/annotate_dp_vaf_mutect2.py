#!/usr/bin/env python
'''
  calculate dp and vaf for mutect2
'''

import logging
import sys

import numpy

import cyvcf2

def main(vcf_fn):
  '''
    refCounts = Value of FORMAT column $REF + "U" (e.g. if REF="A" then use the value in FOMRAT/AU)
    altCounts = Value of FORMAT column $ALT + "U" (e.g. if ALT="T" then use the value in FOMRAT/TU)
    tier1RefCounts = First comma-delimited value from $refCounts
    tier1AltCounts = First comma-delimited value from $altCounts
    Somatic allele freqeuncy is $tier1AltCounts / ($tier1AltCounts + $tier1RefCounts)
  '''

  logging.info('reading %s...', vcf_fn)

  vcf_in = cyvcf2.VCF(vcf_fn)  
  vcf_in.add_info_to_header({'ID': 'VAF', 'Description': 'Calculated variant allele frequency', 'Type':'Float', 'Number': '1'})
  vcf_in.add_info_to_header({'ID': 'DP_N', 'Description': 'Read depth in Normal sample', 'Type':'Integer', 'Number': '1'})
  vcf_in.add_info_to_header({'ID': 'DP_T', 'Description': 'Read depth in Tumor sample', 'Type':'Integer', 'Number': '1'})

  sys.stdout.write(vcf_in.raw_header)

  #sample_id = vcf_in.samples.index(sample)

  variant_count = 0
  for variant_count, variant in enumerate(vcf_in):
    # GT:AD:AF:F1R2:F2R1:MBQ:MFRL:MMQ:MPOS:SA_MAP_AF:SA_POST_PROB

    format_af = variant.format('AF')
    format_ad = variant.format('AD')
    if len(variant.ALT) > 1:
      logging.warn('%s: variant %i is multi-allelic', vcf_fn, variant_count + 1)

    vaf_tumour = format_af
    #vaf = format_ad[1][0]
    dp_norm = int(format_ad[0][0]) + int(format_ad[0][1])
    dp_tumor = int(format_ad[1][0]) + int(format_ad[1][1])

    #print("--" + str(dp_norm) + "\t" + str(dp_tumor))

    variant.INFO["DP_N"] = int(dp_norm)
    variant.INFO["DP_T"] = int(dp_tumor)
    variant.INFO["VAF"] = float(vaf_tumour[1][0])

    sys.stdout.write(str(variant))

    if (variant_count + 1 ) % 100000 == 0:
      logging.info('reading %s: %i variants processed...', vcf_fn, variant_count + 1)

  logging.info('reading %s: processed %i variants', vcf_fn, variant_count + 1)

if __name__ == '__main__':
  logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=logging.DEBUG)
  main(sys.argv[1])
