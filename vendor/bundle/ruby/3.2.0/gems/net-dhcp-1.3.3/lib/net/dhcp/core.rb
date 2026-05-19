=begin
**
** core.rb
** 02/OCT/2007
** ETD-Software
**  - Daniel Martin Gomez <etd[-at-]nomejortu.com>
**
** Desc:
**   This file provides a set of classes to work with the DHCP protocol. They 
** provide low level access to all the fields and internals of the protocol.
** 
** See the provided rdoc comments for further information.
**
** Version:
**  v1.0 [02/October/2007]: first released
**  v1.1 [31/October/2007]: file moved under /dhcp/ directory and renamed to
**                          core.rb. Now it only contains core classes to 
**                          encapsulate DHCP messages
**
** License:
**   Please see dhcp.rb or LICENSE.txt for copyright and licensing information.
**
=end

require 'rubygems'

module DHCP
  # -------------------------------------------------------------- dhcp messages
  class Message
    attr_accessor :op, :htype, :hlen, :hops
    attr_accessor :xid
    attr_accessor :secs, :flags
    attr_accessor :ciaddr, :yiaddr, :siaddr, :giaddr, :chaddr
    attr_accessor :sname, :fname
    attr_accessor :options

    alias == eql?
    
    def Message.from_udp_payload(data, opts={})
      opts = {:debug => true}.merge(opts)
      values = data.unpack('C4Nn2N4C16C192NC*')

      params = {
        :op => values.shift,
        :htype => values.shift,
        :hlen => values.shift,
        :hops => values.shift,
      
        :xid => values.shift,
        :secs => values.shift,
        :flags => values.shift,
        :ciaddr => values.shift,
        :yiaddr => values.shift,
        :siaddr => values.shift,
        :giaddr => values.shift,
        :chaddr => values.slice!(0..15),
        :sname => values.slice!(0..63),
        :fname => values.slice!(0..127),
      }
      
      # sname and file are now used
      #not_used = values.slice!(0..191) 127+63 190
      
      return nil unless ($DHCP_MAGIC == values.shift)
      
      #default message class
      msg_class = Message
      #default option class
      opt_class = Option
      
      params[:options] = []
      next_opt = values.shift
      while(next_opt != $DHCP_END)
        p = {
          :type => next_opt,
          :len => values.shift
        }
        p[:payload] = values.slice!(0..p[:len]-1)
        
        # check what is the type of dhcp option
        opt_class = $DHCP_MSG_OPTIONS[p[:type]]
        if opt_class.nil?
          if opts[:debug]
            puts '-------------------- please further investigate!!'
            puts p[:type]
            puts '-------------------- /'
          end
          opt_class = Option
        end
        if (opt_class == MessageTypeOption)
          msg_class = $DHCP_MSG_CLASSES[p[:payload].first]
        end
        params[:options] << opt_class.new(p)
        next_opt = values.shift
      end
      
      if msg_class.nil?
        if opts[:debug]
          puts '-------------------- please further investigate!!'
          p params[:options]
          puts '-------------------- /'
        end
        msg_class = Message
      end
      msg_class.new(params)
    end
  
    def initialize(params = {})
    
      # message operation and options. We need at least an operation and a 
      # MessageTypeOption to create a DHCP message!!
      if (([:op, :options]  & params.keys).size != 2)
        raise ArgumentError, 'you need to specify at least values for :op and :options'
      end
      
      self.op = params[:op]
      
      self.options = params[:options]
      found = false
      self.options.each do |opt|
        next unless opt.class == MessageTypeOption
        found = true
      end
      raise ArgumentError, ':options must include a MessageTypeOption' unless found
    
      #hardware type and length of the hardware address
      self.htype = params.fetch(:htype, $DHCP_HTYPE_ETHERNET)
      self.hlen = params.fetch(:hlen, $DHCP_HLEN_ETHERNET)
    
      # client sets to zero. relay agents may modify
      self.hops = params.fetch(:hops, 0x00)
    
      # initialize a random transaction ID
      self.xid  = params.fetch(:xid, rand(2**32))
    
      # seconds elapsed, flags
      self.secs = params.fetch(:secs, 0x0000)
      self.flags = params.fetch(:flags, 0x0000)
    
      # client, you, next server  and relay agent addresses
      self.ciaddr = params.fetch(:ciaddr, 0x00000000)
      self.yiaddr = params.fetch(:yiaddr, 0x00000000)
      self.siaddr = params.fetch(:siaddr, 0x00000000)
      self.giaddr = params.fetch(:giaddr, 0x00000000)
    
      if (params.key?(:chaddr))
        self.chaddr = params[:chaddr]
        raise 'chaddr field should be of 16 bytes' unless self.chaddr.size == 16
      else
        if Gem.respond_to?(:win_platform?) && Gem.win_platform?
          mac_line = `getmac /fo list`.split("\n").grep(/Physical Address/).first
          if mac_line
            mac = mac_line.strip.split(":")[1].gsub("-","").strip
          end
        else
          ifcfg_out = `/sbin/ifconfig`.chomp
          matches1 = ifcfg_out.scan(/HWaddr ([a-h0-9:]+)/i).flatten  # Linux
          matches2 = ifcfg_out.scan(/ether ([a-h0-9:]+)/i).flatten   # Some Linux (EL7), BSDs
          mac = matches1.first || matches2.first
          mac = mac.gsub(/:/,"") if mac
        end
        mac = '000000000000' if mac.empty?
        self.chaddr = [mac].pack('H*').unpack('CCCCCC')
        self.chaddr += [0x00]*(16-self.chaddr.size)
      end

      if (params.key?(:sname))
        sname = params[:sname]
        case 
        when sname.size == 64
          self.sname = sname
        when sname.size < 64 && sname.class == String
          self.sname = sname.unpack('C64').map {|x| x ? x : 0}
        else
          raise 'sname field should be of 64 bytes or a string of less'
        end
      else
        self.sname = [0x00]*64
      end

      if (params.key?(:fname))
        fname = params[:fname]
        case 
        when fname.size == 128
          self.fname = fname
        when fname.size < 128 && fname.class == String
          self.fname = fname.unpack('C128').map {|x| x ? x : 0}
        else
          raise 'fname field should be of 128 bytes or a string of less'
        end
      else
        self.fname = [0x00]*128
      end
      
    end
  
    def pack()
      out = [
      self.op, self.htype, self.hlen, self.hops, 
      self.xid, 
      self.secs, self.flags, 
      self.ciaddr, 
      self.yiaddr, 
      self.siaddr, 
      self.giaddr
      ].pack('C4Nn2N4')

      if self.chaddr.size >= 16
        out << self.chaddr.pack('C16')
      else
        out << (self.chaddr + [0x00]*(16-self.chaddr.size)).pack('C16')
      end
      # file_name/server_name for pxe
      out << self.sname.pack('C64')
      out << self.fname.pack('C128')
    
      # sname and file
      # out << ([0x00]*192).pack('C192')
    
      out << [$DHCP_MAGIC].pack('N')
      self.options.each do |option|
        out << option.pack
      end
      out << [$DHCP_END].pack('C')
      
      # add padding up to 300 bytes
      if out.size < 300
        out << ([$DHCP_PAD]*(300-out.size)).pack('C*')
      end
      return out
    end
    
    def eql?(obj)
      # objects must be of the same class
      return false unless (self.class == obj.class)
      
      vars1 = self.instance_variables
      
      # first make sure that the :options var is equal
      opt1 = self.instance_variable_get('@options')
      opt2 = obj.instance_variable_get('@options')
      
      return false unless opt1.eql?(opt2)
      vars1.delete('@options')
      
      # check all the other instance vairables
      vars1.each do |var|
        return false unless (self.instance_variable_get(var) == obj.instance_variable_get(var))
      end
      
      return true
    end
    
    
    
    def to_s
      out = "DHCP Message\r\n"
      out << "\tFIELDS:\r\n"
      out << "\t\tTransaction ID = 0x#{self.xid.to_s(16)}\r\n"
      out << "\t\tClient IP address = #{[self.ciaddr].pack('N').unpack('C4').join('.')}\r\n"
      out << "\t\tYour IP address = #{[self.yiaddr].pack('N').unpack('C4').join('.')}\r\n"      
      out << "\t\tNext server IP address = #{[self.siaddr].pack('N').unpack('C4').join('.')}\r\n"
      out << "\t\tRelay agent IP address = #{[self.giaddr].pack('N').unpack('C4').join('.')}\r\n"      
      out << "\t\tHardware address = #{self.chaddr.slice(0..(self.hlen-1)).collect do |b| b.to_s(16).upcase.rjust(2,'0') end.join(':')}\r\n"
      out << "\t\tServer Name = #{self.sname.pack('n*').unpack('A*')}\r\n"
      out << "\t\tFile Name = #{self.fname.pack('n*').unpack('A*')}\r\n"
      out << "\tOPT:\r\n"
      self.options.each do |opt|
        out << "\t\t #{opt.to_s}\r\n"
      end
      return out
    end
  end

  # Client broadcast to locate available servers.
  class Discover < Message
    def initialize(params={})
      params[:op] = $DHCP_OP_REQUEST
      # if an :options field is provided, we use it, otherwise, a default is set
      params[:options] = params.fetch(:options, [MessageTypeOption.new, ParameterRequestListOption.new])
      super(params)
    end
  end

  # Server to client in response to DHCPDISCOVER with offer of configuration
  # parameters.
  #
  # By default an ACK message will contain a Server Identifier (0.0.0.0) and
  # a Domain Name ('nomejortu.com') option.
  class Offer < Message
    def initialize(params={})
      params[:op] = $DHCP_OP_REPLY
      params[:options] = params.fetch(:options, [
      MessageTypeOption.new({:payload=>[$DHCP_MSG_OFFER]}), 
      ServerIdentifierOption.new,
      DomainNameOption.new
      ])
      super(params)
    end        
  end
  
  # Client message to servers either (a) requesting offered parameters from one 
  # server and implicitly declining offers from all others, (b) confirming
  # correctness of previously allocated address after, e.g., system reboot, or 
  # (c) extending the lease on a particular network address.  
  class Request < Message
    def initialize(params={})
      params[:op] = $DHCP_OP_REQUEST
      params[:options] = params.fetch(:options, [MessageTypeOption.new({:payload=>[$DHCP_MSG_REQUEST]}), ParameterRequestListOption.new])
      super(params)
    end
  end

  #
  #   DHCPDECLINE  -  Client to server indicating network address is already
  #                   in use.
  
  # Server to client with configuration parameters, including committed network
  # address.
  #
  # By default an ACK message will contain a Server Identifier (0.0.0.0) and
  # a Domain Name ('nomejortu.com') option.
  class ACK < Message
    def initialize(params={})
      params[:op] = $DHCP_OP_REPLY
      params[:options] = params.fetch(:options, [
      MessageTypeOption.new({:payload=>[$DHCP_MSG_ACK]}), 
      ServerIdentifierOption.new,
      DomainNameOption.new
      ])
      super(params)
    end    
  end
  
  #   DHCPNAK      -  Server to client indicating client's notion of network
  #                   address is incorrect (e.g., client has moved to new
  #                   subnet) or client's lease as expired

  # Client to server relinquishing network address and cancelling remaining
  # lease.
  #
  # By default an ACK message will contain a Server Identifier (0.0.0.0)
  class Release < Message
    def initialize(params={})
      params[:op] = $DHCP_OP_REQUEST
      params[:options] = params.fetch(:options, [
      MessageTypeOption.new({:payload=>[$DHCP_MSG_RELEASE]}), 
      ServerIdentifierOption.new
      ])
      super(params)
    end    
  end
  
  # Client to server, asking only for local configuration parameters; client 
  # already has externally configured network address.  
  class Inform < Message
    def initialize(params={})
      params[:op] = $DHCP_OP_REQUEST
      params[:options] = params.fetch(:options, [MessageTypeOption.new({:payload=>[$DHCP_MSG_INFORM]}), ParameterRequestListOption.new])
      super(params)
    end
  end

  # ------------------------------------ map from values of fields to class names

  $DHCP_MSG_CLASSES = {
    $DHCP_MSG_DISCOVER  => Discover,
    $DHCP_MSG_OFFER     => Offer,
    $DHCP_MSG_REQUEST   => Request,
    #    $DHCP_MSG_DECLINE=     0x04
    $DHCP_MSG_ACK       => ACK,
    #    $DHCP_MSG_NACK=        0x06
    $DHCP_MSG_RELEASE   => Release,
    $DHCP_MSG_INFORM    => Inform
  }

  
end
