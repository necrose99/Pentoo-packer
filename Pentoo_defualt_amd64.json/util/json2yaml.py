##https://github.com/sheppard/json2yaml.py/blob/master/json2yaml.py
### Added for the Simplility of Yaml over Json.
#!/usr/bin/python

import json
import sys
from collections import OrderedDict

def json2yaml(fname):
    if fname.endswith('.json'):
        fname = fname.replace('.json', '')
    infile = open(fname + '.json')
    outfile = open(fname + '.yml', 'w')
    data = json.load(infile, object_pairs_hook=OrderedDict)

    def dump(val, indent=""):
        yml = ""
        if isinstance(val, OrderedDict):
            for key, item in val.items():
                if key == "_comment":
                    key = "# "
                else:
                    key = key + ": "
                yml += "\n%s%s" % (indent, key)
                yml += dump(item, indent + "    ")
        elif isinstance(val, list):
            for item in val:
                yml += "\n%s - " % indent
                yml += dump(item, indent + "    ")
        else:
            if val is None:
                val = "null"
            elif isinstance(val, bool):
                val = "true" if val else "false"
            elif isinstance(val, basestring) and (" " in val or "#" in val):
                val = '"%s"' % val
            yml += str(val)
        return yml

    outfile.write(dump(data))

if __name__ == "__main__":
    for fname in sys.argv[1:]:
        json2yaml(fname)
