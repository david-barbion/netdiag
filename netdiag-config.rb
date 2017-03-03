module Netdiag
  class Config
    def initialize
      #@theme = 'default'
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
  end
end
