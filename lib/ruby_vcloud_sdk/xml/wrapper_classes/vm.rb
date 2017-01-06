module VCloudSdk
  module Xml
    class Vm < Wrapper
      def initialize(xml, ns = nil, ns_definitions = nil)
        super(xml, ns, ns_definitions)
        @logger = Config.logger
      end      

      def vapp_link
        get_nodes(XML_TYPE[:LINK],
                  { type: MEDIA_TYPE[:VAPP] },
                  true)
                  .first
      end

      def product_sections_link
        get_nodes(XML_TYPE[:LINK],
                  { type: MEDIA_TYPE[:PRODUCT_SECTIONS] },
                  true)
                  .first
      end

      def attach_disk_link
        get_nodes(XML_TYPE[:LINK],
                  { rel: "disk:attach",
                    type: MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS] },
                  true).first
      end

      def detach_disk_link
        get_nodes(XML_TYPE[:LINK],
                  { rel: "disk:detach",
                    type: MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS] },
                  true).first
      end

      def description
        nodes = get_nodes("Description")
        return nodes unless nodes
        node = nodes.first
        return node unless node
        node.content
      end

      def description=(value)
        nodes = get_nodes("Description")
        return unless nodes
        node = nodes.first
        return unless node
        node.content = value
        value
      end

      def operating_system
        get_nodes("OperatingSystemSection",nil,false,OVF).first.
            get_nodes("Description",nil,false,OVF).first.content
      end

      def vm_tools     
          tools = get_nodes("VMWareTools")
          return tools.first["version"] if !tools.empty?
          return nil              
      end

      def vmrc_ticket_link
        get_nodes(XML_TYPE[:LINK],
                  { rel: "screen:acquireTicket" },
                  true).first
      end

      def ip_address       
        ips = []
        get_nodes("NetworkConnection").each do |ip|          
          ips << ip.ip_address
          end
        return ips if !ips.empty?
        return nil
      end
      
      def reconfigure_link
        get_nodes(XML_TYPE[:LINK],
                  { rel: "reconfigureVm" },
                  true).first
      end

      def insert_media_link
        get_nodes(XML_TYPE[:LINK],
                  { rel: "media:insertMedia" },
                  true).first
      end

      def install_vmtools_link
        get_nodes(XML_TYPE[:LINK],
                  { rel: "installVmwareTools" },
                  true).first
      end

      def guest_customization_link
         get_nodes("GuestCustomizationSection").first["href"]
      end

      def

      def eject_media_link
        get_nodes(XML_TYPE[:LINK],
                  { rel: "media:ejectMedia" },
                  true).first
      end

      def metadata_link
        get_nodes(XML_TYPE[:LINK],
                  { type: MEDIA_TYPE[:METADATA] },
                  true).first
      end

      def hardware_section
        get_nodes("VirtualHardwareSection",
                  nil,
                  false,
                  OVF)
                  .first
      end

      def network_connection_section
        get_nodes("NetworkConnectionSection",
                  type: MEDIA_TYPE[:NETWORK_CONNECTION_SECTION]).first
      end

      def product_section
        get_nodes("ProductSection", nil, true, OVF).first
      end

      def guest_customization_section
        get_nodes("GuestCustomizationSection").first
      end

      def hard_disk_exists?(disk_id)
          hardware_section.hard_disks.each do |disk|
            return true if disk.disk_id == disk_id
          end
          return false
      end

      # hardware modification methods

      def add_hard_disk(capacity, bus_type, bus_sub_type,disk_id=nil)
        section = hardware_section
        # Create a RASD item
        new_disk = WrapperFactory
                     .create_instance("Item",
                                      nil,
                                      hardware_section.doc_namespaces)
        section.add_item(new_disk)       
        # The order matters!    
        if !disk_id.nil?
          ap = RASD_TYPES[:ADDRESS_ON_PARENT]
          new_disk.add_rasd(ap)
          new_disk.set_rasd(ap,disk_id)          
        end      
        new_disk.add_rasd(RASD_TYPES[:HOST_RESOURCE])
        new_disk.add_rasd(RASD_TYPES[:INSTANCE_ID])
        if !disk_id.nil?
          p = RASD_TYPES[:PARENT]
          new_disk.add_rasd(p)          
          new_disk.set_rasd(RASD_TYPES[:PARENT],1)          
        end
               
        rt = RASD_TYPES[:RESOURCE_TYPE]
        new_disk.add_rasd(rt)
        new_disk.set_rasd(rt, HARDWARE_TYPE[:HARD_DISK])
        host_resource = new_disk.get_rasd(RASD_TYPES[:HOST_RESOURCE])
        host_resource[new_disk.create_qualified_name(
          "capacity", VCLOUD_NAMESPACE)] = capacity.to_s
        host_resource[new_disk.create_qualified_name(
          "busSubType", VCLOUD_NAMESPACE)] = bus_sub_type
        host_resource[new_disk.create_qualified_name(
          "busType", VCLOUD_NAMESPACE)] = bus_type
      end

      def modify_hard_disk(name,new_capacity)
        section = hardware_section
        disks = section.hard_disks
        disk  = disks.find do |d|  
                  d.element_name == name            
                end                      
        host_resource = disk.get_rasd(RASD_TYPES[:HOST_RESOURCE])
        host_resource[disk.create_qualified_name(
          "capacity", VCLOUD_NAMESPACE)] = new_capacity.to_s                                             
      end


      def delete_hard_disk?(disk_name)
        hardware_section.hard_disks.each do |disk|
          if disk.element_name == disk_name
            disk.node.remove
            return true
          end
        end
        false
      end

      def delete_hard_disk_by_id(disk_id)
        hardware_section.hard_disks.each do |disk|
          if disk.disk_id == disk_id
            disk.node.remove
            return true
          end
        end
        false
      end

      def change_cpu_count(quantity)
        @logger.debug("Updating CPU count on vm #{name} to #{quantity} ")
        item = hardware_section.cpu
        item.set_rasd("VirtualQuantity", quantity)
      end

      def change_memory(mb)
        @logger.debug("Updating memory on vm #{name} to #{mb} MB")
        item = hardware_section.memory
        item.set_rasd("VirtualQuantity", mb)
      end

      def change_name(name)
        @logger.debug("Updating name on vm #{name} to #{name} ")
        item = hardware_section.cpu
        item.set_rasd("VirtualQuantity", quantity)
      end  


      # Deletes NIC from VM.  Accepts variable number of arguments for NICs.
      # To delete all NICs from VM use the splat operator
      # ex: delete_nic(vm, *vm.hardware_section.nics)
      def delete_nics(*nics)
        # Trying to remove a NIC without removing the network connection
        # first will cause an error.  Removing the network connection of a NIC
        # in the NetworkConnectionSection will automatically delete the NIC.
        net_conn_section = network_connection_section
        vhw_section = hardware_section
        nics.each do |nic|
          nic_index = nic.nic_index
          @logger.info("Removing NIC #{nic_index} from VM #{name}")
          primary_index = net_conn_section.remove_network_connection(nic_index)
          vhw_section.remove_nic(nic_index)
          vhw_section.reconcile_primary_network(primary_index) if primary_index
        end
      end

      def set_nic_is_connected(nic_index, is_connected)
        net_conn_section = network_connection_section
        connection = net_conn_section.network_connection(nic_index)
        unless connection
          fail ObjectNotFoundError,
               "NIC #{nic_index} cannot be found on VM #{name}."
        end
        connection.is_connected = is_connected
        nil
      end

      def set_primary_nic(nic_index)
        net_conn_section = network_connection_section
        net_conn_section.primary_network_connection_index = nic_index
        nil
      end
    end
  end
end
