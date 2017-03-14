require 'yaml'
require 'pathname'
module Netdiag
  class Config
    def initialize(config_dir=nil)
      @config_dir = config_dir.nil? ? find_config_dir : config_dir
      @cnf = self.load_default_config
      self.load_config
      self.parse_config
    end

    # put your configuration in the file .config/netdiag/config.yaml
    # this config dir is reversed searched from the current directory
    def find_config_dir(dir = Pathname.new("."))
      app_config_dir = dir + ".config/netdiag"
      if File.exist?(app_config_dir)
        app_config_dir.expand_path
      else
        return nil if dir.expand_path.root?
        find_config_dir(dir.parent)
      end
    end

    def load_default_config
      cnf = Hash.new
      cnf[:theme] = 'iconic'
      cnf[:test_url] = 'http://httpbin.org/get'
      cnf[:test_dns] = 'root-servers.org'
      return cnf
    end


    def load_config
      begin
        @cnf.merge!(YAML::load_file("#{@config_dir}/config.yaml"))
      rescue Exception => e
        $stderr.puts "Can't load config file: #{e.message}. Using defaults"
      end
    end

    # this creates a method per configuration object
    def parse_config
      @cnf.each do |k,v|
        define_singleton_method(k.to_s) do
          return v
        end
      end
    end

  end
end
