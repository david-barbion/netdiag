require 'webkit-gtk'

module Netdiag
  class WindowPortal < Gtk::Window
    def initialize(uri)
      super
      @uri = uri
      @view = WebKitGtk::WebView.new
      @view.load_uri(@uri)
      self.add(@view)
      self.set_default_size 544, 280
      self.window_position = :center
    end

    def reload_portal
    puts "reload of #{@view.uri} asked"
      @view.reload_bypass_cache
    end

    def hide
      super
      puts "hide"
    end

  end

  class Portal
    def initialize(uri="http://httpbin.org")
      @uri = uri
      @opened = false
      @window = Netdiag::WindowPortal.new(@uri)
      @window.signal_connect("delete-event") do
        self.close_portal_authenticator_window
        true
      end
    end

    def open_portal_authenticator_window
      return if self.is_opened?
      @window.reload_portal
      @window.show_all
      @opened = true
    end

    def close_portal_authenticator_window
      return if self.is_closed?
      @window.hide
      @opened = false
    end

    def is_closed?
      !@opened
    end

    def is_opened?
      @opened
    end
  end
end






