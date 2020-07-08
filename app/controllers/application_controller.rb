class ApplicationController < ActionController::API
  include ActionController::Helpers
  include DeviseTokenAuth::Concerns::SetUserByToken

  def redirect_home
    redirect_to 'https://api-dev-v2.getcoveredinsurance.com/v2/'
  end

  # method for creating a standard error hash
  def standard_error(error, message = nil, payload = nil)
    {
      error: error, # required
      message: message, # optional
      payload: payload # optional
    }
  end
end
