require "forwardable"
require_relative "infrastructure"
require_relative "ip_ranges"

module VCloudSdk

  ##############################################################################
  # This class represents a Edge Gateway in the Virtual Data Center. 
  ##############################################################################
  class EdgeGateway
    include Infrastructure

    extend Forwardable
    def_delegator :entity_xml, :name

    ############################################################################
    # Initializes a EdgeGateway object associated with a vCloud Session and the
    # the Edge Gateway's link 
    # @param session   [Session] The client's session
    # @param link      [String]  The xml representation of the Edge Gateway
    ############################################################################
    def initialize(session, link)
      @session  = session
      @link     = link
    end

    ############################################################################
    # Add Firewall rules to the Edge Gateyay.
    # @param rules [Array]   Array of Hashes representing the rules to be added.
    #                      :name      [String] The name of the rule. 
    #                      :ip_src    [String] The source IP or "Any".
    #                      :ip_dest   [String] The destination IP or "Any".
    #                      :port_src  [String] The source Port or "Any".
    #                      :port_dest [String] The destination IP or "Any".
    #                      :prot      [String] "TCP","UDP", "TCP & UDP", "ICMP",
    #                                           "ANY"    .
    #                      :action    [String] The action to be applied.It can be 
    #                                          "allow" or "deny".
    #                      :enabled   [String] To enable or disable the rule.
    #                                          The options are "true" or "false".
    #
    # @return      [EdgeGateway]  The Edge Gateway object.
    ############################################################################
    def add_fw_rules(rules)
      link      = entity_xml.configure_services_link
      payload   = entity_xml.add_fw_rules(rules)
         
      task      = connection.post(link,
                            payload.configure_services,
                            Xml::ADMIN_MEDIA_TYPE[:EDGE_SERVICES_CONFIG])
      monitor_task(task)
      self
    end
    
    ############################################################################
    # Remove the Firewall rules with IPs destination passed as an argument 
    # @param ips [Array] Array of IPs destination addresses                    
    # @return    [EdgeGateway]  The Edge Gateway object.
    ############################################################################
    def remove_fw_rules(ips)
      link     = entity_xml.configure_services_link
      payload  = entity_xml.remove_fw_rules(ips)

      task    = connection.post(link,
                            payload.configure_services,
                            Xml::ADMIN_MEDIA_TYPE[:EDGE_SERVICES_CONFIG])
      monitor_task(task)
      self
    end
    def ent
      entity_xml
    end
    ############################################################################
    # Add Nat rules to the Edge Gateyay.
    # @param rules [Array]   Array of Hashes representing the rules to be added.
    #                      :description     [String] Description about the rule.
    #                      :rule_type       [String] "SNAT" or "DNAT". 
    #                      :enabled         [String] "true" or "false".
    #                      :interface       [String] The name of the uplink network.
    #                      :original_ip     [String] The original IP or "Any".
    #                      :original_port   [String] The translated IP,"Any" or range ("startIP"-"finalIP").
    #                      :translated_ip   [String] The destination IP or "Any".
    #                      :translated_port [String] 
    #                      :protocol        [String] 
    #
    # @return      [EdgeGateway]  The Edge Gateway object.
    ############################################################################    
    def add_nat_rules(rules)
      link      = entity_xml.configure_services_link
      payload   = entity_xml.add_nat_rules(rules)
      
      task      = connection.post(link,
                            payload.configure_services,
                            Xml::ADMIN_MEDIA_TYPE[:EDGE_SERVICES_CONFIG])
      monitor_task(task)
      self      
    end

    ############################################################################
    # Remove the Nat rules with the VM IPs passed as an argument 
    # @param ips [Array] Array of IPs addresses                    
    # @return    [EdgeGateway]  The Edge Gateway object.
    ############################################################################
    def remove_nat_rules(ips)
      link     = entity_xml.configure_services_link
      payload  = entity_xml.remove_nat_rules(ips)

      task    = connection.post(link,
                            payload.configure_services,
                            Xml::ADMIN_MEDIA_TYPE[:EDGE_SERVICES_CONFIG])
      monitor_task(task)
      self
    end
    
    def public_net_name
      uplink_gateway_interface = entity_xml
                                   .gateway_interfaces
                                   .find { |g| g.interface_type == "uplink" }
      return uplink_gateway_interface.get_nodes("Name").first.content
           
    end

    def public_ip_net
      uplink_gateway_interface = entity_xml
                                   .gateway_interfaces
                                   .find { |g| g.interface_type == "uplink" }

      ip_address = uplink_gateway_interface.get_nodes("IpAddress").first.content.split(".")
      netmask = uplink_gateway_interface.get_nodes("Netmask").first.content.split(".")
     
      ip_net = ""
      ip_net << (ip_address[0].to_i & netmask[0].to_i).to_s << "."
      ip_net << (ip_address[1].to_i & netmask[1].to_i).to_s << "."
      ip_net << (ip_address[2].to_i & netmask[2].to_i).to_s << "."
      ip_net << (ip_address[3].to_i & netmask[3].to_i).to_s

      return ip_net
    end 

    def public_ip_ranges
      uplink_gateway_interface = entity_xml
                                   .gateway_interfaces
                                   .find { |g| g.interface_type == "uplink" }

      ip_ranges = uplink_gateway_interface.ip_ranges
      return IpRanges.new unless ip_ranges

      ip_ranges
        .ranges
        .reduce(IpRanges.new) do |result, i|
          result + IpRanges.new("#{i.start_address}-#{i.end_address}")
        end
    end
  end
end
