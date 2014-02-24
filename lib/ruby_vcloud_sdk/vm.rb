require "forwardable"
require_relative "infrastructure"
require_relative "powerable"

module VCloudSdk
  class VM
    include Infrastructure
    include Powerable

    extend Forwardable
    def_delegator :entity_xml, :name

    def initialize(session, link)
      @session = session
      @link = link
    end

    def href
      @link
    end

    # returns size of memory in megabyte
    def memory
      m = entity_xml
                 .hardware_section
                 .memory
      allocation_units = m.get_rasd_content(Xml::RASD_TYPES[:ALLOCATION_UNITS])
      bytes = parse_memory_allocation_units(allocation_units)

      virtual_quantity = m.get_rasd_content(Xml::RASD_TYPES[:VIRTUAL_QUANTITY]).to_i
      memory_mb = virtual_quantity * bytes / 1_048_576 # 1048576 = 1024 * 1024 = 2^20
      fail CloudError,
           "Size of memory is zero!" if memory_mb == 0
      memory_mb
    end

    def independent_disks
      hardware_section = entity_xml.hardware_section
      disks = []
      hardware_section.hard_disks.each do |disk|
        disk_link = disk.host_resource.attribute("disk")
        unless disk_link.nil?
          disks << VCloudSdk::Disk.new(@session, disk_link.to_s)
        end
      end
      disks
    end

    def list_disks
      entity_xml.hardware_section.hard_disks.map do |disk|
        disk_link = disk.host_resource.attribute("disk")
        if disk_link.nil?
          disk.element_name
        else
          "#{disk.element_name} (#{VCloudSdk::Disk.new(@session, disk_link.to_s).name})"
        end
      end
    end

    def attach_disk(disk)
      fail CloudError,
           "Disk '#{disk.name}' of link #{disk.href} is attached to VM '#{disk.vm.name}'" if disk.attached?

      task = connection.post(entity_xml.attach_disk_link.href,
                             disk_attach_or_detach_params(disk),
                             Xml::MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS])
      task = monitor_task(task)

      Config.logger.info "Disk '#{disk.name}' is attached to VM '#{name}'"
      task
    end

    def detach_disk(disk)
      parent_vapp = vapp
      if parent_vapp.status == "SUSPENDED"
        fail VmSuspendedError,
             "vApp #{parent_vapp.name} suspended, discard state before detaching disk."
      end

      unless (vm = disk.vm).href == href
        fail CloudError,
             "Disk '#{disk.name}' is attached to other VM - name: '#{vm.name}', link '#{vm.href}'"
      end

      task = connection.post(entity_xml.detach_disk_link.href,
                             disk_attach_or_detach_params(disk),
                             Xml::MEDIA_TYPE[:DISK_ATTACH_DETACH_PARAMS])
      task = monitor_task(task)

      Config.logger.info "Disk '#{disk.name}' is detached from VM '#{name}'"
      task
    end

    def insert_media(catalog_name, media_file_name)
      catalog = find_catalog_by_name(catalog_name)
      media = catalog.find_item(media_file_name, Xml::MEDIA_TYPE[:MEDIA])

      vm = entity_xml
      media_xml = connection.get(media.href)
      Config.logger.info("Inserting media #{media_xml.name} into VM #{vm.name}")

      wait_for_running_tasks(media_xml, "Media '#{media_xml.name}'")

      task = connection.post(vm.insert_media_link.href,
                             media_insert_or_eject_params(media),
                             Xml::MEDIA_TYPE[:MEDIA_INSERT_EJECT_PARAMS])
      monitor_task(task)
    end

    def eject_media(catalog_name, media_file_name)
      catalog = find_catalog_by_name(catalog_name)
      media = catalog.find_item(media_file_name, Xml::MEDIA_TYPE[:MEDIA])

      vm = entity_xml
      media_xml = connection.get(media.href)
      Config.logger.info("Ejecting media #{media_xml.name} from VM #{vm.name}")

      wait_for_running_tasks(media_xml, "Media '#{media_xml.name}'")

      task = connection.post(vm.eject_media_link.href,
                             media_insert_or_eject_params(media),
                             Xml::MEDIA_TYPE[:MEDIA_INSERT_EJECT_PARAMS])
      monitor_task(task)
    end

    private

    def disk_attach_or_detach_params(disk)
      Xml::WrapperFactory
        .create_instance("DiskAttachOrDetachParams")
        .tap do |params|
        params.disk_href = disk.href
      end
    end

    def vapp
      vapp_link = entity_xml.vapp_link
      VCloudSdk::VApp.new(@session, vapp_link.href)
    end

    def media_insert_or_eject_params(media)
      Xml::WrapperFactory.create_instance("MediaInsertOrEjectParams").tap do |params|
        params.media_href = media.href
      end
    end

    def parse_memory_allocation_units(allocation_units)
      # allocation_units is in the form of "byte * modifier * base ^ exponent" such as "byte * 2^20"
      # "modifier", "base" and "exponent" are positive integers and optional.
      # "base" and "exponent" must be present together.
      # Parsing logic: remove starting "byte" and first char "*" and replace power "^" with ruby-understandable "**"
      bytes = allocation_units.sub(/byte\s*(\*)?/, "").sub(/\^/, "**")
      return 1 if bytes.empty? # allocation_units is "byte" without "modifier", "base" or "exponent"
      fail unless bytes =~ /(\d+\s*\*)?(\d+\s*\*\*\s*\d+)?/
      eval bytes
    rescue
      raise ApiError,
            "Unexpected form of AllocationUnits of memory: '#{allocation_units}'"
    end
  end
end
