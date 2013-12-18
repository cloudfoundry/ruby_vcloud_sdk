module VCloudSdk
  # Shared functions by classes VM and VApp
  module Powerable
    def status
      status_code = entity_xml[:status].to_i
      Xml::RESOURCE_ENTITY_STATUS.each_pair do |k, v|
        return k.to_s if v == status_code
      end

      fail CloudError,
           "Fail to find corresponding status for code '#{status_code}'"
    end

    def power_on
      target = entity_xml
      class_name = self.class.name.split("::").last # such as VApp or VM
      Config.logger.debug "#{class_name} status: #{target[:status]}"
      if is_status?(target, :POWERED_ON)
        Config.logger.info "#{class_name} #{target.name} is already powered-on."
        return
      end

      power_on_link = target.power_on_link
      unless power_on_link
        fail CloudError,
             "#{class_name} #{target.name} not in a state to be powered on."
      end

      Config.logger.info "Powering on #{class_name} #{target.name}."
      task = connection.post(power_on_link, nil)
      task = monitor_task task, @session.time_limit[:power_on]
      Config.logger.info "#{class_name} #{target.name} is powered on."
      task
    end

    def power_off
      target = entity_xml
      class_name = self.class.name.split("::").last # such as VApp or VM
      Config.logger.debug "#{class_name} status: #{target[:status]}"
      if is_status?(target, :SUSPENDED)
        error_msg = "#{class_name} #{target.name} suspended, discard state before powering off."
        fail class_name == "VApp" ? VappSuspendedError : VmSuspendedError,
             error_msg
      end
      if is_status?(target, :POWERED_OFF)
        Config.logger.info "#{class_name} #{target.name} is already powered off."
        return
      end

      power_off_link = target.power_off_link
      unless power_off_link
        fail CloudError, "#{class_name} #{target.name} is not in a state that could be powered off."
      end

      task = connection.post(power_off_link, nil)
      monitor_task task, @session.time_limit[:power_off]
      Config.logger.info "#{class_name} #{target.name} is powered off."

      Config.logger.info "#{class_name} #{target.name} is in powered off state. Need to be undeployed."
      undeploy(target, class_name)
    end

    private

    def is_status?(target, status)
      target[:status] == Xml::RESOURCE_ENTITY_STATUS[status].to_s
    end

    def undeploy(target, class_name)
      params = Xml::WrapperFactory.create_instance("UndeployVAppParams") # Even for VM it's called UndeployVappParams
      task = connection.post(target.undeploy_link, params)
      task = monitor_task(task, @session.time_limit[:undeploy])
      Config.logger.info "#{class_name} #{target.name} is undeployed."
      task
    end
  end
end
