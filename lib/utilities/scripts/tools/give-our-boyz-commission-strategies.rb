
def give_em_cses
  sheet = Roo::Spreadsheet.open(Rails.root.join('lib/utilities/scripts/tools/gobcs/commissions.xlsx').to_s)
  begin
    ActiveRecord::Base.transaction do
      # clear out shittastic data
      ::CarrierPolicyType.where(carrier_id: nil).or(::CarrierPolicyType.where(policy_type_id: nil)).delete_all
      CarrierAgencyPolicyType.all.select{|capt| capt.carrier_policy_type.nil? }.each{|capt| capt.delete }
      ::CarrierAgency.where("carrier_id > 6").each{|ca| ca.destroy! }
      ::Carrier.where("id > 6").each{|c| c.carrier_policy_types.each{|cpt| cpt.destroy! }; c.fees.delete_all; c.carrier_insurable_types.delete_all; c.carrier_insurable_profiles.delete_all; c.carrier_class_codes.delete_all; c.histories.delete_all; c.access_tokens.delete_all; c.destroy! }
      ::PolicyPremium.where(policy_id: nil, policy_quote_id: nil).delete_all

      # create capts for weird garbage
      folk = (
        ::PolicyApplication.order('carrier_id asc, agency_id asc, policy_type_id asc').group('carrier_id, agency_id, policy_type_id').pluck('carrier_id, agency_id, policy_type_id').to_a +
        ::Policy.order('carrier_id asc, agency_id asc, policy_type_id asc').group('carrier_id, agency_id, policy_type_id').pluck('carrier_id, agency_id, policy_type_id').to_a
      ).uniq
      folk.each do |f|
        next if f.compact.count < 3
        cpt = ::CarrierPolicyType.where(carrier_id: f[0], policy_type_id: f[2]).take
        if cpt.nil?
          cpt = ::CarrierPolicyType.create!(carrier_id: f[0], policy_type_id: f[2])
        end
        51.times do |state|
          available = state == 0 || state == 11 ? false : true
          carrier_policy_availability = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: cpt) unless ::CarrierPolicyTypeAvailability.where(state: state, carrier_policy_type: cpt).take
        end
        ca = ::CarrierAgency.where(carrier_id: f[0], agency_id: f[1]).take
        if ca.nil?
          ca = ::CarrierAgency.create!(carrier_id: f[0], agency_id: f[1])
        end
        if ::CarrierAgencyPolicyType.where(carrier_agency: ca, policy_type_id: f[2]).take.nil?
          ::CarrierAgencyPolicyType.create!(carrier_agency: ca, policy_type_id: f[2])
        end
      end
      
      # give our CPTs commission strategies
      get_covered = ::Agency.where(master_agency: true).take
      ::CarrierPolicyType.all.each do |cpt|
        if cpt.commission_strategy.nil? || cpt.commission_strategy.recipient != get_covered
          cpt.update!(commission_strategy_attributes: { recipient: get_covered, percentage: {
            PolicyType::RESIDENTIAL_ID => 30,
            PolicyType::MASTER_ID => 25,
            PolicyType::MASTER_COVERAGE_ID => 25,
            PolicyType::SECURITY_DEPOSIT_ID => 10,
            PolicyType::RENT_GUARANTEE_ID => 18.5,
            PolicyType::COMMERCIAL_ID => 0
          }[cpt.policy_type_id] || "unknown policy type ##{cpt.policy_type_id}" }) # will trigger error on unknown
        end
      end
      
      # order our capts by agency ownership
      allcapts = ::CarrierAgencyPolicyType.all.to_a
      capts = [allcapts.select{|capt| capt.agency.agency.nil? }]
      allcapts -= capts.last
      # fix orphans
      orphaned = allcapts.select{|ac| ac.parent_carrier_agency_policy_type.nil? }
      while !orphaned.blank?
        if orphaned.first.parent_carrier_agency_policy_type.nil?
          newparent = ::CarrierAgencyPolicyType.create!(policy_type_id: orphaned.first.policy_type_id, carrier_agency: ::CarrierAgency.where(carrier_id: orphaned.first.carrier_agency.carrier_id, agency_id: orphaned.first.carrier_agency.agency.agency_id).take || ::CarrierAgency.create!(carrier_id: orphaned.first.carrier_agency.carrier_id, agency_id: orphaned.first.carrier_agency.agency.agency_id))
          if newparent.carrier_agency.agency.agency_id == nil
            capts.first.push(newparent)
            if newparent.carrier_policy_type.nil?
              cpt = ::CarrierPolicyType.create!(carrier_id: newparent.carrier_agency.carrier_id, policy_type_id: newparent.policy_type_id, commission_strategy_attributes: { percentage: 30 })
              51.times do |state|
                available = state == 0 || state == 11 ? false : true
                carrier_policy_availability = CarrierPolicyTypeAvailability.create(state: state, available: available, carrier_policy_type: cpt)
              end
            end
          else
            allcapts.push(newparent)
            orphaned.push(newparent) if newparent.parent_carrier_agency_policy_type.nil?
          end
        end
        orphaned = orphaned.drop(1)
      end
      # order by ownership
      while !allcapts.blank? && !capts.last.blank?
        capts.push(allcapts.select{|capt| capts.last.any?{|c| c.agency == capt.agency.agency } })
        allcapts -= capts.last
      end
      capts.pop if capts.last.blank?
      if !allcapts.blank?
        puts "We have a problem! CAPTS exist without a valid superagency: #{allcapts.map{|c| c.id }.join(", ")}"
        raise Exception
      end
      if capts.count > 4
        puts "Agency hierarchy too deep! Oh man! Way too deep! Depth #{capts.count}!"
        raise Exception
      end

      # give capts commission strategies
      capts.each.with_index do |capty_boiz, depth|
        capty_boiz.each do |capt|
          begin
            capt.update!(commission_strategy_attributes: { percentage: capt.agency == get_covered ? 30 : 30 - (depth+1)*5 })
          rescue
            puts "!!!!!!!"
            puts capt.id
            raise
          end
        end
      end
    end
  rescue ActiveRecord::RecordInvalid => e
    puts "HELL HATH COME"
    puts "Record: #{e.record.class.name} ##{e.record.id}"
    puts "Errors: #{e.record.errors.to_h}"
    puts "JSON: #{e.record.to_json}"
    puts "Backtrace: #{e.backtrace.join("\n")}"
  end
end
