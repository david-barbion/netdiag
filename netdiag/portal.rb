require 'webkit-gtk'

module Netdiag
  class Portal < Gtk::Window
  
    def initialize(uri="http://httpbin.org")
      super
      @uri = uri
      signal_connect("destroy") do
        self.close_portal_authenticator_window
      end
      @opened = false
      @view = WebKitGtk::WebView.new
      @view.load_uri(uri)
      self.add(@view)
    end

    def open_portal_authenticator_window
      self.show_all
      @opened = true
    end
    def close_portal_authenticator_window
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






