#!/usr/bin/env ruby

#Gtk.init

#window = Gtk::Window.new
#gateway_img = Gtk::Image.new(:pixbuf => gateway_pb)
##newi = Gtk::ImageMenuItem.new(:stock_id => Gtk::Stock::NEW, :accel_group => agr)
#fixed = Gtk::Fixed.new
#fixed.put gateway_img, 20, 20
#add fixed
##button = Gtk::Button.new(:label => 'Bonjour tout le monde')
##window.add(button)
#
##button.show
#window.show
#
#Gtk.main
require "gtk3"
module Netdiag
  class Window < Gtk::Window

    def initialize
        Gtk.init
	super
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
    end

    def init_ui
        override_background_color :normal, Gdk::RGBA::new(0.8, 0.8, 0.8, 1)

        begin
            local_pb = Gdk::Pixbuf.new(:file => "#{File.dirname(File.expand_path(__FILE__))}/../static/local.png")
            gateway_pb = Gdk::Pixbuf.new(:file => "#{File.dirname(File.expand_path(__FILE__))}/../static/gateway.png")
            internet_pb = Gdk::Pixbuf.new(:file => "#{File.dirname(File.expand_path(__FILE__))}/../static/internet.png")
            conn_pb = Gdk::Pixbuf.new(:file => "#{File.dirname(File.expand_path(__FILE__))}/../static/connection.png")
            conn_pb_alt = Gdk::Pixbuf.new(:file => "#{File.dirname(File.expand_path(__FILE__))}/../static/connection.png")
            conn_pb_alt = conn_pb_alt.saturate_and_pixelate(5.5, true)
            no_conn_pb = Gdk::Pixbuf.new(:file => "#{File.dirname(File.expand_path(__FILE__))}/../static/no_connection.png")
            small_local_pb = local_pb.scale(128, 128, Gdk::Pixbuf::INTERP_BILINEAR)
            small_gateway_pb = gateway_pb.scale(128, 128, Gdk::Pixbuf::INTERP_BILINEAR)
            small_internet_pb = internet_pb.scale(128, 128, Gdk::Pixbuf::INTERP_BILINEAR)
        rescue IOError => e
            puts e
            puts "cannot load images"
            exit
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

        @vb1.pack_start(image1)
        @vb1.pack_start(Gtk::Label.new.set_markup('<span foreground="#000000">Local</span>'))
        @vb1.pack_start(@label_local_diag)
        hb.pack_start(@vb1)
        hb.pack_start(@eb_lan)
        @vb2.pack_start(image2)
        @vb2.pack_start(Gtk::Label.new.set_markup('<span foreground="#000000">Gateway</span>'))
        @vb2.pack_start(@label_gw_diag)
        hb.pack_start(@vb2)
        hb.pack_start(@eb_wan)
        @vb3.pack_start(image3)
        @vb3.pack_start(Gtk::Label.new.set_markup('<span foreground="#000000">Internet</span>'))
        @vb3.pack_start(@label_internet_diag)
        hb.pack_start(@vb3)
        add hb

        set_title "Network diag"
        signal_connect "destroy" do
            self.close_window
        end

        set_default_size 544, 280
        self.window_position = :center
	self.open_window
    end

    def close_window
      self.hide
    end

    def open_window
        self.show_all
        GLib::Timeout.add(1000) do
          self.change_lan_icon
          true
        end
        GLib::Timeout.add(1000) do
          self.change_wan_icon
          true
        end
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
