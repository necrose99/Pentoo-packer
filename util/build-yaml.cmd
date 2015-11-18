# Lazy Users on Windows Edition
# %~dp0 wildcard for relative path. 
Echo "rebuilding Yaml files for Editing Simplicity "
Echo "F'ONT Put Yaml Files in the ROOT Project the Cloud Packer Will FAIL BIG time"
copy %~dp0\sabayon-packer\*.json %~dp0\sabayon-packer\yaml
python3 %~dp0\sabayon-packer\util\json2yaml.py %~dp0\sabayon-packer\yaml\*.json
rm %~dp0\sabayon-packer\yaml\*.json
