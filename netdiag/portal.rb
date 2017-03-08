require 'webkit2-gtk'

module Netdiag
  class WindowPortal < Gtk::Window
    def initialize(uri)
      super
      @uri = uri
      @view = WebKit2Gtk::WebView.new
      self.add(@view)
      self.set_default_size 544, 280
      self.window_position = :center
    end

    def reload_portal
      @view.load_uri(@uri)
      @view.reload_bypass_cache
    end

  end

  class Portal
    def initialize(uri="http://httpbin.org")
      @keep_open=false
      @uri = uri
      @opened = false
    end

    def open_portal_authenticator_window(args={})
      return if self.is_opened?
      @window = Netdiag::WindowPortal.new(@uri)
      @window.signal_connect("delete-event") do
        @keep_open=false
        self.close_portal_authenticator_window
        true
      end
      @keep_open=true if args[:keep_open]
      @window.reload_portal
      @window.show_all
      @opened = true
    end

    def close_portal_authenticator_window
      return if self.is_closed? or @keep_open
      @window.destroy
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






