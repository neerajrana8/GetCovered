class UserClaimMailer < ApplicationMailer
  before_action { @user = params[:user] }
  before_action :check_user_presence

  default to: -> { 'claims@getcoveredllc.com' },
          from: -> { @user.email }

  def claim_creation_email
    @claim = Claim.last
    if Rails.env.include?('development')
      mail(
        to: ['andreyden@nitka.com', 'roman.filimonchik@nitka.com', 'protchenkopa@gmail.com'],
        subject: 'CLAIM WAS CREATED'
      )
    else
      mail(
        :subject => "CLAIM WAS CREATED"
      )
    end
  end

  private

  def check_user_presence
    return false if @user.nil?
  end
end
