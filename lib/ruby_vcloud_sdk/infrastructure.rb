module VCloudSdk
  # Shared functions by classes such as Client, Catalog and VDC
  # Make sure instance variable @session is available
  module Infrastructure

    ERROR_STATUSES = [Xml::TASK_STATUS[:ABORTED], Xml::TASK_STATUS[:ERROR],
                      Xml::TASK_STATUS[:CANCELED]]
    SUCCESS_STATUS = [Xml::TASK_STATUS[:SUCCESS]]

    def find_vdc_by_name(name)
      vdc_link = @session.org.vdc_link(name)
      fail ObjectNotFoundError, "VDC #{name} not found" unless vdc_link
      VCloudSdk::VDC.new(@session, connection.get(vdc_link))
    end

    def catalogs
      @session.org.catalogs.map do |catalog|
        VCloudSdk::Catalog.new(@session, catalog)
      end
    end

    def find_catalog_by_name(name)
      catalogs.each do |catalog|
        return catalog if catalog.name == name
      end

      nil
    end

    private

    def connection
      @session.connection
    end

    def monitor_task(
      task,
        time_limit = @session.time_limit[:default],
        error_statuses = ERROR_STATUSES,
        success = SUCCESS_STATUS,
        delay = @session.delay,
        &b)
      iterations = time_limit / delay
      i = 0
      prev_progress = task.progress
      prev_status = task.status
      current_task = task
      while i < iterations
        Config.logger.debug %Q{
          #{current_task.urn} #{current_task.operation} is #{current_task.status}
        }

        if task_is_success(current_task, success)
          if b
            return b.call(current_task)
          else
            return current_task
          end
        elsif task_has_error(current_task, error_statuses)
          fail ApiRequestError,
               "Task #{task.urn} #{task.operation} did not complete successfully."
        elsif task_progressed?(current_task, prev_progress, prev_status)
          Config.logger.debug %Q{
            task status #{prev_status} =>
            #{current_task.status}, progress #{prev_progress}% =>
            #{current_task.progress}%, timer #{i} reset.
          }
          prev_progress = current_task.progress
          prev_status = current_task.status
          i = 0  # Reset clock if status changes or running task makes progress
          sleep(delay)
        else
          Config.logger.debug %Q{
            Approximately #{i * delay}s elapsed waiting for #{current_task.operation} to
            reach #{success.join("/")}/#{error_statuses.join("/")}.
            Checking again in #{delay} seconds.
          }
          if current_task.progress
            Config.logger.debug(
              "Task #{task.urn} progress: #{current_task.progress} %.")
          end
          sleep(delay)
        end
        current_task = connection.get(task)
        i += 1
      end
      fail ApiTimeoutError,
           "Task #{task.operation} did not complete within limit of #{time_limit} seconds."
    end

    def task_progressed?(current_task, prev_progress, prev_status)
      (current_task.progress && (current_task.progress != prev_progress)) ||
        (current_task.status && (current_task.status != prev_status))
    end

    def task_is_success(current_task, success = SUCCESS_STATUS)
      success.map { |s| s.downcase }.find do
        |s| s == current_task.status.downcase
      end
    end

    def task_has_error(current_task, error_statuses = ERROR_STATUSES)
      error_statuses.map { |s| s.downcase }.find do
        |s| s == current_task.status.downcase
      end
    end
  end
end
