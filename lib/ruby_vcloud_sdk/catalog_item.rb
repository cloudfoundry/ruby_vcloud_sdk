require_relative "session"
require_relative "infrastructure"

module VCloudSdk
  # Represents the calalog item in calalog.
  class CatalogItem
    include Infrastructure

    def initialize(session, catalog_item_link)
      @session = session
      @catalog_item_link = catalog_item_link
    end

    def name
      entity[:name]
    end

    def type
      entity[:type]
    end

    def href
      entity[:href]
    end

    def remove_link
      connection.get(@catalog_item_link).remove_link
    end

    def to_s
      "Catalog Item '#{name}' of type '#{type}'"
    end

    private

    def entity
      catalog_item_xml_node = connection.get(@catalog_item_link)
      catalog_item_xml_node.entity
    end
  end
end
