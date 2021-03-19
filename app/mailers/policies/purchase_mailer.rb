
module Policies
  class PurchaseMailer < ApplicationMailer
    before_action :set_variables

    default to: -> { "policysold@getcoveredllc.com" },
            from: -> { "purchase-notifier-#{ENV["RAILS_ENV"]}@getcoveredinsurance.com" }

    def get_covered
      opening = [
          "Bray out!  a policy hath been sold.  'i  this message thou shall find details that might be of interest.<br><br>",
          "Been sold a policy has. Details that might of interest in this message you will find. Hrmmm.<br><br>",
          "A policy has been sold!  In this message you will find diddily ding dong details that might of interest.<br><br>",
          "Feiern! Eine Police wurde verkauft. In dieser Nachricht finden Sie Details, die von Interesse sein könnten.<br><br>",
          "lop! QI'tu' ngeH. munobqu' 'e' yInISQo'.<br><br>"
      ]

      details = "Name: #{ @user.profile.full_name }<br>Agency: #{ @agency.title }<br>Policy Type: #{ @policy.policy_type.title }<br>Billing Strategy: #{ @billing_strat.title }<br>Premium: $#{ sprintf "%.2f", @premium.total.to_f / 100 }<br>First Payment: $#{ sprintf "%.2f", @deposit.total.to_f / 100 }"

      @content = opening[rand(0..4)] + details

      mail(subject: "A new #{ @policy.policy_type.title } Policy has Sold!", template_name: 'purchase')
    end

    def agency
      @content = "A new policy has been sold.  See details below.<br><br>Name: #{ @user.profile.full_name }<br>Agency: #{ @agency.title }<br>Policy Type: #{ @policy.policy_type.title }<br>Billing Strategy: #{ @billing_strat.title }<br>Premium: $#{ sprintf "%.2f", @premium.total.to_f / 100 }<br>First Payment: $#{ sprintf "%.2f", @deposit.total.to_f / 100 }"

      mail(subject: "A new #{ @policy.policy_type.title } Policy has Sold!", template_name: 'purchase')
    end

    def account
      @content = "A new policy has been sold.  See details below.<br><br>Name: #{ @user.profile.full_name }<br>Agency: #{ @agency.title }<br>Policy Type: #{ @policy.policy_type.title }<br>Billing Strategy: #{ @billing_strat.title }"

      mail(subject: "A new #{ @policy.policy_type.title } Policy has Sold!", template_name: 'purchase')
    end

    private
    def set_variables
      @policy = params[:policy]
      @agency = @policy.agency
      @user = @policy.primary_user
      @premium = @policy.policy_premiums.first
      @billing_strat = @premium.billing_strategy
      @deposit = @policy.invoices.order(due_date: :ASC).first
    end
  end
end
