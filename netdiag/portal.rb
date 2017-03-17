require 'webkit2-gtk'

RELOAD_MAX_TRIES=50 # this seems a little bit overkill...

module Netdiag

  class WindowPortal < Gtk::Window
    type_register
    attr_reader :view
    signal_new("portal_form_submitted",        # name
               GLib::Signal::RUN_FIRST, # flags
               nil,                     # accumulator (XXX: not supported yet)
               nil,                     # return type (void == nil)
               String                   # parameter types
               )

    def initialize(url)
      super()
      @url = url
      @redirect_url = ''
      @last_url = ''
      @view_context = WebKit2Gtk::WebContext.new
      @view_context.set_tls_errors_policy(WebKit2Gtk::TLSErrorsPolicy::IGNORE)
      @view = WebKit2Gtk::WebView.new(@view_context)
      self.add(@view)
      self.set_default_size 544, 380
      self.window_position = :center

      # stores URI when loading state changed
      # this permits to keep the redirection URL (ie, the captive portal URL)
      @view.signal_connect("load-changed") do |web_view, load_event, user_data|
        case load_event
        when WebKit2Gtk::LoadEvent::REDIRECTED
          @redirect_url = web_view.uri
        when WebKit2Gtk::LoadEvent::FINISHED
          @last_url = web_view.uri
           self.signal_emit("portal_form_submitted", web_view.uri)
        end
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
    def reload_portal(url=@url)
      @tries = RELOAD_MAX_TRIES
      @view.load_uri(url)
#      @view.reload_bypass_cache
    end

    def url
      @view.uri
    end

    def signal_do_portal_form_submitted(*args)
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
    signal_new("form_submitted",        # name
               GLib::Signal::RUN_FIRST, # flags
               nil,                     # accumulator (XXX: not supported yet)
               nil,                     # return type (void == nil)
               String                   # parameter types
               )

    # initialize a new portal
    def initialize(args={})
      super()
      @keep_open=false
      @opened = false
    end

    # open the portal window with the passed URI
    #
    def open_portal_authenticator_window(args={})
      return if self.is_opened?
      @window = Netdiag::WindowPortal.new(args[:uri])
      @window.signal_connect("portal_form_submitted") do |portal, uri|
        self.signal_emit("form_submitted", uri)
      end
      @window.signal_connect("delete-event") do
        @keep_open=false
        uri = @window.url
        self.close_portal_authenticator_window
        Thread.new do
          self.signal_emit("portal_closed", uri)
        end
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

    private

    def signal_do_portal_closed(*args)
    end
    def signal_do_form_submitted(*args)
    end

  end
end






