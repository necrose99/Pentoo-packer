#https://github.com/aostanin/packer-templates/blob/master/gentoo/make.py
#! /usr/bin/env python3

import json
import yaml

yaml = yaml.load(open('gentoo.yaml'))
del yaml['builders_base']
json = json.dumps(yaml)
print(json)
