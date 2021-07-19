
module Policies
  #noinspection ALL
  class PurchaseMailer < ApplicationMailer
    before_action :set_variables
    before_action :set_address

    default to: -> { ENV["RAILS_ENV"] == "production" ? "policysold@getcovered.io" : "testing@getcovered.io" },
            from: -> { "purchase-notifier-#{ENV["RAILS_ENV"]}@getcovered.io" }

    def get_covered
      greetings = [
        'Thou cream faced loon,',
        'Bantha fodder you are,',
        'Hi-Diddily-Ho!',
        'Hallo Verlierer,',
        'QeyHa \'moHwI\',',
        'Arr, matey,',
        'Иди на хуй,'
      ]
      opening = [
          "Bray out!  a policy hath been sold.  'i  this message thou shalt find details that might be of interest.<br><br>",
          "Been sold a policy has. Details that might of interest in this message you will find. Hrmmm.<br><br>",
          "A policy has been sold!  In this message you will find diddily ding dong details that might of interest.<br><br>",
          "Feiern! Eine Police wurde verkauft. In dieser Nachricht finden Sie Details, die von Interesse sein könnten.<br><br>",
          "lop! QI'tu' ngeH. munobqu' 'e' yInISQo'.<br><br>",
          "Been sold a policy 'as. In this here message details o' interest might be found",
          "Полис продан! В этом сообщении вы найдете подробности, которые могут вас заинтересовать."
      ]

      rand_selector = rand(0..6)

      @content = opening[rand_selector] + agency_content()
      @greeting = greetings[rand_selector]

      @inverted = rand(0..9) > 8 ? true : false

      mail(subject: "A new #{ @policy.policy_type.title } Policy has Sold!", template_name: 'purchase')
    end

    def agency
      @content = 'A new policy has been sold.  See details below.<br><br>' + agency_content()
      mail(to: @staff.email, subject: "A new #{ @policy.policy_type.title } Policy has Sold!", template_name: 'purchase')
    end

    def account
      @content = "A new policy has been sold.  See details below.<br><br>" + account_content()
      mail(to: @staff.email, subject: "A new #{ @policy.policy_type.title } Policy has Sold!", template_name: 'purchase')
    end

    private
    def set_variables
      @policy = params[:policy]
      @staff = params[:staff]
      @staff = params[:staff]
      @agency = @policy.agency
      @account = @policy.account
      @user = @policy.primary_user
      @premium = @policy.policy_premiums.first
      @billing_strat = @premium.billing_strategy
      @deposit = @policy.invoices.order(due_date: :ASC).first
      @greeting = nil
      @inverted = false
      @address = nil
    end

    def set_address
      unless @policy.primary_insurable.nil?
        unless @policy.primary_insurable.primary_address.nil?
          @address = @policy.primary_insurable.primary_address.full
        end
      end
    end

    def agency_content
      details = "Name: #{ @user.profile.full_name }<br>"
      details += "Effective: #{ @policy.effective_date.strftime('%m/%d/%Y') } to #{ @policy.expiration_date.strftime('%m/%d/%Y') }<br>"
      details += "Address: #{ @address.nil? ? 'N/A' : @address }<br>"
      details += "Agency: #{ @agency.title }<br>"
      details += "Property Manager: #{ @account.nil? ? 'N/A' : @account.title }<br>"
      details += "Policy Type: #{ @policy.policy_type.title }<br>"
      details += "Billing Strategy: #{ @billing_strat.title }<br>"
      details += "Premium: $#{ sprintf "%.2f", @premium.total.to_f / 100 }<br>"
      details += "First Payment: $#{ sprintf "%.2f", @deposit.total.to_f / 100 }"

      return details
    end

    def account_content
      details = "Name: #{ @user.profile.full_name }<br>"
      details += "Effective: #{ @policy.effective_date.strftime('%m/%d/%Y') } to #{ @policy.expiration_date.strftime('%m/%d/%Y') }<br>"
      details += "Address: #{ @address.nil? ? 'N/A' : @address }<br>"
      details += "Agency: #{ @agency.title }<br>"
      details += "Policy Type: #{ @policy.policy_type.title }<br>"

      return details
    end
  end
end
