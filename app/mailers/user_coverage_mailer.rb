class UserCoverageMailer < ApplicationMailer
  before_action { @user = params[:user] }
  before_action { @policy = params[:policy] }
  before_action :check_user_preference
 
  default to:       -> { @user.email },
          from:     -> { 'no-reply@getcoveredinsurance.com' }
          
  def coverage_required
    mail(
      :subject => "Get Renters Insurance" 
    )
  end
  
  def coverage_required_follow_up
    mail(
      :subject => "FOR THE LOVE OF GOD GET RENTERS INSURANCE" 
    ) 
  end
  
  def proof_of_coverage
    mail(
      :subject => "Your new Insurance Policy" 
    )
  end
  
  def policy_expiring
    mail(
      :subject => "Your policy is expiring" 
    )
  end
  
  def payment_expiring
    mail(
      :subject => "Your payment method for Policy ##{@policy.number} is expiring" 
    )  
  end
  
  def auto_pay_fail
    mail(
      :subject => "Autopayment for Policy #{@policy.number} failed."
    )  
  end
  
  def late_payment
    mail(
      :subject => "Payment for Policy ##{@policy.number} is past due."
    )  
  end
  
  def late_payment_cancellation
    mail(
      :subject => "Policy ##{@policy.number} cancelled for lack of payment."
    ) 
  end
  
  private
  
    def check_user_preference
      return false if @user.nil?
    end
end
