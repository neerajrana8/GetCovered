class Rack::Attack
  cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle('limit resend documents per ip', limit: 1, period: 60.seconds) do |request|
    if request.path.split('/').last == 'resend_policy_documents' && request.get?
      request.ip
    end

  end
end
Rack::Attack.throttled_response = lambda do |request|

  [ 429, {'Content-Type' => 'application/json; charset=utf-8'}, [{error: 'Retry later - Rate Limit exceeded'}.to_json]]
end

