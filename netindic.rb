#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'socket'
require 'net/ping'
require 'resolv'
require 'netdiag/local'
require 'netdiag/gateway'
require 'netdiag/dns'
require 'netdiag/internet'
require 'rubygems'
require 'netdiag/portal'
require 'appindicator.so'
require 'netdiag/window'
require 'libnotify'
require 'netdiag-config'

STATE_OK=0
STATE_ELOCAL=1
STATE_EGATEWAY=2
STATE_EDNS=3
STATE_EINTERNET=4
STATE_ECAPTIVE=5

class Netindic

  class Portal < Netdiag::Portal
    def initialize
      super
    end

    def close_portal_authenticator_window
      super
      # this should refresh tests
    end
  end

  def initialize
    @portal_authenticator = Portal.new
    @config = Netdiag::Config.new()
    @ai = AppIndicator::AppIndicator.new("Netdiag", "indicator-messages", AppIndicator::Category::COMMUNICATIONS);
    @indicator_menu = Gtk::Menu.new
    @indicator_diagnose = Gtk::MenuItem.new :label => "Diagnose"
    @indicator_diagnose.signal_connect "activate" do
      self.show_diag
    end
    @indicator_diagnose.show
    @indicator_menu = Gtk::Menu.new
    @indicator_captive = Gtk::MenuItem.new :label => "Open captive portal authenticator window"
    @indicator_captive.signal_connect "activate" do
      @portal_authenticator.open_portal_authenticator_window(:keep_open => true)
    end
    @indicator_captive.show
    @indicator_menu.append @indicator_diagnose
    @indicator_menu.append @indicator_captive
    @indicator_exit     = Gtk::MenuItem.new :label => "Exit"
    @indicator_exit.signal_connect "activate" do
      Gtk.main_quit
    end
    @indicator_exit.show
    @indicator_menu.append @indicator_exit
    @ai.set_menu(@indicator_menu)
    @ai.set_status(AppIndicator::Status::ACTIVE)
    @ai.set_icon_theme_path("#{File.dirname(File.expand_path(__FILE__))}/static/#{@config.get_theme}")
    @ai.set_icon("help_64")

    @last_state=-1

    @captive_window_authenticator = nil
    @local = Netdiag::Local.new
    @gateway = Netdiag::Gateway.new
    @dns = Netdiag::DNS.new
    @internet = Netdiag::Internet.new(@config.get_test_url)

  end

  def prepare_diag
    @local.prepare
    @gateway.prepare(@local.default_gateways)
    @dns.prepare
    @internet.prepare
  end

  def run
    Thread.new do loop do
      begin
        self.prepare_diag
        self.run_tests
      rescue Exception => e
        puts e.message
      end
      sleep(20)
    end end
    Gtk.main
  end
  
  def show_diag
    @window = Netdiag::Window.new
    Thread.new {
      self.prepare_diag
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
      @window.gw_diag=("Quality: #{gw_diag_percent.round(2)}%")
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
        internet_diag_info = @dns.status
      else
        internet_diag="DNS not working properly"
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
    }
    
  end

  def set_state_and_notify(state)
    case state
    when STATE_ELOCAL
      if @last_state != STATE_ELOCAL
        Libnotify.show(:summary => "No routable address", :body => "No IP address on any interface, check network cable or wifi", :timeout => 2.5)
        @last_state = STATE_ELOCAL
        puts "error 1"
        @ai.set_icon("error_64")
      end
    when STATE_EGATEWAY
      if @last_state != STATE_EGATEWAY
        Libnotify.show(:summary => @gateway.status, :body => "Maybe a temporary network failure\n#{@gateway.message}", :timeout => 2.5)
        @last_state = STATE_EGATEWAY
        puts "error 2"
        @ai.set_icon("help_64")
      end
    when STATE_EDNS
      if @last_state != STATE_EDNS
        Libnotify.show(:summary => "DNS failure", :body => "The local resolver can't resolve internet names.\nError was #{@dns.error}.", :timeout => 2.5)
        @last_state = STATE_EDNS
        puts "error 3"
        @ai.set_icon("warning_64")
      end
    when STATE_EINTERNET
      if @last_state != STATE_EINTERNET
        Libnotify.show(:summary => "Internet unreachable", :body => "Can't go outside local network, check filtering, gateways or cable/ADSL modem\n#{@internet.error}", :timeout => 2.5)
        @last_state = STATE_EINTERNET
        puts "error 4"
        @ai.set_icon("error_64")
      end
    when STATE_ECAPTIVE
      if @last_state != STATE_ECAPTIVE
        Libnotify.show(:summary => "Blocked by a captive portal", :body => "A captive portal blocks access to Internet", :timeout => 2.5)
        @last_state = STATE_ECAPTIVE
        puts "error 5"
        @ai.set_icon("forbidden_64")
      end
    when STATE_OK
      if @last_state != STATE_OK
        Libnotify.show(:summary => "Full network connectivity", :timeout => 2.5)
        @last_state = STATE_OK
        puts "no error"
        @ai.set_icon("checkmark_64")
      end
    else
      puts "unknown state #{state}"
    end
  end

  def run_tests
    if !@local.diagnose
      self.set_state_and_notify(STATE_ELOCAL)
    else 
      if @gateway.diagnose < 50
        self.set_state_and_notify(STATE_EGATEWAY)
      else
        if !@dns.diagnose
          self.set_state_and_notify(STATE_EDNS)
        else
          if @internet.is_captive?
            self.set_state_and_notify(STATE_ECAPTIVE)
            @portal_authenticator.open_portal_authenticator_window
          else
            if @internet.diagnose < 50
              self.set_state_and_notify(STATE_EINTERNET)
            else
              self.set_state_and_notify(STATE_OK)
              @portal_authenticator.close_portal_authenticator_window
            end
          end
        end
      end
    end
  end
end

netindic = Netindic.new
netindic.run
