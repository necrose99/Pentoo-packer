## Packer templates for Pentoo
adapted slighlty from Sabayon Packer Template & https://github.com/aostanin/packer-templates/Gentoo
In progress.... 
**ADDED YAML Templates for Easy to Read/Editing** 
((Scripts to run python scripts in batch output json from Yaml are still Testing. ))
[http://www.json2yaml.com/] , [http://codebeautify.org/yaml-to-json-xml-csv] {note also alows for validation}
tabs in yaml will :||DIE  @conversion   etc you can use to also parse.
thier are other template Aspects, which you can parse to yaml and makes cutting snipits eassier 

Now you can build fresh vagrant, virtualbox and VMware Pentoo images, & LXC Box Images (to DO) [https://github.com/fgrehm/vagrant-lxc] Requires Vagrant-LXC  with [packer](https://packer.io/).

those are the variables that can be tweaked:

      "root_username":"root",
      "root_password":"root",
      "build":"DAILY", 
      "build_type":"daily",
      "arch":"amd64",
      "disk_size":"60000",
      "vagrant":"vagrant",
      

while some of them are self-explanatory, those are the interesting to punt to a specific build type:

* **flavor**: you can tweak what iso is going to be converted to an image : "Pentoo", "Pentoo-dev", "Minimal"
* **vagrant**: if set to vagrant, it will be configured the vagrant user automatically
* **build** && **build_type**: it refeers at the location and type of the build

Note: use the images.json for custom builds, vagrant.json is used for [Atlas](https://atlas.hashicorp.com) automatic building system

Download the repository and then, choose on what are you interested in:

### Vagrant

    packer build -var "vagrant=vagrant" -only virtualbox-iso images.json

Note: vagrant images are also available in Hashicorp's Atlas: **TO DO** [Pentoo/Pentoo-amd64](https://atlas.hashicorp.com/Pentoo/boxes/Pentoo-amd64). 
[Necrose's Evil Tests of Automatic Pentoo Boxes] @ (https://atlas.hashicorp.com/Necrose99) ||State is pre-Alpha
Once **ALPHA or more BETA**

If you have Vagrant this should be straightforward:

	vagrant init Pentoo/Pentoo-amd64; vagrant up --provider virtualbox

You can always download the boxes using Atlas providers link:

 *https://atlas.hashicorp.com/Pentoo/boxes/Pentoo-amd64/versions/**[TAG]**/providers/virtualbox.box*

* here **[TAG]** is the box version (*e.g. v0.10 =>  https://atlas.hashicorp.com/Pentoo/boxes/Pentoo-amd64/versions/0.10/providers/virtualbox.box*)


### Virtualbox

If you want to build a Pentoo, withouth vagrant credentials, you have to run:

	packer build -var "flavor=Pentoo" -var "vagrant=" -only virtualbox-iso images.json

Note: This will produce a vagrant box as well

### VMware

    packer build -var "flavor=Pentoo" -var "vagrant=" -only vmware-iso images.json


### QEMU

    packer build -var "flavor=Pentoo" -var "vagrant=" -only qemu images.json

### LXC (Requires VAGRANT-LXC PLUGIN) **TO DO** 
(adds a **LXC or Linux Containers** gives option of runing on Real Machine but in an **Enhanced CHROOT** Like  Enviorment **AKIN to BSD-JAILS**) CAN SET IP ADDRESS , can RUN X11 , good for testing NEW X11 Packages FOr Pentoo ,that might **Break your MAIN Production PENTOO system**, 
CAN use to emerge packages will FULL CPU or with portage nice , LINUX-Cgroups and set chron jobs, 

    packer build -var "flavor=Pentoo" -var "vagrant=" -only qemu images.json
## Credentials

The **root** user has the **root** password, so if you are going to deploy this image, you want to change that.

Optional:
If you enabled the build with vagrant, a user "vagrant" with password **vagrant** will be created. That can be accessed by issuing "vagrant ssh" (pubkeys are the insecure ones needed by Vagrant).

### WHY A Packer Template for Pentoo ? , Well Why NOT , it saves time , By making virtual a Virtual Machine, 
CAN test a few new toys , without Breaking your REAL Pentoo install. CAN Pull fresh Every Day From Atlas](https://atlas.hashicorp.com) <automatic building system>
