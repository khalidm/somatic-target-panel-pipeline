#!/usr/bin/env python

import collections
import sys

def process():
  keys = set()
  vals = collections.defaultdict(dict)
  for filename in sys.argv[1:]:
    for line in open(filename, 'r'):
      fields = line.strip('\n').split('\t')
      if len(fields) >= 2:
        vals[filename][fields[0]] = fields[1]
        keys.add(fields[0])
  
  #print(keys)
  #sorted_keys = sorted(keys, key=lambda x: int("".join([i for i in x if i.isdigit()])))
  #print(sorted_keys)

  # now print it all
  sys.stdout.write('Filename\t{}\n'.format('\t'.join(sorted(keys))))
  #sys.stdout.write('Filename\t{}\n'.format('\t'.join(sorted_keys)))
  #exit()
  
  for filename in sorted(sys.argv[1:]):
    line = []
    line.append(filename)
    for key in sorted(keys):
      if key in vals[filename]:
        line.append(vals[filename][key])
      else:
        line.append('')
    sys.stdout.write('\t'.join(line))
    sys.stdout.write('\n')

if __name__ == '__main__':
  process()
