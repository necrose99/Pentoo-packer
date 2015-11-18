#
Echo "rebuilding Json's from yaml files"

cp ./sabayon-packer/*.json ./sabayon-packer/*.json.old #add add backup Statment
python3 ./sabayon-packer/util/make-yaml-2json.py ./sabayon-packer/yaml/*.json >> ./sabayon-packer/
Echo "rebuilding Compleaded"