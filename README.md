# Installation

Before using netdiag, some librairies must be installed. 

Example for Ubuntu 16+:
```bash
sudo apt install ruby-dev libcairo-dev libappindicator-dev ruby-bundler ruby-gtk3 gir1.2-webkit2-4.0
git clone https://github.com/david-barbion/netdiag 
cd netdiag
bundle install
```

Example for Debian 8 Jessie:
```bash
sudo apt install ruby-dev libcairo-dev libappindicator-dev ruby-bundler ruby-gtk3 gir1.2-webkit2-4.0
git clone https://github.com/david-barbion/netdiag 
cd netdiag
bundle install
```

Bundle will ask for your password.

This app is now compatible with GTK3.

# Usage

Just run `netindic.rb`

# Configuration

Configuration is done by creating the directory `.config/netdiag`. The file `config.yaml` resides in this directory. It contains:
* `:theme:`: the icon theme to use
* `:test_dns:`: the internet name to query for determining DNS is working
* `:test_url:`: the url to test for determining internet reachability

Currently, configuration is read on startup only.

# Credits
* Theme / iconic : [Open Iconic](https://github.com/iconic/open-iconic) - MIT 
