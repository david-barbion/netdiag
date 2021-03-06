#!/usr/bin/env ruby
require "gtk3"
require_relative "./config"
require_relative "./local"
require_relative "./gateway"
require_relative "./dns"
require_relative "./internet"

module Netdiag
  class DiagWindow < Gtk::Window

    def initialize
        super
        @icon_path = "#{File.dirname(File.expand_path(__FILE__))}/../static/#{Netdiag::Config.theme}"
        @lan_status = nil # undefined lan status
        @wan_status = nil # undefined wan status
        @lan_diag_end = false
        @wan_diag_end = false
        @local_diag    = 'Checking'
        @gw_diag       = 'Checking'
        @internet_diag = 'Checking'
        @lan = true
        @wan = true
        
        init_ui
        prepare_tests
        run_diagnosis
    end

    def init_ui
        override_background_color :normal, Gdk::RGBA::new(0.8, 0.8, 0.8, 1)

        begin
            local_pb = GdkPixbuf::Pixbuf.new(:file => "#{@icon_path}/local.png")
            gateway_pb = GdkPixbuf::Pixbuf.new(:file => "#{@icon_path}/gateway.png")
            internet_pb = GdkPixbuf::Pixbuf.new(:file => "#{@icon_path}/internet.png")
            conn_pb = GdkPixbuf::Pixbuf.new(:file => "#{@icon_path}/connection.png")
            conn_pb_alt = GdkPixbuf::Pixbuf.new(:file => "#{@icon_path}/connection.png")
            conn_pb_alt = conn_pb_alt.saturate_and_pixelate(5.5, true)
            no_conn_pb = GdkPixbuf::Pixbuf.new(:file => "#{@icon_path}/no_connection.png")
            small_local_pb = local_pb.scale(128, 128, :bilinear)
            small_gateway_pb = gateway_pb.scale(128, 128, :bilinear)
            small_internet_pb = internet_pb.scale(128, 128, :bilinear)
        rescue IOError => e
            puts e
            $logger.error("#{self.class.name}::#{__method__.to_s} Cannot load images")
            return(false)
        end

        image1 = Gtk::Image.new :pixbuf => small_local_pb
        image2 = Gtk::Image.new :pixbuf => small_gateway_pb
        image3 = Gtk::Image.new :pixbuf => small_internet_pb
        @lan_ok = Gtk::Image.new :pixbuf => conn_pb
        @lan_ok_alt = Gtk::Image.new :pixbuf => conn_pb_alt
        @wan_ok = Gtk::Image.new :pixbuf => conn_pb
        @wan_ok_alt = Gtk::Image.new :pixbuf => conn_pb_alt

        @lan_ko = Gtk::Image.new :pixbuf => no_conn_pb
        @wan_ko = Gtk::Image.new :pixbuf => no_conn_pb

        hb = Gtk::Box.new(:horizontal) 
        @vb1 = Gtk::Box.new(:vertical)
        @vb2 = Gtk::Box.new(:vertical)
        @vb3 = Gtk::Box.new(:vertical)
        @label_local_diag = Gtk::Label.new.set_markup("<span foreground=\"#000000\">#{@local_diag}</span>")
        @label_gw_diag  = Gtk::Label.new.set_markup("<span foreground=\"#000000\">#{@gw_diag}</span>")
        @label_internet_diag = Gtk::Label.new.set_markup("<span foreground=\"#000000\">#{@internet_diag}</span>")
        @eb_lan = Gtk::EventBox.new()
        @eb_wan = Gtk::EventBox.new()
        @eb_lan.add(@lan_ok)
        @eb_wan.add(@wan_ok)

        @vb1.pack_start(image1,:expand => true)
        @vb1.pack_start(Gtk::Label.new.set_markup('<span foreground="#000000">Local</span>'),:expand => true)
        @vb1.pack_start(@label_local_diag,:expand => true)
        hb.pack_start(@vb1,:expand => true)
        hb.pack_start(@eb_lan,:expand => true)
        @vb2.pack_start(image2,:expand => true)
        @vb2.pack_start(Gtk::Label.new.set_markup('<span foreground="#000000">Gateway</span>',:expand => true))
        @vb2.pack_start(@label_gw_diag,:expand => true)
        hb.pack_start(@vb2,:expand => true)
        hb.pack_start(@eb_wan,:expand => true)
        @vb3.pack_start(image3,:expand => true)
        @vb3.pack_start(Gtk::Label.new.set_markup('<span foreground="#000000">Internet</span>'),:expand => true)
        @vb3.pack_start(@label_internet_diag,:expand => true)
        hb.pack_start(@vb3,:expand => true)
        add hb

        set_title "Network diag"
        signal_connect "destroy" do
            self.close_window
        end

        set_default_size 544, 280
        self.icon_name='gnome-nettool'
        self.window_position = :center
        self.open_window
    end

    def close_window
      self.hide
    end

    def open_window
        self.show_all
        self.present
        GLib::Timeout.add(1000) do
          if !self.change_lan_icon
            false
          else
            true
          end
        end
        GLib::Timeout.add(1000) do
          if !self.change_wan_icon
            false
          else
            true
          end
        end
    end

    # prepare test run
    def prepare_tests
      $logger.debug("entering #{self.class.name}::#{__method__.to_s}")
      @local = Netdiag::Local.new
      @gateway = Netdiag::Gateway.new
      @dns = Netdiag::DNS.new(Netdiag::Config.test_dns)
      @internet = Netdiag::Internet.new
    end

    def run_diagnosis
      Thread.new {
        Thread.current[:name] = "diagnose"
        @local.prepare
        @local.diagnose
        self.local_diag = @local.message
        self.local_diag_info = self.render_interface_info(@local.local_interfaces)
        
        @gateway.prepare(@local.default_gateways)
        gateway_quality = @gateway.diagnose 
        self.lan_status = !@gateway.check_gateway_threshold
        self.gw_diag = "#{@gateway.status}\nquality: #{gateway_quality}%"
        self.gw_diag_info = @gateway.message

        @dns.prepare
        @dns.diagnose
        @internet.prepare
	      self.wan_status = @internet.diagnose >= 50 ? true : false
        self.internet_diag = "#{@dns.status}\n#{@internet.status}"
        self.internet_diag_info = "#{@dns.message}\n#{@internet.message}"
      }
    end

    def render_interface_info(int)
      text = []
      int.map { |interface,data|
        text << "interface #{interface}"
        data.each { |data_addr|
          text << " #{data_addr[:address]}/#{data_addr[:netmask]}"
        }
      }
      text.join("\n")
    end

    # change lan icon
    def alternate_lan_icon
      if @lan
        @eb_lan.remove(@lan_ok)
        @eb_lan.add(@lan_ok_alt)
        @lan = false
      else
        @eb_lan.remove(@lan_ok_alt)
        @eb_lan.add(@lan_ok)
        @lan = true
      end
    end

    def change_lan_icon
      return false if @eb_lan.destroyed?
      return if @lan_diag_end
      if @lan_status.nil? # lan status undefined
        self.alternate_lan_icon
      else
        # remove old icon
        if @lan
          @eb_lan.remove(@lan_ok)
        else
          @eb_lan.remove(@lan_ok_alt)
        end
        if @lan_status == true
          @eb_lan.add(@lan_ok)
        else
          @eb_lan.add(@lan_ko)
        end
        @lan_diag_end = true # last time we go here
      end
      @eb_lan.show_all
    end

    # change wan icon
    def alternate_wan_icon
      if @wan
        @eb_wan.remove(@wan_ok)
        @eb_wan.add(@wan_ok_alt)
        @wan = false
      else
        @eb_wan.remove(@wan_ok_alt)
        @eb_wan.add(@wan_ok)
        @wan = true
      end
    end
    def change_wan_icon
      return false if @eb_wan.destroyed?
      return if @wan_diag_end
      if @wan_status.nil? # wan status undefined
        self.alternate_wan_icon
      else
        # remove old icon
        if @wan
          @eb_wan.remove(@wan_ok)
        else
          @eb_wan.remove(@wan_ok_alt)
        end
        if @wan_status == true
          @eb_wan.add(@wan_ok)
        else
          @eb_wan.add(@wan_ko)
        end
        @wan_diag_end = true # last time we go here
      end
      @eb_wan.show_all
    end

    # set summary info
    def local_diag=(diag)
      @local_diag = diag
      @label_local_diag.markup="<span foreground=\"#222222\">#{diag}</span>"
      @label_local_diag.show
    end
    def gw_diag=(diag)
      @gw_diag = diag
      @label_gw_diag.markup="<span foreground=\"#222222\">#{diag}</span>"
      @label_gw_diag.show
    end
    def internet_diag=(diag)
      @internet_diag = diag
      @label_internet_diag.markup="<span foreground=\"#222222\">#{diag}</span>"
      @label_internet_diag.show
    end

    # set links
    def lan_status=(status)
      @lan_status = status
    end
    def wan_status=(status)
      @wan_status = status
    end

    # set tooltip for the 3 main items
    def local_diag_info=(text)
      @vb1.tooltip_text=text
    end
    def gw_diag_info=(text)
      @vb2.tooltip_text=text
    end
    def internet_diag_info=(text)
      @vb3.tooltip_text=text
    end
  end
end
