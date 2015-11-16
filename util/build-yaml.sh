#
Echo "rebuilding Yaml files for Editing Simplicity "
Echo "F'ONT Put Yaml Files in the ROOT Project the Cloud Packer Will FAIL BIG time"
cp ./sabayon-packer/*.json ./sabayon-packer/yaml
./sabayon-packer/util/json2yaml.py ./sabayon-packer/yaml/*.json
