module StandardErrorMethods
  # method for creating a standard error hash
  def standard_error(error, message = nil, payload = nil)
    {
      error: error, # required
      message: message, # optional
      payload: payload # optional
    }
  end
end
