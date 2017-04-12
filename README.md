# What is netindic?

Netindic is an indicator tool for diagnosing network connectivity problem. The issues netindic can detect includes:
* missing IPv4 address or IPv6 address (global)
* missing or unreachable gateway
* unreachable or malfunctioning DNS
* captive portal
* malfunctioning internet (currently make a test to http://httpbin.org) 

If a captive portal is detected, an authentication window is opened.

Basically, netindic tests all components every 20 seconds. 

![Indicator](https://github.com/david-barbion/netdiag/wiki/images/indicator.png)

At any time, one can ask for a network diagnosis. The following window will appear:

![Diagnose](https://github.com/david-barbion/netdiag/wiki/images/diagnose.png)

# Installation

Before using netindic, some librairies must be installed. 

## Ubuntu 16+:

```bash
sudo apt install libappindicator-dev ruby-bundler ruby-gtk3 gir1.2-webkit2-4.0 ruby-json ruby-atk ruby-pango ruby-gio2 ruby-cairo ruby-cairo-gobject ruby-gobject-introspection ruby-gdk-pixbuf2 ruby-gdk3 ruby-glib2 ruby-gtk2 ruby-ffi
git clone https://github.com/david-barbion/netdiag 
cd netdiag
bundle install
```

Bundle will ask for your password.

## Debian 8 Jessie and Debian 9 Stretch:
If you are running Gnome Shell, you have to enable AppIndicator: take a look here https://extensions.gnome.org/extension/615/appindicator-support/

```bash
sudo apt install libappindicator-dev ruby-bundler ruby-gtk3 gir1.2-webkit2-4.0 ruby-json ruby-atk ruby-pango ruby-gio2 ruby-cairo ruby-cairo-gobject ruby-gobject-introspection ruby-gdk-pixbuf2 ruby-gdk3 ruby-glib2 ruby-gtk2 ruby-ffi
git clone https://github.com/david-barbion/netdiag 
cd netdiag
bundle install
```

Bundle will ask for your password.
 
## Archlinux and Manjaro 17 Gellivara

```
pacman -S ruby ruby-bundler ruby-gtk2 ruby-json ruby-atk ruby-pango ruby-gio2 ruby-cairo ruby-gobject-introspection ruby-gdk_pixbuf2 ruby-glib2 ruby-ffi gobject-introspection libappindicator-gtk2
git clone https://github.com/david-barbion/netdiag 
cd netdiag
bundle install
```

Bundle will ask for your password.

# Usage

Just run `./netindic.rb`

# Autostart

Run `./install.sh` to enable automatic startup on session start.

# Configuration

Configuration is done by creating the directory `.config/netindic`. The file `config.yaml` resides in this directory. It contains:
* `:theme:`: the icon theme to use
* `:test_dns:`: the internet name to query for determining DNS is working
* `:test_url:`: the url to test for determining internet reachability

Currently, configuration is read on startup only.

# Credits
* Theme / iconic : [Open Iconic](https://github.com/iconic/open-iconic) - MIT 

