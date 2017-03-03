#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'pp'
require 'socket'
require 'net/ping'
require 'resolv'
require 'gtk3'
require 'netdiag/window'
require "netdiag/local"
require "netdiag/gateway"
require "netdiag/dns"
require "netdiag/internet"
#
#dns = NetworkDNS.new
#puts dns.diagnose
#exit
#ni = NetworkInternet.new
#puts ni.diagnose
#exit
# end test

#Gtk.init
window = Netdiag::Window.new

    GLib::Timeout.add(1000) do
      window.change_lan_icon
      true
    end
    GLib::Timeout.add(1000) do
      window.change_wan_icon
      true
    end
    thr = Thread.new {
      # Test local interface LAN
      local = Netdiag::Local.new
      local_diag_info = 'Network interfaces informations:'
      if (local.diagnose)
        status = "Ok"
      else
        status = "Error"
      end
      window.local_diag="Status: #{status}"
      # full text informations
      local.local_interfaces.each do |int,data|
        local_diag_info.concat("\n#{int}")
        data.each do |data_addr|
          local_diag_info.concat("\n #{data_addr[:address]}/#{data_addr[:netmask]}")
        end
      end
      window.local_diag_info=local_diag_info
      #puts local_diag_info
      #local.raise_diag

      # Test Gateway reachability
      gw = Netdiag::Gateway.new(local.default_gateways)
      gw_diag_percent = gw.diagnose
      puts "La qualité d'accès à la/les gateway(s): #{gw_diag_percent}"
      window.gw_diag=("Quality: #{gw_diag_percent}%")
      # stop lan blinking
      if gw_diag_percent >= 50
        window.lan_status=(true)
      else
        window.lan_status=(false)
      end
      if local.default_gateways.length > 1
        gw_diag_info = 'Gateways addresses:'
      else
        gw_diag_info = 'Gateway address:'
      end
      local.default_gateways.each do |gw|
        gw_diag_info.concat("\n#{gw}")
      end
      window.gw_diag_info=gw_diag_info
      #gw.raise_diag


      # test internet access
      dns = Netdiag::DNS.new
      ni = Netdiag::Internet.new
      internet_dns_diag = dns.diagnose
      internet_net_diag = ni.diagnose

      if internet_dns_diag
        internet_diag="DNS working"
        internet_diag_info = "DNS is working"
      else
        internet_diag="DNS not working"
        internet_diag_info = "DNS is not working"
      end
      if internet_net_diag > 50
        internet_diag.concat("\nQuality: #{internet_net_diag}%")
        internet_diag_info.concat("\nInternet reachable")
        window.wan_status=true
      else
        internet_diag.concat("\nQuality: #{internet_net_diag}%")
        internet_diag_info.concat("\nInternet not reachable")
        window.wan_status=false
      end
      puts "DNS: #{internet_diag}"


      window.internet_diag = internet_diag
      window.internet_diag_info = internet_diag_info
    }

Gtk.main

#pp local.local_interfaces
#pp local.routed_addresses
#pp local.routes
#pp local.default_gateways
#puts Socket::IFF_UP
