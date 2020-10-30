class Rack::Attack
  cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle('limit resend documents per ip', limit: 1, period: 60.seconds) do |request|
    if request.path.split('/').last == 'resend_policy_documents' && request.get?
      request.ip
    end

  end
end

