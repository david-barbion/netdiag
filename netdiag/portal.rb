require 'webkit2-gtk'

RELOAD_MAX_TRIES=50 # this seems a little bit overkill...

module Netdiag

  class WindowPortal < Gtk::Window
    attr_reader :button_disable
    def initialize(url)
      super
      @url = url
      @redirect_url = ''
      @last_url = ''
      @vbox = Gtk::Box.new(:vertical)
      header_bar = Gtk::HeaderBar.new
      header_bar.set_title('Authentication needed')
      header_bar.set_show_close_button(true)
      icon = Gio::ThemedIcon.new('stop')
      image = Gtk::Image.new(:icon => icon, :size => Gtk::IconSize::BUTTON)
      @button_disable = Gtk::Button.new()
      @button_disable.add(image)
      @button_disable.set_tooltip_text('Disable for next 5 minutes')
      header_bar.pack_end(@button_disable)

      @view_context = WebKit2Gtk::WebContext.new
      @view_context.set_tls_errors_policy(WebKit2Gtk::TLSErrorsPolicy::IGNORE)
      @view = WebKit2Gtk::WebView.new(@view_context)
      @vbox.pack_start(@view, :expand => true, :fill => true)
      self.set_titlebar(header_bar)
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

    def url
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
      @disabled_to = 0
    end

    def is_disabled?
      if Time.now.to_i < @disabled_to
        true
      else
        false
      end
    end

    def open_portal_authenticator_window(args={})
      return if self.is_opened?
      @window = Netdiag::WindowPortal.new(args[:uri])
      @window.signal_connect("delete-event") do
        @keep_open=false
        uri = @window.url
        self.close_portal_authenticator_window
        self.signal_emit("portal_closed", uri)
        true
      end
      @keep_open=true if args[:keep_open]
      @window.button_disable.signal_connect("clicked") do
        @disabled_to = Time.now.to_i + 300
        @keep_open = false
        self.close_portal_authenticator_window
      end
      @window.reload_portal
      # this hack brings the portal window authenticator to front
      @window.set_keep_above(true)
      @window.set_keep_above(false)
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






