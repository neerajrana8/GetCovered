class ApplicationController < ActionController::API
        include DeviseTokenAuth::Concerns::SetUserByToken
        def redirect_home
                redirect_to 'https://api-dev-v2.getcoveredinsurance.com/v2/'
        end
end
