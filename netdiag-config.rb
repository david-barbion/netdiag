class NetdiagConfig
  def initialize
    #@theme = 'default'
    @theme = 'iconic'
    @test_url = 'http://httpbin.org/get'
    @test_dns = 'root-servers.org'
  end
  def getTheme
    return @theme
  end
  def getTestUrl
    return @test_url
  end
  def getTestDns
    return @test_dns
  end
end
