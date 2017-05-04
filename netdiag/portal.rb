require 'webkit2-gtk'

RELOAD_MAX_TRIES=50 # this seems a little bit overkill...

module Netdiag

  class WindowPortal < Gtk::Window
    attr_reader :view
    def initialize(uri)
      super
      @url = uri
      @redirect_url = ''
      @last_url = ''
      @vbox = Gtk::Box.new(:vertical)
      @view_context = WebKit2Gtk::WebContext.new
      @view_context.set_tls_errors_policy(WebKit2Gtk::TLSErrorsPolicy::IGNORE)
      @view = WebKit2Gtk::WebView.new(@view_context)
      @vbox.pack_start(Gtk::Label.new.set_markup('<span foreground="#000000">Authentication needed</span>'),:expand => false, :padding => 15)
      @vbox.pack_start(@view, :expand => true, :fill => true)
      self.add(@vbox)
      self.set_default_size 544, 380
      self.window_position = :center
      self.icon_name = 'system-lock-screen'

      # stores URI when loading state changed
      # this permits to keep the redirection URL (ie, the captive portal URL)
      @view.signal_connect("load-changed") do |web_view, load_event, user_data|
        @redirect_url = web_view.uri if load_event == WebKit2Gtk::LoadEvent::REDIRECTED
        @last_url = web_view.uri if load_event == WebKit2Gtk::LoadEvent::FINISHED
      end

      # intercept load errors, this can be caused by network problem,
      # bad response from captive portal
      # if such an error is catched, netdiag will try to reload the portal page
      # for RELOAD_MAX_TRIES
      @view.signal_connect("load-failed") do |web_view, load_event, failing_uri, error|
#        puts "load failed, #{@tries} tries left"
#        puts "URI is #{failing_uri}"
        self.retry_load_portal
      end
    end
   
    # reload the current page
    def retry_load_portal
      return false if @tries == 0
      @tries -= 1
      @view.load_uri(@url)
    end

    # initiate a new load
    def reload_portal
      @tries = RELOAD_MAX_TRIES
      @view.load_uri(@url)
#      @view.reload_bypass_cache
    end

    def get_current_url
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
        uri = @window.get_current_url
        self.close_portal_authenticator_window
        Thread.new do
          self.signal_emit("portal_closed", uri)
        end
        true
      end
      @window.view.signal_connect("submit-form") do |web_view, request, user_data|
puts "form submited"
puts request.instance_variables
pp request.text_fields
#data = request.text_fields.to_s # seems unimplemented
#request.text_fields.each do |k,v|
#  puts "#{k}=#{v}"
#end
        request.submit
      end
      @keep_open=true if args[:keep_open]
      @window.reload_portal
      @window.show_all
      # this hack brings the portal window authenticator to front
      @window.set_keep_above(true)
      @window.set_keep_above(false)
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
