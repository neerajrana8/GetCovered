class YardiSyncJob < ApplicationJob
  queue_as :default # call it gordo

  def perform(account_or_integration = nil, resync: false)
    # get integration ids from whatever params were or were not provided
    ids = case account_or_integration
      when nil
        ::Integration.where(provider: 'yardi', enabled: true).order("updated_at asc").map{|i| i.id }
      when ::Account
        inty = account_or_integration.integrations.where(provider: 'yardi', enabled: true).take
        inty.nil? ? nil : [inty.id]
      when ::Integration
        [account_or_integration.id]
      else
        nil
    end
    # split things out to run parallel if there are multiple
    if ids.count > 1
      ids.each do |id|
        YardiSyncJob.perform_later(Integration.find(id))
      end
      return
    end
    # if there aren't multiple, run dat shizzle
    ids&.each do |integration_id|
      integration = Integration.where(id: integration_id).take
      next if integration.nil?
      begin
        Integrations::Yardi::Refresh.run!(integration: integration)
        integration.reload
      rescue
        # just don't wan' 'er to crash...
      end
      begin
        integration.configuration['sync']['syncable_communities'].select do |property_id, config|
          break unless integration.reload.enabled
          next unless config['enabled']
          next if !resync && !integration.configuration['sync']['queued_resync'] && config['last_sync_f'] == Time.current.to_date.to_s && config['last_sync_i'] == Time.current.to_date.to_s
          Integrations::Yardi::Sync::Insurables.run!(integration: integration, property_ids: [property_id], efficiency_mode: true) rescue  nil
        end
      rescue
        # just don't wan' 'er to crash...
      end
      if integration.configuration['sync']['push_policies']
        universal_export = (integration.configuration['sync']['queued_universal_export'] ? true : false)
        begin
          integration.configuration['sync']['syncable_communities'].select do |property_id, config|
            break unless integration.reload.enabled
            next unless config['enabled'] && !config['insurables_only']
            next if !resync && !integration.configuration['sync']['queued_resync'] && config['last_sync_p'] == Time.current.to_date.to_s
            Integrations::Yardi::Sync::Policies.run!(integration: integration, property_ids: [property_id], efficiency_mode: true, universal_export: universal_export) rescue  nil
          end
        rescue
          # just don't wan' 'er to crash...
        end
      end
      integration.configuration['sync']['next_sync']['timestamp'] = (Time.current.to_date + 1.day).to_s rescue nil
      integration.configuration['sync']['queued_universal_export'] = false
      integration.configuration['sync']['queued_resync'] = false
      integration.save
    end
  end
  
end
