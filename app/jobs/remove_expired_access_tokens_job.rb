class RemoveExpiredAccessTokensJob < ApplicationJob
  queue_as :default
  before_perform :set_access_tokens

  def perform(*_args)
    @tokens.delete_all
  end

  private
  
    def set_access_tokens
      @tokens = ::AccessToken.where("expires_at < ?", Time.current)
    end
end
