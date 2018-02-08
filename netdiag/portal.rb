require 'webkit2-gtk'

RELOAD_MAX_TRIES=50 # this seems a little bit overkill...

module Netdiag
  # manage portal window
  class WindowPortal < Gtk::Window
    attr_reader :pom_disable_button
    def initialize(url)
      super
      @url = url
      @redirect_url = ''
      @last_url = ''
      interface
    end

    def interface
      @vbox = Gtk::Box.new(:vertical)
      header_bar = Gtk::HeaderBar.new
      header_bar.set_title('Authentication needed')
      header_bar.set_show_close_button(true)

      icon = Gio::ThemedIcon.new('format-justify-fill-symbolic')
      image = Gtk::Image.new(:icon => icon, :size => Gtk::IconSize::BUTTON)

      @pom_disable_button = []
      @pom_disable_button[0] = Gtk::ModelButton.new
      @pom_disable_button[0].text = 'Disable for next 5 minutes'
      @pom_disable_button[0].halign = Gtk::Align::FILL
      @pom_disable_button[1] = Gtk::ModelButton.new
      @pom_disable_button[1].text = 'Disable for next 30 minutes'
      @pom_disable_button[1].halign = Gtk::Align::FILL
      @pom_disable_button[2] = Gtk::ModelButton.new
      @pom_disable_button[2].text = 'Disable for next hour'
      @pom_disable_button[2].halign = Gtk::Align::FILL
      sep = Gtk::SeparatorMenuItem.new
      @portal_properties = Gtk::ModelButton.new
      @portal_properties.text = 'Portal properties'
      @portal_properties.halign = Gtk::Align::FILL

      @portal_properties.signal_connect('clicked') do
        show_portal_properties
      end

      menubox = Gtk::Box.new(:vertical)
      menubox.add(@portal_properties)
      menubox.add(sep)
      menubox.add(@pom_disable_button[0])
      menubox.add(@pom_disable_button[1])
      menubox.add(@pom_disable_button[2])
      menubox.margin_left = 10
      menubox.margin_right = 10
      menubox.margin_top = 10
      menubox.margin_bottom = 10
      menubox.show_all

      pom = Gtk::PopoverMenu.new
      pom.set_position(Gtk::PositionType::BOTTOM)
      pom.add(menubox)

      pom_button = Gtk::MenuButton.new
      pom_button.set_image(image)
      pom_button.set_popover(pom)

      header_bar.pack_end(pom_button)

      @view_context = WebKit2Gtk::WebContext.new
      @view_context.set_tls_errors_policy(WebKit2Gtk::TLSErrorsPolicy::IGNORE)
      @view = WebKit2Gtk::WebView.new(:context => @view_context)
      @vbox.pack_start(@view, :expand => true, :fill => true)
      self.set_titlebar(header_bar)
      self.add(@vbox)
      self.set_default_size 544, 380
      self.window_position = :center
      self.icon_name = 'system-lock-screen'

      # stores URI when loading state changed
      # this permits to keep the redirection URL (ie, the captive portal URL)
      @view.signal_connect('load-changed') do |web_view, load_event, _user_data|
        @redirect_url = web_view.uri if load_event == WebKit2Gtk::LoadEvent::REDIRECTED
        @last_url = web_view.uri if load_event == WebKit2Gtk::LoadEvent::FINISHED
      end

      # intercept load errors, this can be caused by network problem,
      # bad response from captive portal
      # if such an error is catched, netdiag will try to reload the portal page
      # for RELOAD_MAX_TRIES
      @view.signal_connect("load-failed") do |web_view, load_event, failing_uri, _error|
        retry_load_portal
      end
    end

    # reload the current page
    def retry_load_portal
      return false if @tries.zero?
      @tries -= 1
      @view.load_uri(@url)
    end

    # initiate a new load
    def reload_portal
      @tries = RELOAD_MAX_TRIES
      @view.load_uri(@url)
    end

    def url
      @view.uri
    end

    def show_portal_properties
      puts "Current URL: #{self.url}"
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
      @window.pom_disable_button[0].signal_connect("clicked") do
        @disabled_to = Time.now.to_i + 300
        @keep_open = false
        self.close_portal_authenticator_window
      end
      @window.pom_disable_button[1].signal_connect("clicked") do
        @disabled_to = Time.now.to_i + 1800
        @keep_open = false
        self.close_portal_authenticator_window
      end
      @window.pom_disable_button[2].signal_connect("clicked") do
        @disabled_to = Time.now.to_i + 3600
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






