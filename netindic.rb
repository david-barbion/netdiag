#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'socket'
require 'net/ping'
require 'resolv'
require "netdiag/local"
require "netdiag/gateway"
require "netdiag/dns"
require "netdiag/internet"
require "rubygems"
require "gtk3"
require "appindicator.so"
require "netdiag/window"
require "libnotify"
require "netdiag-config"

STATE_OK=0
STATE_ELOCAL=1
STATE_EGATEWAY=2
STATE_EDNS=3
STATE_EINTERNET=4

class Netindic

  def initialize
    Gtk.init
    @config = Netdiag::Config.new()
    @ai = AppIndicator::AppIndicator.new("Netdiag", "indicator-messages", AppIndicator::Category::COMMUNICATIONS);
    @indicator_menu = Gtk::Menu.new
    @indicator_diagnose = Gtk::MenuItem.new "Diagnose"
    @indicator_diagnose.signal_connect "activate" do
      self.update_ntw_info
      self.show_diag
    end
    @indicator_diagnose.show
    @indicator_menu.append @indicator_diagnose
    @indicator_exit     = Gtk::MenuItem.new "Exit"
    @indicator_exit.signal_connect "activate" do
      Gtk.main_quit
    end
    @indicator_exit.show
    @indicator_menu.append @indicator_exit
    @ai.set_menu(@indicator_menu)
    @ai.set_status(AppIndicator::Status::ACTIVE)
    @ai.set_icon_theme_path("#{File.dirname(File.expand_path(__FILE__))}/static/#{@config.get_theme}")
    @ai.set_icon("help_64")
    @last_state=STATE_OK
  end

  def update_ntw_info
    @config = Netdiag::Config.new
    @local = Netdiag::Local.new
    @gateway = Netdiag::Gateway.new(@local.default_gateways)
    @dns = Netdiag::DNS.new
    @internet = Netdiag::Internet.new(@config.get_test_url)
  end

  def run
    self.update_ntw_info
    self.run_tests
    Thread.new do loop do
      self.update_ntw_info
      self.run_tests
      sleep(20)
    end end
    Gtk.main
  end
  
  def show_diag
    @window = Netdiag::Window.new
    # Test local interface LAN
    local_diag_info = 'Network interfaces informations:'
    if (@local.diagnose)
      status = "Ok"
    else
      status = "Error"
    end
    @window.local_diag="Status: #{status}"
    # full text informations
    @local.local_interfaces.each do |int,data|
      local_diag_info.concat("\n#{int}")
      data.each do |data_addr|
        local_diag_info.concat("\n #{data_addr[:address]}/#{data_addr[:netmask]}")
      end
    end
    @window.local_diag_info=local_diag_info
    #puts local_diag_info
    #local.raise_diag

    # Test Gateway reachability
    gw_diag_percent = @gateway.diagnose
    puts "La qualité d'accès à la/les gateway(s): #{gw_diag_percent}"
    @window.gw_diag=("Quality: #{gw_diag_percent}%")
    # stop lan blinking
    if gw_diag_percent >= 50
      @window.lan_status=(true)
    else
      @window.lan_status=(false)
    end
    if @local.default_gateways.length > 1
      gw_diag_info = 'Gateways addresses:'
    else
      gw_diag_info = 'Gateway address:'
    end
    @local.default_gateways.each do |gw|
      gw_diag_info.concat("\n#{gw}")
    end
    @window.gw_diag_info=gw_diag_info
    #gw.raise_diag


    # test internet access
    internet_dns_diag = @dns.diagnose
    internet_net_diag = @internet.diagnose

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
      @window.wan_status=true
    else
      internet_diag.concat("\nQuality: #{internet_net_diag}%")
      internet_diag_info.concat("\nInternet not reachable")
      @window.wan_status=false
    end
    puts "DNS: #{internet_diag}"
    @window.internet_diag = internet_diag
    @window.internet_diag_info = internet_diag_info
    
  end

  def run_tests
    if !@local.diagnose
      puts "error 1"
      if @last_state != STATE_ELOCAL
        Libnotify.show(:summary => "No routable address", :body => "No IP address on any interface, check network cable or wifi", :timeout => 2.5)
        @last_state = STATE_ELOCAL
      end
      @ai.set_icon("error_64")
    else 
      if @gateway.diagnose < 50
        if @last_state != STATE_EGATEWAY
          Libnotify.show(:summary => "Gateway unreachable", :body => "The default gateway is ureachable, maybe a temporary network failure", :timeout => 2.5)
          @last_state = STATE_EGATEWAY
        end
        puts "error 2"
        @ai.set_icon("help_64")
      else
        if !@dns.diagnose
          if @last_state != STATE_EDNS
            Libnotify.show(:summary => "DNS failure", :body => "The local resolve internet names", :timeout => 2.5)
            @last_state = STATE_EDNS
          end
          puts "error 3"
          @ai.set_icon("warning_64")
        else
          if @internet.diagnose < 50
            if @last_state != STATE_EINTERNET
              Libnotify.show(:summary => "Internet unreachable", :body => "Can't go outside local network, check filtering, border gateway or cable/ADSL modem", :timeout => 2.5)
              @last_state = STATE_EINTERNET
            end
            puts "error 4"
            @ai.set_icon("error_64")
          else
            if @last_state != STATE_OK
              Libnotify.show(:summary => "Full network connectivity", :timeout => 2.5)
              @last_state = STATE_OK
            end
            @ai.set_icon("checkmark_64")
          end
        end
      end
    end
  end
end

netindic = Netindic.new
netindic.run
