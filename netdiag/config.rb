require 'pathname'
module Netdiag
  class Config
    attr_reader :theme
    attr_reader :test_url
    attr_reader	:test_dns
    attr_reader :config_dir

    def initialize(config_dir=nil)
      @config_dir = find_config_dir if config_dir.nil? 
      @theme = 'iconic'
      @test_url = 'http://httpbin.org/get'
      @test_dns = 'root-servers.org'
    end
    def get_theme
      return @theme
    end
    def get_test_url
      return @test_url
    end
    def get_test_dns
      return @test_dns
    end

    # put your configuration in the directory .netdiag
    # this config dir is reversed searched from the current directory
    def find_config_dir(dir = Pathname.new("."))
      app_config_dir = dir + ".netdiag"
      if dir.children.include?(app_config_dir)
        app_config_dir.expand_path
      else
        return nil if dir.expand_path.root?
        find_config_dir(dir.parent)
      end
    end

    def dump_config
      puts "theme: '#{@theme}'"
      puts "test_url: '#{@test_url}'"
      puts "test_dns: '#{@test_dns}'"
      puts "config_dir: '#{@config_dir}'"
    end

  end
end
