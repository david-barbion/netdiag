require 'dbus'

module Netdiag
  class NMListener
  
    attr_accessor :callback

    def initialize
      @bus = DBus::SystemBus.instance
      @nm_service = @bus.service("org.freedesktop.NetworkManager")
      @started = false
      @mutex = Mutex.new
      nm_object = @nm_service.object("/org/freedesktop/NetworkManager")
      nm_object.introspect
  
      nm_intf = nm_object["org.freedesktop.NetworkManager"]
      nm_intf.on_signal("DeviceAdded") do |o| 
        @loop.quit
      end
      nm_intf.on_signal("DeviceRemoved") do |o| 
        @loop.quit
      end
    end
  
    # place signals for all known network devices
    def devices_add_signal
      nm_object = @nm_service.object("/org/freedesktop/NetworkManager")
      nm_object.introspect
      nm_devices = @nm_service.object("/org/freedesktop/NetworkManager/Devices")
      poi = DBus::ProxyObjectInterface.new(nm_object, "org.freedesktop.NetworkManager")
      begin
        poi.define_method("getDevices", "") # NM 0.6
        nm_devices = poi.getDevices
      rescue Exception
        poi.define_method("GetDevices", "") # NM 0.7
        nm_devices = poi.GetDevices
      end
      nm_devices.flatten!.each do |node|
        self.device_add_remove(node)
      end
    end
  
    # add StateChanged signal for selected device 
    def device_add_remove(o)
      nm_object = @nm_service.object(o)
      return if !nm_object.is_a?(DBus::ProxyObject)
      nm_device = DBus::ProxyObjectInterface.new(nm_object, "org.freedesktop.NetworkManager.Device")
      nm_device.on_signal("StateChanged") do |new_state, old_state, reason|
        device_state_changed(new_state, old_state, reason, o)
      end
    end
  
    # executed on device state changed (going offline or online)
    def device_state_changed(n,o,r, dev)
      if o == 100 or n == 100 # connection stopped or initialized
        $logger.info("Device #{dev} o=#{o} n=#{n}")
        begin
          @callback.call
        rescue Exception => e
          puts e.message
          puts e.backtrace
        end
      end
    end
  
    def set_callback &block
      @callback = block
    end

    # start dbus loop
    def run
      Thread.new {
        Thread.current[:name] = "dbus"
        while true
          @loop = DBus::Main.new
          @loop << @bus
          self.devices_add_signal
          @loop.run
        end
      }
    end

  end
end
