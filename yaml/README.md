## Packer template for Sabayon (AS YAML)

Now you can build fresh vagrant, virtualbox and VMware Sabayon images with YAML
For Some Of US this makes IT easier to read, 

./sabayon-packer/yaml  **YAML FILES LIVE HEAR**

### Some Credits 
https://github.com/aostanin/packer-templates/blob/master/gentoo/make.py

https://github.com/sheppard/json2yaml.py/blob/master/json2yaml.py
###
###UTIL Dir (JUST A WARNING they will Overight any Json in the Project root, 
**BACKUP** Your **JSON** Prior To Pushing a build test)

sabayon-packer/util/rebuild-json.sh  gets YAML 

Files you have worked upon and transforms them to ./sabayon-packer/*.json using python3 and make.py

sabayon-packer/util/make.py from 

/sabayon-packer/util/build-yaml.sh gets json files from root will use Python3 to transform them to YAML using

sabayon-packer/util/json2yaml.py 
