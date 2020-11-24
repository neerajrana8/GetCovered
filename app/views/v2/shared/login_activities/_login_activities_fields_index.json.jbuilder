json.extract! login, :user_agent, :city, :region, :country, :latitude, :longitude

json.expiry Time.at(login.expiry)
