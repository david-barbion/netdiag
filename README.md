# Installation

Before using netdiag, some librairies must be installed. Example for Ubuntu 16+:

```bash
sudo apt install ruby-gtk3
sudo apt install ruby-dev
sudo apt install libcairo-dev
sudo apt install libappindicator-dev

sudo gem install net-ping
sudo gem install ruby-libappindicator
```

Additionaly, libappindicator gem depends on GTK2 whereas netdiag depends on GTK3. To solve this issue, you need to modify libappindicator gem manually:
Edit the file `/var/lib/gems/2.3.0/gems/ruby-libappindicator-0.1.5/lib/ruby-libappindicator.rb` and change `gtk2` to `gtk3`.

The file path may vary, use gem contents ruby-libappindicator to find the right file.

# Usage

Just run `netindic.rb`
