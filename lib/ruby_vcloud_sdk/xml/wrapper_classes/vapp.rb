module VCloudSdk
  module Xml
    class VApp < Wrapper
      def description
        get_nodes("Description").first.content
      end

      def network_config_section
        get_nodes("NetworkConfigSection").first
      end

      def power_on_link
        get_nodes("Link", {"rel" => "power:powerOn"}, true).first
      end

      def power_off_link
        get_nodes("Link", {"rel" => "power:powerOff"}, true).first
      end

      def reboot_link
        get_nodes("Link", {"rel" => "power:reboot"}, true).first
      end

      def running_tasks
        get_nodes(XML_TYPE[:TASK], { status: TASK_STATUS[:RUNNING] })
      end

      def tasks
        get_nodes(XML_TYPE[:TASK])
      end

      def undeploy_link
        get_nodes("Link", {"rel" => "undeploy"}, true).first
      end

      def discard_state
        get_nodes("Link", {"rel" => "discardState"}, true).first
      end

      def recompose_vapp_link
        link = get_nodes(XML_TYPE[:LINK],
                         { rel: "recompose" },
                         true).first
      end

      def vdc_link
        get_nodes(XML_TYPE[:LINK],
                  { type: MEDIA_TYPE[:VDC] },
                  true).first
      end

      def vms
        get_nodes("Vm")
      end

      def vm(name)
        get_nodes("Vm", name: name).first
      end
    end

  end
end
