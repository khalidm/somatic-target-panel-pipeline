#!/usr/bin/env python
'''
  given tumour and normal vcf pairs, explore msi status
'''

import argparse
import logging
import os
import sys

def run(cmd):
  logging.debug('running %s...', cmd)
  os.system(cmd)
  logging.debug('running %s: done', cmd)

def main(bed, bam):
  logging.info('starting...')
  run('sort -k1,1 -k2,2n {bed} | bedtools merge -i - | bedtools coverage -sorted -a stdin -b {bam} -d | cut -f6 | src/stats.py'.format(bed=bed, bam=bam))
  logging.info('done')

if __name__ == '__main__':
  parser = argparse.ArgumentParser(description='Assess MSI')
  parser.add_argument('--bed', required=True, help='target regions')
  parser.add_argument('--bam', required=True, help='input bam')
  parser.add_argument('--verbose', action='store_true', help='more logging')
  args = parser.parse_args()
  if args.verbose:
    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=logging.DEBUG)
  else:
    logging.basicConfig(format='%(asctime)s %(levelname)s %(message)s', level=logging.INFO)

  main(args.bed, args.bam)
