require 'gtk3'
require 'fileutils'
require 'netdiag/config'
module Netdiag
  class Preferences < Gtk::Window
    def initialize
      super
      @builder = Gtk::Builder.new
      @builder.add_from_file("#{File.dirname(File.expand_path(__FILE__))}/../preferences.ui")

      @builder.connect_signals{ |handler| method(handler) }
      @window = @builder.get_object('main_window')
      @theme = @builder.get_object('theme')
      @ipv4_mandatory = @builder.get_object('ipv4_mandatory')
      @ipv6_mandatory = @builder.get_object('ipv6_mandatory')
      @test_dns = @builder.get_object('test_dns')
      @test_url = @builder.get_object('test_url')
      self.insert_config
    end

    def get_theme_list
      Dir.entries("#{File.dirname(File.expand_path(__FILE__))}/../static").select { |f| !File.directory? f }
    end


    def insert_config
      i=0
      self.get_theme_list.each do |t|
        @theme.append_text(t)
        @theme.active=i if t == Netdiag::Config.theme
        i += 1
      end
      @test_dns.text = Netdiag::Config.test_dns
      @test_url.text = Netdiag::Config.test_url
      @ipv4_mandatory.active = Netdiag::Config.gateways[:ipv4_mandatory]
      @ipv6_mandatory.active = Netdiag::Config.gateways[:ipv6_mandatory]
    end
    

    # save clicked
    def save
      _settings = {
        :theme    => @theme.active_text,
        :test_url => @test_url.text,
        :test_dns => @test_dns.text,
        :gateways => {
                      :ipv4_mandatory => @ipv4_mandatory.active?,
                      :ipv6_mandatory => @ipv6_mandatory.active?,
                    }
      }
      Netdiag::Config.save("#{ENV['HOME']}/.config/netindic/config.yaml", _settings)
      Netdiag::Config.load!("#{ENV['HOME']}/.config/netindic/config.yaml")
      self.close
    end

    # cancel clicked
    def cancel
      self.close
    end

    def show
      @window.show_all
    end

    def close
      @window.destroy
    end
  end
end
