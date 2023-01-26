
module Policies
  #noinspection ALL
  class PurchaseMailer < ApplicationMailer
    before_action :set_variables
    before_action :set_address

    default to: -> { ENV["RAILS_ENV"] == "production" ? "policysold@getcovered.io" : "testing@getcovered.io" },
            from: -> { "purchase-notifier-#{ENV["RAILS_ENV"]}@getcovered.io" }

    def get_covered
      @content = "
        <table style=\"width: 100%; cell-padding: 0px\">
          <tr>
              <td>User</td>
              <td>#{ @user.profile.full_name }</td>
          </tr>
          <tr>
              <td>Effective Date</td>
              <td>#{ @policy.effective_date.strftime('%m/%d/%Y') } to #{ @policy.expiration_date.strftime('%m/%d/%Y') }</td>
          </tr>
          <tr>
              <td>Community</td>
              <td>
                #{ @policy.primary_insurable.parent_community.title }<br>
                <small>#{ @address.nil? ? 'N/A' : @address }</small>
              </td>
          </tr>
          <tr>
              <td>Agency</td>
              <td>#{ @agency.title }</td>
          </tr>
          <tr>
              <td>Property Manager</td>
              <td>#{ @account.nil? ? 'N/A' : @account.title }</td>
          </tr>
          <tr>
              <td>Policy Type</td>
              <td>#{ @policy.policy_type.title }</td>
          </tr>
          <tr>
              <td>Billing Schedule</td>
              <td>#{ @billing_strat.title }</td>
          </tr>
          <tr>
              <td>Total Premium</td>
              <td>$#{ sprintf "%.2f", @premium.total.to_f / 100 }</td>
          </tr>
          <tr>
              <td>Deposit</td>
              <td>$#{ sprintf "%.2f", @deposit.total_due.to_f / 100 }</td>
          </tr>
        </table>
      "

      mail(subject: "A new #{ @policy.policy_type.title } Policy has Sold!", template_name: 'purchase')
    end

    def agency
      @content = 'A new policy has been sold.  See details below.<br><br>' + agency_content(symbol: "$", multiplier: 1)
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
      @agency = @policy.agency
      @account = @policy.account
      @user = @policy.primary_user
      @premium = @policy.policy_premiums.first
      @billing_strat = @premium.billing_strategy
      @deposit = @policy.invoices.order(due_date: :ASC).first
    end

    def set_address
      unless @policy.primary_insurable.nil?
        unless @policy.primary_insurable.primary_address.nil?
          @address = @policy.primary_insurable.primary_address.full
        end
      end
    end

    def agency_content(symbol: "$", multiplier: 1)
      details = "Name: #{ @user.profile.full_name }<br>"
      details += "Effective: #{ @policy.effective_date.strftime('%m/%d/%Y') } to #{ @policy.expiration_date.strftime('%m/%d/%Y') }<br>"
      details += "Address: #{ @address.nil? ? 'N/A' : @address }<br>"
      details += "Agency: #{ @agency.title }<br>"
      details += "Property Manager: #{ @account.nil? ? 'N/A' : @account.title }<br>"
      details += "Policy Type: #{ @policy.policy_type.title }<br>"
      details += "Billing Strategy: #{ @billing_strat.title }<br>"
      details += "Premium: #{ symbol }#{ sprintf "%.2f", (@premium.total.to_f * multiplier) / 100 }<br>"
      details += "First Payment: #{ symbol }#{ sprintf "%.2f", (@deposit.total_due.to_f * multiplier) / 100 }"

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

    def get_exchange_rates(to: 'USD')
      exchange = {
        multiplier: 1,
        error: true
      }
      response = HTTParty.get("https://api.apilayer.com/exchangerates_data/convert?to=#{ to }&from=USD&amount=1",
                              :headers => {'apikey': '8mJvTMHPaZZak3bFlzg9Rd25ujOL551w'})

      data = JSON.parse(response.body)
      exchange[:error] = data.has_key?("success") && data["success"] == true ? false : true
      exchange[:multiplier] = data.has_key?("success") && data["success"] == true ? data["result"] : 1
      return exchange
    end
  end
end
