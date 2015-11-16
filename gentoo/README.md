# Description

A Gentoo Linux template for Packer with systemd and SaltStack.

# Usage

Convert YAML file to JSON

    $ ./make.py > gentoo.json

Build with packer

    $ packer build -only=vmware gentoo.json

