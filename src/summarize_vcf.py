#!/usr/bin/env python
'''
  
'''

import logging
import sys

import numpy

import cyvcf2

def main(sample, vcf_fn):
  '''
    refCounts = Value of FORMAT column $REF + “U” (e.g. if REF="A" then use the value in FOMRAT/AU)
    altCounts = Value of FORMAT column $ALT + “U” (e.g. if ALT="T" then use the value in FOMRAT/TU)
    tier1RefCounts = First comma-delimited value from $refCounts
    tier1AltCounts = First comma-delimited value from $altCounts
    Somatic allele freqeuncy is $tier1AltCounts / ($tier1AltCounts + $tier1RefCounts)
  '''

  logging.info('reading %s...', vcf_fn)

  vcf_in = cyvcf2.VCF(vcf_fn)  

  sample_id = vcf_in.samples.index(sample)

  variant_count = 0
  skipped = 0
  sys.stdout.write('{}\n'.format('af'))
  for variant_count, variant in enumerate(vcf_in):
    # GL000220.1      135366  .       T       C       .       LowEVS;LowDepth SOMATIC;QSS=1;TQSS=1;NT=ref;QSS_NT=1;TQSS_NT=1;SGT=TT->TT;DP=2;MQ=60.00;MQ0=0;ReadPosRankSum=0.00;SNVSB=0.00;SomaticEVS=0.71    DP:FDP:SDP:SUBDP:AU:CU:GU:TU    1:0:0:0:0,0:0,0:0,0:1,1 1:0:0:0:0,0:1,1:0,0:0,0
    if (variant_count + 1 ) % 100000 == 0:
      logging.info('reading %s: %i variants processed...', vcf_fn, variant_count + 1)

    if variant.FILTER is not None: # PASS only
      skipped += 1
      continue

    af = variant.format("AF") 
    if af is None:
      tier1RefCounts = variant.format('{}U'.format(variant.REF))
      tier1AltCounts = variant.format('{}U'.format(variant.ALT[0])) # assume not multiallelic
      if len(variant.ALT) > 1:
        logging.warn('%s: variant %i is multi-allelic', vcf_fn, variant_count + 1)

      altCount = refCount = 0
      for idx, refCountList in enumerate(tier1RefCounts):
        altCount += int(tier1AltCounts[idx][0])
        refCount += int(refCountList[0])

      if refCount + altCount == 0:
        af = 0.0
      else:
        af = 1.0 * altCount / (altCount + refCount)
    else:
      af = af[sample_id][0]

    sys.stdout.write('{}\n'.format(af))

  logging.info('reading %s: processed %i variants. skipped %i', vcf_fn, variant_count + 1, skipped)

if __name__ == '__main__':
  logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=logging.DEBUG)
  # sample, vcf
  main(sys.argv[1], sys.argv[2])
