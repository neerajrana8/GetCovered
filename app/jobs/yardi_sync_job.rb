class YardiSyncJob < ApplicationJob
  queue_as :default

  def perform(*args)
    ::Integration.where(provider: 'yardi', enabled: true).order("updated_at asc").map{|i| i.id }.each do |integration_id|
      integration = Integration.where(id: integration_id).take
      next if integration.nil?
      begin
        integration.configuration['sync']['syncable_communities'].select do |property_id, config|
          next unless config['enabled']
          Integrations::Yardi::Sync::Insurables.run!(integration: integration, property_ids: [property_id], efficiency_mode: true) rescue  nil
        end
      rescue
        # just don't wan' 'er to crash...
      end
      if integration.configuration['sync']['push_policies']
        begin
          integration.configuration['sync']['syncable_communities'].select do |property_id, config|
            next unless config['enabled']
            Integrations::Yardi::Sync::Policies.run!(integration: integration, property_ids: [property_id], efficiency_mode: true) rescue  nil
          end
        rescue
          # just don't wan' 'er to crash...
        end
      end
      integration.configuration['sync']['next_sync']['timestamp'] = (Time.current.to_date + 1.day).to_s rescue nil
      integration.save
    end
  end
  
end
