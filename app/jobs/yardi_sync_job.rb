class YardiSyncJob < ApplicationJob
  queue_as :default
  before_perform :set_integrations

  def perform(*args)
    @integration_ids.each do |integration_id|
      integration = Integration.where(id: integration_id).take
      next if integration.nil?
      begin
        Integrations::Yardi::Sync::Insurables.run!(integration: integration)
      rescue
        begin
          integration.configuration['sync_history'].push({
            "message"=>"Failed to sync properties & leases; encountered a system error.",
            "timestamp"=>Time.current.to_date.to_s,
            "event_type"=>"sync_insurables",
            "log_format"=>"1.0"
          })
          integration.save
        rescue
          # uh oh
        end
      end
      begin
        Integrations::Yardi::Sync::Policies.run!(integration: integration)
      rescue
        begin
          integration.configuration['sync_history'].push({
            "message"=>"Failed to sync policies; encountered a system error.",
            "timestamp"=>Time.current.to_date.to_s,
            "event_type"=>"sync_policies",
            "log_format"=>"1.0"
          })
          integration.save
        rescue
          # uh oh
        end
      end
      integration.configuration['sync']['next_sync']['timestamp'] = (Time.current.to_date + 1.day).to_s rescue nil
      integration.save
    end
  end

  private

    def set_invoices
      @integration_ids = ::Integration.enabled.where(provider: 'yardi').select{|i| (Date.parse(i.configuration['sync']['next_sync']['timestamp']) rescue nil) <= Time.current.to_date }.map{|i| i.id }
    end
end
