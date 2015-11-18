# %~dp0 batch path wildcard
#Windoze users Lazy edition
Echo "rebuilding Json's from yaml files"
copy %~dp0\sabayon-packer\*.json %~dp0\sabayon-packer\*.json.old #add add backup Statment
python3 %~dp0\sabayon-packer\util\make-yaml-2json.py %~dp0\sabayon-packer\yaml\*.json > %~dp0\sabayon-packer\
Echo "rebuilding Compleaded"