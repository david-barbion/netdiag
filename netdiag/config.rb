require 'yaml'
require 'pathname'
module Netdiag
  class Config
    def initialize(config_dir=nil)
      @config_dir = find_config_dir if config_dir.nil? 
      @cnf = Hash.new
      @cnf[:theme] = 'iconic'
      @cnf[:test_url] = 'http://httpbin.org/get'
      @cnf[:test_dns] = 'root-servers.org'
      self.load_config
      self.parse_config
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

    def load_config
      if File::exist?("#{@config_dir}/config.yaml")
        @cnf.merge!(YAML::load_file("#{@config_dir}/config.yaml"))
      end
    end

    def parse_config
      @cnf.each do |k,v|
        define_singleton_method(k.to_s) do
          return v
        end
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
