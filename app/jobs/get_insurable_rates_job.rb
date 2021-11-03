class GetInsurableRatesJob < ApplicationJob
  queue_as :default

  def perform(community, number_insured = 1, traits_override: {})
    
    unless community.nil? ||
           community.insurable_type_id != 1
      
      community.get_qbe_rates(number_insured, traits_override: traits_override) 
      
      community.reload()
      
#       notification_details = {
#         :subject => "#{community.name} rate sync ",
#         :action => "community_rates_sync",
#         :message => nil,
#         :code => nil
#       }
#       
#       if community.ho4_enabled
#         
#         notification_details[:subject].concat("succeeded.")
#         notification_details[:message] = "QBE Rates for #{community.name} have finished loading at #{ Time.current.strftime("%m/%d/%Y %I:%M %p") }"
#         notification_details[:code] = "success"
#         
#       #else
#       #  
#       #  notification_details[:subject].concat("failed.")
#       #  notification_details[:message] = "QBE Rates for #{community.name} could not be loaded.  Last attempt at #{ Time.current.strftime("%m/%d/%Y %I:%M %p") }."
#       #  notification_details[:code] = "error"
#       
#         community.staff.each do |staff|
#           tmp_notification = community.notifications.new(notification_details.merge({ notifiable: staff }))
#           
#           if tmp_notification.save
#           
#             # Blank for now...
#           
#           else
#             puts "\nNotification Error\n".red
#             pp tmp_notification.errors
#           end
#         end
#             
#       end
      
    end
  end
end
