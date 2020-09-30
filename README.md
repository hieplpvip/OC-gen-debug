# OC-gen-debug

A script for generating debugging files for Hackintosh running OpenCore

#### Installation

Open up Terminal and type:

```shell
curl https://raw.githubusercontent.com/hieplpvip/OC-gen-debug/master/gen_debug.sh -o /usr/local/bin/gen_debug && chmod a+x /usr/local/bin/gen_debug
```

#### Usage

It is a fully automated script. All the dependencies are fetched automatically from GitHub.

Just open up terminal and type: `gen_debug`

In case you have no internet connectivity, do the following:
- Download the source code as a zip file from github
- Open Terminal and type:

```shell
cd ~/Downloads/OC-gen-debug*
mkdir -p ~/Library/OC-gen-debug
cp -rf ./* ~/Library/OC-gen-debug
cp gen_debug.sh /usr/local/bin/gen_debug && chmod a+x /usr/local/bin/gen_debug
unzip -o IORegistryExplorer.zip -d /Applications/
```

#### Credits

- [black-dragon74](https://github.com/black-dragon74) for
[OSX-Debug](https://github.com/black-dragon74/OSX-Debug)
- RehabMan for MountEFI script
