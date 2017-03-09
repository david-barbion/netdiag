require 'webkit2-gtk'

module Netdiag

  class WindowPortal < Gtk::Window
    attr_reader :view
    def initialize(uri)
      super
      @uri = uri
      @view_context = WebKit2Gtk::WebContext.new
      @view_context.set_tls_errors_policy(WebKit2Gtk::TLSErrorsPolicy::IGNORE)
      @view = WebKit2Gtk::WebView.new(@view_context)
      self.add(@view)
      self.set_default_size 544, 380
      self.window_position = :center
    end

    def reload_portal
      @view.load_uri(@uri)
      @view.reload_bypass_cache
    end

    def uri
      @view.uri
    end

  end

  class Portal < GLib::Object
    type_register
    signal_new("portal_closed",         # name
               GLib::Signal::RUN_FIRST, # flags
               nil,                     # accumulator (XXX: not supported yet)
               nil,                     # return type (void == nil)
               String                   # parameter types
               )


    def initialize
      super
      @keep_open=false
      @opened = false
    end

    def open_portal_authenticator_window(args={})
      return if self.is_opened?
      @window = Netdiag::WindowPortal.new(args[:uri])
      @window.signal_connect("delete-event") do
        @keep_open=false
        uri = @window.uri
        self.close_portal_authenticator_window
        Thread.new do
          self.signal_emit("portal_closed", uri)
        end
        true
      end
      @window.view.signal_connect("submit-form") do |web_view, request, user_data|
puts "form submited"
pp user_data
p request.get_type
request.get_text_fields().each do |k,v|
  puts "#{k}=#{v}"
end
        request.submit
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

    private

    def signal_do_portal_closed(*args)
    end

  end
end






