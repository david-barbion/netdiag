require 'ipaddr'
module Netdiag
  class Conninfo
    def initialize(interface, gateway, internet)
      @builder = Gtk::Builder.new
      @builder.add_from_file("#{File.dirname(File.expand_path(__FILE__))}/../ui/conninfo.ui")

      @builder.connect_signals{ |handler| method(handler) }
      @window = @builder.get_object('conn_info')
      @notebook = @builder.get_object('notebook_int')

      interface.prepare
      gateway.prepare(interface.default_gateways)
      internet.prepare
      
      # process each interface
      interface.local_interfaces.each do |int,addr|
        next if int == 'lo'
        child = Gtk::Box.new(:horizontal)   # notebook page
        left_box = Gtk::Box.new(:vertical)  # connection pane, items
        left_box.spacing=5
        right_box = Gtk::Box.new(:vertical) # connection pane, values
        right_box.spacing=5
        tab = Gtk::Label.new(int)           # tab name

        # process each address
        addr.each do |a|                    
          # get matching gateway if any
          net = IPAddr.new("#{a[:address].gsub(/%.*/, '')}/#{a[:netmask]}")
          net_gw = ''
          interface.default_gateways.each do |gw|
            net_gw = gw if net.include?(gw.gsub(/%.*/, '')) 
          end
          # pack left item and right values
          left_box.pack_start(Gtk::Label.new('IP address:').set_xalign(0) )
          right_box.pack_start(Gtk::Label.new(a[:address]).set_xalign(0))
          left_box.pack_start(Gtk::Label.new('Subnet mask:').set_xalign(0))
          right_box.pack_start(Gtk::Label.new(a[:netmask]).set_xalign(0))
          left_box.pack_start(Gtk::Alignment.new(0,0,0,0).set_bottom_padding(15).add(Gtk::Label.new('Gateway:').set_xalign(0)))
          right_box.pack_start(Gtk::Alignment.new(0,0,0,0).set_bottom_padding(15).add(Gtk::Label.new(net_gw).set_xalign(0)))
        end
        # pack both pane to child page
        child.pack_start(Gtk::Alignment.new(0,0,0,0).set_padding(5,5,5,5).add(left_box))
        child.pack_start(Gtk::Alignment.new(0,0,0,0).set_padding(5,5,5,5).add(right_box))
        # add the page
        @notebook.append_page(Gtk::Alignment.new(0,0,0,0).set_padding(5,5,5,5).add(child), tab)
      end
    end

    def show
      @window.show_all
    end

    def close
      @window.destroy
    end
  end
end
