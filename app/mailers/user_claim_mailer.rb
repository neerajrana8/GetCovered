class UserClaimMailer < ApplicationMailer
  before_action { @user = params[:user] }
  before_action { @claim = params[:claim] }
  before_action :check_user_presence

  default to: -> { 'claims@getcoveredllc.com' },
          from: -> { @user.email }

  def claim_creation_email
    @claim = @user.claims.find(@claim.id)
    if Rails.env.include?('awsdev')
      mail(
        to: ['andreyden@nitka.com', 'roman.filimonchik@nitka.com', 'protchenkopa@gmail.com'],
        subject: "Claim was created policy number: #{@claim&.policy&.number}"
      )
    else
      mail(
        subject: "Claim was created policy number: #{@claim&.policy&.number}"
      )
    end
  end

  private

  def check_user_presence
    return false if @user.nil?
  end
end
