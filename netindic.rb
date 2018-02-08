#!/usr/bin/env ruby

$LOAD_PATH.unshift(File.dirname(__FILE__))
require 'socket'
require 'net/ping'
require 'resolv'
require 'netdiag/config'
require 'netdiag/local'
require 'netdiag/gateway'
require 'netdiag/dns'
require 'netdiag/internet'
require 'netdiag/preferences'
require 'netdiag/utils'
require 'rubygems'
require 'netdiag/portal'
require 'appindicator.so'
require 'netdiag/diagwindow'
require 'libnotify'
require 'logger'

STATE_OK=0
STATE_ELOCAL=1
STATE_EGATEWAY=2
STATE_EDNS=3
STATE_EINTERNET=4
STATE_ECAPTIVE=5

class Netindic 

  class Portal < Netdiag::Portal
    def initialize
      $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
      Gtk.queue do super end
    end

     def open_portal_authenticator_window(args={})
      $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
      Gtk.queue do super end
     end

    def close_portal_authenticator_window
      $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
      Gtk.queue do super end
      # this should refresh tests
    end

    def signal_do_portal_closed(*args)
      $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
      $logger.info("Portal closed: last uri is #{args[:uri]}")
      Gtk.queue do super end
    end

  end

  def initialize
    $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
    @portal_authenticator = Portal.new

    @portal_authenticator.signal_connect "portal_closed" do
      @run_sleeper.wakeup
    end

    Netdiag::Config.load!("#{ENV['HOME']}/.config/netindic/config.yaml")
    @ai = AppIndicator::AppIndicator.new("Netdiag", "indicator-messages", AppIndicator::Category::COMMUNICATIONS);
    @indicator_menu = Gtk::Menu.new
    @indicator_diagnose = Gtk::MenuItem.new :label => "Diagnose"
    @indicator_diagnose.signal_connect "activate" do
      self.show_diag
    end
    @indicator_diagnose.show
    @indicator_captive = Gtk::MenuItem.new :label => "Open captive portal authenticator window"
    @indicator_captive.signal_connect "activate" do
      @portal_authenticator.open_portal_authenticator_window(:keep_open => true, :uri => 'http://httpbin.org')
    end
    @indicator_captive.show
    @indicator_prefs = Gtk::MenuItem.new :label => "Preferences"
    @indicator_prefs.signal_connect "activate" do
      $logger.debug('open preferences window')
      @preferences = Netdiag::Preferences.new
      @preferences.show
    end
    @indicator_prefs.show
    @indicator_captive_t = Gtk::CheckMenuItem.new :label => "Disable captive portal"
    @indicator_captive_t.show
    @indicator_menu.append @indicator_diagnose
    @indicator_menu.append @indicator_captive
    @indicator_menu.append @indicator_captive_t
    @indicator_menu.append @indicator_prefs

    @indicator_exit     = Gtk::MenuItem.new :label => "Exit"
    @indicator_exit.signal_connect "activate" do
      Gtk.main_quit
    end
    @indicator_exit.show
    @indicator_menu.append @indicator_exit
    @ai.set_menu(@indicator_menu)
    @ai.set_status(AppIndicator::Status::ACTIVE)
    @ai.set_icon_theme_path("#{File.dirname(File.expand_path(__FILE__))}/static/#{Netdiag::Config.theme}")
    @ai.set_icon("help_64")

    Libnotify.icon_dirs << "#{File.dirname(File.expand_path(__FILE__))}/static/#{Netdiag::Config.theme}"

    @last_state=-1

    @captive_window_authenticator = nil
    @local = Netdiag::Local.new
    @gateway = Netdiag::Gateway.new(ipv4_mandatory: Netdiag::Config.gateways[:ipv4_mandatory],
                                    ipv6_mandatory: Netdiag::Config.gateways[:ipv6_mandatory])
    @dns = Netdiag::DNS.new(Netdiag::Config.test_dns)
    @internet = Netdiag::Internet.new(Netdiag::Config.test_url)

  end

  def prepare_diag
    $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
    @local.prepare
    @gateway.prepare(@local.default_gateways)
    @dns.prepare
    @internet.prepare
  end

  def run
    $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
    @run_sleeper = Netdiag::InterruptibleSleep.new
    Thread.new {
      $logger.debug("entering polling thread")
      loop do
        begin
          self.prepare_diag
          self.run_tests
        rescue Exception => e
          $logger.warn("Diag exception report: #{e.message}")
        end
        $logger.debug('going to sleep')
        @run_sleeper.sleep(20)
      end
    }
    $logger.debug('starting Gtk.main')
    Gtk.main_with_queue(100)
  end
  
  def show_diag
    $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
    @window = Netdiag::DiagWindow.new
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
      $logger.debug("Network gateway reachability quality: #{gw_diag_percent}")
      gw_diag = "Quality: #{gw_diag_percent.round(2)}%"
      gw_diag.concat("\nMissing IPv4 gateway") if @gateway.is_ipv4_gateway_missing
      gw_diag.concat("\nMissing IPv6 gateway") if @gateway.is_ipv6_gateway_missing
      @window.gw_diag=gw_diag
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
        gw_diag_info.concat("\n#{gw} quality: #{@gateway.get_gw_quality(gw).round(2)}%")
      end
      gw_diag_info.concat("\nMissing IPv4 gateway") if @gateway.is_ipv4_gateway_missing
      gw_diag_info.concat("\nMissing IPv6 gateway") if @gateway.is_ipv6_gateway_missing
      @window.gw_diag_info=gw_diag_info
  
      # test internet access
      internet_dns_diag = @dns.diagnose
      internet_net_diag = @internet.diagnose
  
      if internet_dns_diag
        internet_diag="DNS working"
        internet_diag_info = @dns.message
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
      logger.debug("DNS: #{internet_diag}")
      @window.internet_diag = internet_diag
      @window.internet_diag_info = internet_diag_info
    }
    
  end

  def set_state_and_notify(state)
    $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
    case state
    when STATE_ELOCAL
      if @last_state != STATE_ELOCAL
        Libnotify.show(:summary => "No routable address",
                       :body => "No IP address on any interface, check network cable or wifi",
                       :timeout => 2.5,
                       :urgency => :critical,
                       :icon_path => 'error_64.png')
        @last_state = STATE_ELOCAL
        $logger.error("Error code 1. No IP address on any interface")
        @ai.set_icon("error_64")
      end
    when STATE_EGATEWAY
      if @last_state != STATE_EGATEWAY
        Libnotify.show(:summary => @gateway.status,
                       :body => "#{@gateway.message}",
                       :timeout => 2.5,
                       :urgency => :critical,
                       :icon_path => 'help_64.png')
        @last_state = STATE_EGATEWAY
        $logger.error("Error code 2. Can't reach gateway: #{@gateway.message}")
        @ai.set_icon("help_64")
      end
    when STATE_EDNS
      if @last_state != STATE_EDNS
        Libnotify.show(:summary => "DNS failure",
                       :body => "The local resolver can't resolve internet names.\nError was #{@dns.error}.",
                       :timeout => 2.5,
                       :urgency => :critical,
                       :icon_path => 'warning_64.png')
        @last_state = STATE_EDNS
        $logger.error("Error code 3. DNS problem")
        @ai.set_icon("warning_64")
      end
    when STATE_EINTERNET
      if @last_state != STATE_EINTERNET
        Libnotify.show(:summary => "Internet unreachable",
                       :body => "Can't go outside local network, check filtering, gateways or cable/ADSL modem\n#{@internet.error}",
                       :timeout => 2.5,
                       :urgency => :normal,
                       :icon_path => 'error_64.png')
        @last_state = STATE_EINTERNET
        $logger.error("Error code 4. Internet unreachable")
        @ai.set_icon("error_64")
      end
    when STATE_ECAPTIVE
      if @last_state != STATE_ECAPTIVE
        Libnotify.show(:summary => "Blocked by a captive portal",
                       :body => "A captive portal blocks access to Internet",
                       :timeout => 2.5,
                       :urgency => :normal,
                       :icon_path => 'forbidden_64.png')
        @last_state = STATE_ECAPTIVE
        $logger.error("Error code 5. Blocked by a captive portal")
        @ai.set_icon("forbidden_64")
      end
    when STATE_OK
      if @last_state != STATE_OK
        Libnotify.show(:summary => "Full network connectivity",
                       :timeout => 2.5,
                       :urgency => :low,
                       :icon_path => "checkmark_64.png")
        @last_state = STATE_OK
        $logger.info("No error. All tests ok")
        @ai.set_icon("checkmark_64")
      end
    else
      $logger.warn("unknown state #{state}")
    end
  end

  def run_tests
    $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
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
            if !@indicator_captive_t.active? and !@portal_authenticator.is_disabled?
              @portal_authenticator.open_portal_authenticator_window(:uri => 'http://httpbin.org')
            end
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

module Gtk
	GTK_PENDING_BLOCKS = []
	GTK_PENDING_BLOCKS_LOCK = Monitor.new

	def Gtk.queue &block
		if Thread.current == Thread.main
			block.call
		else
			GTK_PENDING_BLOCKS_LOCK.synchronize do
				GTK_PENDING_BLOCKS << block
			end
		end
	end

	def Gtk.main_with_queue timeout
    GLib::Timeout.add timeout do
			GTK_PENDING_BLOCKS_LOCK.synchronize do
				for block in GTK_PENDING_BLOCKS
					block.call
				end
				GTK_PENDING_BLOCKS.clear
			end
			true
		end
		Gtk.main
	end
end

$logger = Logger.new(STDOUT)
$logger.level = Logger::DEBUG
$logger.debug('Program started')
netindic = Netindic.new
netindic.run
