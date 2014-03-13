module VCloudSdk

  class InternalDisk
    attr_reader :entity_xml,
                :name, :capacity, :bus_type, :bus_sub_type

    def initialize(entity_xml)
      @entity_xml = entity_xml
      @name = @entity_xml.element_name
      @capacity = @entity_xml.host_resource.attribute("capacity").to_s.to_i
      @bus_type = @entity_xml.host_resource.attribute("busType").to_s
      @bus_sub_type = @entity_xml.host_resource.attribute("busSubType").to_s
    end
  end
end
