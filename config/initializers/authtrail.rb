AuthTrail.geocode = true

AuthTrail.job_queue = :authtrail

AuthTrail.transform_method = lambda do |data, request|
  data[:client] = if request.headers.env["HTTP_CLIENT"].blank? || request.headers['client'].blank?
                    data[:user].tokens&.keys&.last
                  else
                    request.headers.env["HTTP_CLIENT"] || request.headers['client']
                  end
  data[:expiry] = if request.headers['client'].blank?
                    data[:user].tokens[data[:user].tokens&.keys&.last].fetch("expiry", nil)#request.headers[:expiry]
                  else
                    request.headers['client']
                  end
end
