class ApplicationController < ActionController::API
  include ActionController::Helpers
  include DeviseTokenAuth::Concerns::SetUserByToken
  include ::StandardErrorMethods

  def redirect_home
    redirect_to 'https://api-dev-v2.getcoveredinsurance.com/v2/'
  end
end
