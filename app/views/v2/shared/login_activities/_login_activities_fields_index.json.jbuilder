json.extract! login, :ip, :user_agent, :city, :region, :country, :latitude, :longitude
if request.headers.env['HTTP_CLIENT'].present? && login.client.present? && request.headers.env['HTTP_CLIENT'] == login.client
  json.current request.headers.env['HTTP_CLIENT'] == login.client
end

json.last_activity login.user&.tokens&.values&.map { |client| client['updated_at'].to_datetime }&.max

if login.user_agent.present?
  browser = Browser.new(login.user_agent)

  json.device_id browser.device.id
  json.device_name browser.device.name
  json.browser_name browser.name
  json.browser_version browser.version
  json.platform_name browser.platform.name
  json.platform_version browser.platform.version
end

json.expiry Time.at(login.expiry)
