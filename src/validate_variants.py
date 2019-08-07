#!/usr/bin/env python
'''
  TODO INCOMPLETE
  write out details of a variant if found
'''

import argparse
import collections
import logging
import sys

import cyvcf2

def main(samples):

  lines = []
  locations = collections.defaultdict(dict)
  for line in open(samples, 'r'):
    sample, chrom, pos = line.strip('\n').split('\t')
    if pos not in locations[chrom]:
      locations[chrom][pos] = []
    locations[chrom][pos].append(len(lines))
    lines.append([sample, chrom, pos, '0'])

  logging.info('reading from stdin...')

  vcf_in = cyvcf2.VCF('-')  
  sample_id = vcf_in.samples.index(sample)

  for variant in vcf_in:
    if variant.FILTER is not None:
      continue

    if variant.POS in locations[chrom]:
      # check gt 0,1,2,3==HOM_REF, HET, UNKNOWN, HOM_ALT
      gt = variant.gt_types[sample_id]
      if gt == 1 or gt == 3:
        sys.stdout.write('{}\t{}\t{}\t{}\n'.format(sample, chrom, pos, '1'))
        logging.info('done')
        sys.exit(0)

  sys.stdout.write('{}\t{}\t{}\t{}\n'.format(sample, chrom, pos, '0'))
  logging.info('done')

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='Max coverage')
  parser.add_argument('--samples', required=True, help='file containing sample<tab>chrom<tab>pos')
  parser.add_argument('--verbose', action='store_true', help='more logging')
  args = parser.parse_args()
  if args.verbose:
    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=logging.DEBUG)
  else:
    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=logging.INFO)

  main(args.samples)
