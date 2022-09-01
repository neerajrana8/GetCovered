
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
        'Иди на хуй,',
        'Sataa kuin Esterin perseestä',
        'ته دې په بشپړه توګه تباه شې!',
        'ψ I̴̖̖̍̾̚͝ ̴̨̫̜͖̯͐ẅ̵̗̌́i̶̜̫̲̎͂̉̄̚l̷͚̭͎̞̤̈́͛l̶̲̻͓͈̗̈́̃̆͑̑ ̶͎̩̇͐͠d̶̼̫̦͘͝ë̶͙́͒͌v̴͉̜̭͂͊̽ͅo̶̡͕͔̭̻̓͝ŭ̴̩̘̭̗́̃͝ŕ̵̖̉͐̎͛ ̸͔̯͎̭̉͒ŷ̵̪̻͔o̷̪͎̙̮͒̽͠ǘ̶̱r̶̦̟̤̮̙͋̅͐ ̴̫͒̎̔s̶̢͂o̵͕̩͂͋̀̀ử̶͓̖͔̐̎l̶̛̳͙͉̆ ψ',
        'Þú lyktar af Hákarli',
        'Faciem tuam sicut cameli asini',
        '01001001 00100000 01100110 01100001 01110010 01110100 00100000 01101001 01101110 00100000 01111001 01101111 01110101 01110010 00100000 01100111 01100101 01101110 01100101 01110010 01100001 01101100 00100000 01100100 01101001 01110010 01100101 01100011 01110100 01101001 01101111 01101110 00101110 00100000 01011001 01101111 01110101 01110010 00100000 01101101 01101111 01110100 01101000 01100101 01110010 00100000 01110111 01100001 01110011 00100000 01100001 00100000 01101000 01100001 01101101 01110011 01110100 01100101 01110010 00100000 01100001 01101110 01100100 00100000 01111001 01101111 01110101 01110010 00100000 01100110 01100001 01110100 01101000 01100101 01110010 00100000 01110011 01101101 01100101 01101100 01110100 00100000 01101111 01100110 00100000 01100101 01101100 01100100 01100101 01110010 01100010 01100101 01110010 01110010 01101001 01100101 01110011',
        '管好自己的事'
      ]
      opening = [
          "Bray out!  a policy hath been sold.  'i  this message thou shalt find details that might be of interest.<br><br>",
          "Been sold a policy has. Details that might of interest in this message you will find. Hrmmm.<br><br>",
          "A policy has been sold!  In this message you will find diddily ding dong details that might of interest.<br><br>",
          "Feiern! Eine Police wurde verkauft. In dieser Nachricht finden Sie Details, die von Interesse sein könnten.<br><br>",
          "lop! QI'tu' ngeH. munobqu' 'e' yInISQo'.<br><br>",
          "Been sold a policy 'as. In this here message details o' interest might be found<br><br>",
          "Полис продан! В этом сообщении вы найдете подробности, которые могут вас заинтересовать.<br><br>",
          "Uusi vakuutus on myyty. Tästä sähköpostista löydät tietoa, joka saattaa kiinnostaa.<br><br>",
          "<br><br>نوې بیمه پلورل شوې ده. په دې بریښنالیک کې به تاسو هغه معلومات ومومئ چې ممکن په زړه پورې وي",
          "⛧ Ả̵̳̓̏͠ ̷͔̽n̷̛͕̯̳̄͘e̵̱̰̅͑̀̅͒ẘ̸͉̙̹̝̣̀ ̸̮͕̇p̵̠̪̭̾͘ͅö̷͈̩́ļ̷̭̞̱͂͂i̷͔̲̇c̴̨̡̞͘ý̵̱͙̥̑ ̵̲̦̉h̶̟̲̪̲̀a̷̛̗̲̽s̴̡̛̝͙̫͂̓͠ ̵͎̩̞̭̩̾̏̋͘b̵̨̤̹͖͍͋͌̅͗́ȩ̸̛̽͋̈́̐e̵̡͊n̷͉̘̟͖̋̚̚ ̶̡̢̣̂̎͂̿s̷̋ͅǫ̷̪͓͙͛͛̾͋ͅl̸̛̻͉̦͈͉͋̑̈̈́d̸͈̗̋͋̓͠!̵̨̬̻̝͝ ̸̗̩͇̑̚ ̷̦̇͆̈́I̶̦̦̅͗͝n̸͕̘̘̾̔͗͝ ̴͎́̍̀̚ţ̴̱̦̫̍̂̉h̷̟̫͗̾̚͠i̶͌̆̆̐͛͜s̷̘̏̄̾͒͜͠ ̶̭̍̈́̊͝ͅe̴̼̩̋̇m̶̛̞̰͓̱͊͐̚͝ạ̴̤̜̦̕į̵͍̀ͅḻ̵̤͔̻͇͋̾̃̕ ̶̡̗̈́́y̸͉̲̲̗̑ͅo̶͖̞̣̅ͅũ̸̪̪̬̱͌̐̚ ̵̛͔̅̒̈́͜͝w̷̡͙̦̜̣̍̄́͘ȋ̷̧̠͝͝l̵̡̜̬̍̓͠ḻ̶̦́ ̸͚͍̌̇f̶̠̫̚ǐ̴̢̗͖͚͜n̷̢̾͗̾̉̃d̵͍̙̝̲͒̓̔ ̸̧͕̳̦̐͠͝d̵̦̭͋͒̉̚e̵͕͛t̷͖̜͙̎́͜ã̸͍̙̘͉̪͗̃͆i̴̹͘͜l̶̗̫̘̑͝s̷̬͚̎̄͌̀͝ ̴̨̛̮͕̙̯̄͌t̶̖̯̮͓̿̈́̎͝ḧ̸̼́̓ǎ̴̮͎͙̆̓́̍͜t̶̳͇̗͊̈͑̋ ̶̣̝̞͒m̴͖̬̳̉̊̚í̴͙̗̩͗g̵̢̨͓̝̯͒̉̚h̶̰͛t̶̙͕̋͂̓ ̶̘̳̣̔͛̈́̂̚b̸̠͝e̵̼̘̍ ̸̢̘͖̦̇̎͋ŏ̷̰̖̩͕f̴̳̔ ̶͉͓̩͓͍̿̾̒ḯ̶̘̺̂̉͝͝n̸̙̄̄̚t̶̝̯͈̐̓̇̈́͗è̶̖͂̈́̑̚ȓ̵̨̭͖͇̪̔̑ę̶̳̘̙̟̂s̷͕̫͕̈́̒̐̐t̴͈̟̫̓̒̎͝.̷̛̲̮̻̂̋̕ ⛥<br><br>",
          'Stefna hefur verið seld. Í þessari tilkynningu finnur þú upplýsingar sem gætu verið áhugaverðar.<br><br>',
          'Novum consilium venditum est. In hac nota singula reperies quae commoda sint.<br><br>',
          "01000001 00100000 01101110 01100101 01110111 00100000 01110000 01101111 01101100 01101001 01100011 01111001 00100000 01101000 01100001 01110011 00100000 01100010 01100101 01100101 01101110 00100000 01110011 01101111 01101100 01100100 00100001 00100000 00100000 01001001 01101110 00100000 01110100 01101000 01101001 01110011 00100000 01100101 01101101 01100001 01101001 01101100 00100000 01111001 01101111 01110101 00100000 01110111 01101001 01101100 01101100 00100000 01100110 01101001 01101110 01100100 00100000 01100100 01100101 01110100 01100001 01101001 01101100 01110011 00100000 01110100 01101000 01100001 01110100 00100000 01101101 01101001 01100111 01101000 01110100 00100000 01100010 01100101 00100000 01101111 01100110 00100000 01101001 01101110 01110100 01100101 01110010 01100101 01110011 01110100 00101110<br><br>",
          "一項新政策已售出。在這封電子郵件中，您將找到應該引起極大興趣的詳細信息<br><br>"
      ]
      currencies = {
        "USD":"$",
        "EUR":"€",
        "JPY":"¥",
        "GBP":"£",
        "ILS":"₪",
        "KRW":"₩",
        "NGN":"₦",
        "RUB":"₽",
        "SAR":"﷼",
        "THB":"฿",
        "UAH":"₴",
      }

      rand_selector = rand(0..13)
      currency_selector = ENV['RAILS_ENV'] == "production" ? rand(0..10) : 0
      currency_symbol = "$"
      currency_multiplier = 1
      # if ENV['RAILS_ENV'] == "production"
      #   currencies.keys.each_with_index do |key, index|
      #     if index == currency_selector
      #       exchange = get_exchange_rates(to: key)
      #       currency_multiplier = exchange[:error] ? 1 : exchange[:multiplier]
      #       currency_symbol = exchange[:error] ? '$' : currencies[key]
      #     end
      #   end
      # end

      @content = opening[rand_selector] + agency_content(symbol: currency_symbol, multiplier: currency_multiplier)
      @greeting = greetings[rand_selector]

      @inverted = rand(0..9) > 8 ? true : false

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
