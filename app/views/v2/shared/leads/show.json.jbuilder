json.partial! 'v2/shared/leads/lead_fields_show.json.jbuilder',
              lead: @lead, visits: @visits

json.last_premium_estimation @last_premium_estimation.present? ? @last_premium_estimation.data['total_amount'] : 0
