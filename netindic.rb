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
require 'netdiag/conninfo'
require 'netdiag/utils'
require 'netdiag/nmlistener'
require 'rubygems'
require 'netdiag/portal'
require 'appindicator.so'
require 'netdiag/diagwindow'
require 'netdiag/notify'
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
    @run_sleeper = Netdiag::InterruptibleSleep.new
    @portal_authenticator = Portal.new

    @portal_authenticator.signal_connect "portal_closed" do
      @run_sleeper.wakeup
    end

    Netdiag::Config.load!("#{ENV['HOME']}/.config/netindic/config.yaml")
    @ai = AppIndicator::AppIndicator.new("Netdiag", "indicator-messages", AppIndicator::Category::COMMUNICATIONS);
    @indicator_menu = Gtk::Menu.new
    @indicator_diagnose = Gtk::MenuItem.new :label => "Diagnose"
    @indicator_diagnose.signal_connect "activate" do
      Netdiag::DiagWindow.new
    end
    @indicator_diagnose.show
    @indicator_captive = Gtk::MenuItem.new :label => "Open captive portal authenticator window"
    @indicator_captive.signal_connect "activate" do
      @portal_authenticator.open_portal_authenticator_window(:keep_open => true, :uri => Netdiag::Config.test_url)
    end
    @indicator_captive.show
    @indicator_conninfo = Gtk::MenuItem.new :label => "Show connection informations"
    @indicator_conninfo.signal_connect "activate" do
      @conninfo = Netdiag::Conninfo.new(@local, @gateway, @internet)
      @conninfo.show
    end
    @indicator_conninfo.show
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
    @indicator_menu.append @indicator_conninfo
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

    Netdiag::Notify.icon_dirs << "#{File.dirname(File.expand_path(__FILE__))}/static/#{Netdiag::Config.theme}"

    @last_state=-1

    @captive_window_authenticator = nil
    @local = Netdiag::Local.new
    @gateway = Netdiag::Gateway.new
    @dns = Netdiag::DNS.new(Netdiag::Config.test_dns)
    @internet = Netdiag::Internet.new

    @nmlistener = Netdiag::NMListener.new
    @nmlistener.set_callback {
      @run_sleeper.wakeup
    }
    @nmlistener.run
  end

  def run
    $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
    Thread.new {
      Thread.current[:name] = "polling"
      $logger.debug("entering polling thread")
      loop do
        begin
          self.run_tests
        rescue Exception => e
          $logger.warn("Diag exception report: #{e.message}")
          puts e.backtrace
        end
        $logger.debug('going to sleep')
        @run_sleeper.sleep(20)
      end
    }
    $logger.debug('starting Gtk.main')
    Gtk.main_with_queue(100)
  end
  
  def set_state_and_notify(state)
    $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
    case state
    when STATE_ELOCAL
      if @last_state != STATE_ELOCAL
        Netdiag::Notify.send(
          :summary => "No routable address",
          :body    => "No IP address on any interface, check network cable or wifi",
          :timeout => 2500,
          :icon    => 'error_64.png'
        )
        @last_state = STATE_ELOCAL
        $logger.error("Error code 1. No IP address on any interface")
        @ai.set_icon("error_64")
      end
    when STATE_EGATEWAY
      if @last_state != STATE_EGATEWAY
        Netdiag::Notify.send(
          :summary => @gateway.status,
          :body    => "#{@gateway.message}",
          :timeout => 2500,
          :icon    => 'help_64.png'
        )
        @last_state = STATE_EGATEWAY
        $logger.error("Error code 2. Can't reach gateway: #{@gateway.message}")
        @ai.set_icon("help_64")
      end
    when STATE_EDNS
      if @last_state != STATE_EDNS
        Netdiag::Notify.send(
          :summary => "DNS failure",
          :body    => "The local resolver can't resolve internet names.\nError was #{@dns.error}.",
          :timeout => 200,
          :icon    => 'warning_64.png'
        )
        @last_state = STATE_EDNS
        $logger.error("Error code 3. DNS problem")
        @ai.set_icon("warning_64")
      end
    when STATE_EINTERNET
      if @last_state != STATE_EINTERNET
        Netdiag::Notify.send(
          :summary => "Internet unreachable",
          :body    => "Can't go outside local network, check filtering, gateways or cable/ADSL modem\n#{@internet.error}",
          :timeout => 2500,
          :icon    => 'error_64.png'
        )
        @last_state = STATE_EINTERNET
        $logger.error("Error code 4. Internet unreachable")
        @ai.set_icon("error_64")
      end
    when STATE_ECAPTIVE
      if @last_state != STATE_ECAPTIVE
        Netdiag::Notify.send(
          :summary => "Blocked by a captive portal",
          :body    => "A captive portal blocks access to Internet",
          :timeout => 2500,
          :icon    => 'forbidden_64.png'
        )
        @last_state = STATE_ECAPTIVE
        $logger.error("Error code 5. Blocked by a captive portal")
        @ai.set_icon("forbidden_64")
      end
    when STATE_OK
      if @last_state != STATE_OK
        Netdiag::Notify.send(
          summary: "Full network connectivity",
          icon: 'checkmark_64.png',
          timeout: 2500,
        )
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
    @local.prepare
    if !@local.diagnose
      self.set_state_and_notify(STATE_ELOCAL)
    else 
      @gateway.prepare(@local.default_gateways)
      if @gateway.check_gateway_threshold
        self.set_state_and_notify(STATE_EGATEWAY)
      else
        @dns.prepare
        if !@dns.diagnose
          self.set_state_and_notify(STATE_EDNS)
        else
          @internet.prepare
          if @internet.is_captive?
            self.set_state_and_notify(STATE_ECAPTIVE)
            if !@indicator_captive_t.active? and !@portal_authenticator.is_disabled?
              Gtk.queue do @portal_authenticator.open_portal_authenticator_window(:uri => Netdiag::Config.test_url) end
            end
          else
            if @internet.diagnose < 50
              self.set_state_and_notify(STATE_EINTERNET)
            else
              self.set_state_and_notify(STATE_OK)
              Gtk.queue do @portal_authenticator.close_portal_authenticator_window if @portal_authenticator.is_opened? end
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

Thread.current[:name] = "main"
$logger = Logger.new(STDOUT)
$logger.formatter = proc do |severity, datetime, progname, msg|
  "[#{datetime}] [th: #{Thread.current[:name]}] #{severity} #{msg}\n"
end
$logger.level = Logger::DEBUG
$logger.debug('Program started')
netindic = Netindic.new
netindic.run
