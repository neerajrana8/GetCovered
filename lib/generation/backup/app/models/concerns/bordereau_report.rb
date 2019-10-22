# Bordereau Report Concern
# file: app/models/concerns/bordereau_report.rb

module BordereauReport
  extend ActiveSupport::Concern

  def generate_bordereau_report(current_date = Time.current.to_date)
    conn = ActiveRecord::Base
    # set up hash defining fields to select & their aliases
    to_select = {
      master_policies: {
        master_policy_number: :master_policy_number
      },
      master_policy_coverages: {
        certificate_number: :certificate_number,
        effective_date: :master_policy_effective_date,
        expiration_date: :master_policy_cancellation_date,
        landlord_supplemental: :landlord_supplemental,
        contingent_liability_limit: :contingent_liability_limit,
        tenant_contingent_contents_limit: :tenant_contingent_contents_limit
      },
      agencies: {
        call_sign: :agency_call_sign,
        contact_phone: :agency_contact_phone,
        contact_phone_ext: :agency_contact_phone_ext,
        contact_email: :agency_contact_email
      },
      accounts: {
        call_sign: :account_call_sign,
        title: :account_title,
        contact_phone: :account_contact_phone,
        contact_phone_ext: :account_contact_phone_ext,
        contact_email: :account_contact_email
      },
      communities: {
        id: :community_id,
        slug: :community_slug,
        name: :community_name
      },
      buildings: {
        id: :building_id,
        slug: :building_slug,
        name: :building_name
      },
      addresses: {
        street_number: :building_street_number,
        street_one: :building_street_one,
        street_two: :building_street_two,
        locality: :building_city,
        region: :building_state,
        postal_code: :building_zip
      },
      units: {
        id: :unit_id,
        mailing_id: :unit_mailing_id
      },
      users: {
        id: :user_id,
        email: :user_email
      },
      profiles: {
        first_name: :user_first_name,
        middle_name: :user_middle_name,
        last_name: :user_last_name,
        contact_email: :user_contact_email
      }
    }
    # set up order by settings
    order_by = [
      {
        column: "master_policies.master_policy_number",
        direction: "ASC"
      },
      {
        column: "master_policy_coverages.certificate_number",
        direction: "ASC"
      }
    ]
    # get necessary values to use in query
    master_policy_coverage_active_status = MasterPolicyCoverage.coverage_types['active']
    lease_current_status = Lease.statuses['current']
    first_of_this_month = current_date.at_beginning_of_month.strftime("%Y-%m-%d")
    last_of_this_month = current_date.at_end_of_month.strftime("%Y-%m-%d")
    # perform query
    sql = "SELECT #{to_select.map{|table, columns| columns.map{|column, calias| "#{table}.#{column} AS #{calias}"}.join(", ") }.join(", ") }" +
          " FROM master_policies" +
            " INNER JOIN agencies ON agencies.id = master_policies.agency_id" +
            " INNER JOIN master_policy_coverages ON master_policy_coverages.master_policy_id = master_policies.id AND master_policy_coverages.effective_date <= '#{last_of_this_month}' AND (master_policy_coverages.expiration_date IS NULL OR master_policy_coverages.expiration_date >= '#{first_of_this_month}') AND master_policy_coverages.coverable_type = 'Unit' AND master_policy_coverages.coverage_type = #{master_policy_coverage_active_status}" +
            " INNER JOIN units ON units.id = master_policy_coverages.coverable_id AND units.occupied = TRUE" +
            " INNER JOIN buildings ON buildings.id = units.building_id" +
            " INNER JOIN communities ON communities.id = buildings.community_id" +
            " INNER JOIN accounts ON accounts.id = communities.account_id" +
            " INNER JOIN addresses ON addresses.addressable_id = buildings.id AND addresses.addressable_type = 'Building'" +
            " INNER JOIN leases ON leases.unit_id = units.id AND leases.status = #{lease_current_status}" +
            " INNER JOIN lease_users ON lease_users.lease_id = leases.id" +
            " INNER JOIN users ON users.id = lease_users.user_id" +
            # " INNER JOIN master_policy_coverage_users ON master_policy_coverage_users.master_policy_coverage_id = master_policy_coverages.id" +
            # " INNER JOIN users ON users.id = master_policy_coverage_users.user_id" +
            " INNER JOIN profiles ON profiles.profileable_id = users.id AND profiles.profileable_type = 'User'" +
          " WHERE master_policies.id = #{ self.id }" +
          " ORDER BY #{order_by.map{|ob| "#{ob[:column]} #{ob[:direction]}" }.join(", ")}" +
          "" # end sql
    result = conn.connection.execute(sql)
    # format query results for report
    report_rows = []
    result.each do |row|
      report_rows.push({
        MasterPolicyNumber:     row["master_policy_number"],
        CertificateNumber:      row["certificate_number"],
        AgentID:                row["agency_call_sign"],
        AgentEmail:             row["agency_contact_email"],
        PropMgrID:              row["account_call_sign"],
        PropMgrName:            row["account_title"],
        PropMgrEmail:           row["account_contact_email"],
        CommunityName:          row["community_name"],
        CommunityID:            row["community_id"],
        UnitID:                 "B#{row["building_id"]}U#{row["unit_id"]}",
        TenantID:               row["user_id"],
        TenantName:             "#{row["user_first_name"]} #{row["user_last_name"]}",
        TenantAddress:          "#{row["building_street_number"].blank? ? "" : row["building_street_number"] + " "}#{row["building_street_one"]}#{row["building_street_two"].blank? ? "" : ", #{row["building_street_two"]}"}", #MOOSE WARNING: decide how to handle building_street_two
        TenantUnit:             row["unit_mailing_id"],
        TenantCity:             row["building_city"],
        TenantState:            normalize_state(row["building_state"]),
        TenantZipCode:          row["building_zip"],
        TenantEmail:            row["user_email"], #MOOSE WARNING: resolve whether to use contact_email if exists
        Risk_State:             normalize_state(row["building_state"]), #MOOSE WARNING: always same as TenantState... misunderstanding?
        Transaction:            Date.parse(row["master_policy_effective_date"]) >= current_date.at_beginning_of_month ?
                                  "New" : row["master_policy_expiration_date"].nil? ? "Renew" : "Cancel",
        Eff_Date:               Date.parse(row["master_policy_effective_date"]) >= current_date.at_beginning_of_month ?
                                  row["master_policy_effective_date"] : first_of_this_month,
        Exp_Date:               current_date.at_end_of_month.strftime("%Y-%m-%d"),
        Canc_Date:              row["master_policy_expiration_date"].nil? ? "" : row["master_policy_expiration_date"],
        Tenant_Liability_Limit: normalize_money(row["landlord_supplemental"] ? "#{row["contingent_liability_limit"]}" : ""),
        Tenant_CovC_Limit:      normalize_money(row["landlord_supplemental"] ? "#{row["tenant_contingent_contents_limit"]}" : "")
        #MOOSE WARNING: is CovC a typo for ConC?
      })
    end
    # construct and return Report model object
    return(self.reports.new(format: 'bordereau', data: { rows: report_rows }))
  end

private
    def normalize_money(money_string)
      return(money_string.sub("$", ""))
    end

    def normalize_state(state_name)      
      states = {
        "Alabama" => "AL",
        "Alaska" => "AK",
        "Arizona" => "AZ",
        "Arkansas" => "AR",
        "California" => "CA",
        "Colorado" => "CO",
        "Connecticut" => "CT",
        "Delaware" => "DE",
        "Florida" => "FL",
        "Georgia" => "GA",
        "Hawaii" => "HI",
        "Idaho" => "ID",
        "Illinois" => "IL",
        "Indiana" => "IN",
        "Iowa" => "IA",
        "Kansas" => "KS",
        "Kentucky" => "KY",
        "Louisiana" => "LA",
        "Maine" => "ME",
        "Maryland" => "MD",
        "Massachusetts" => "MA",
        "Michigan" => "MI",
        "Minnesota" => "MN",
        "Mississippi" => "MS",
        "Missouri" => "MO",
        "Montana" => "MT",
        "Nebraska" => "NE",
        "Nevada" => "NV",
        "New Hampshire" => "NH",
        "New Jersey" => "NJ",
        "New Mexico" => "NM",
        "New York" => "NY",
        "North Carolina" => "NC",
        "North Dakota" => "ND",
        "Ohio" => "OH",
        "Oklahoma" => "OK",
        "Oregon" => "OR",
        "Pennsylvania" => "PA",
        "Rhode Island" => "RI",
        "South Carolina" => "SC",
        "South Dakota" => "SD",
        "Tennessee" => "TN",
        "Texas" => "TX",
        "Utah" => "UT",
        "Vermont" => "VT",
        "Virginia" => "VA",
        "Washington" => "WA",
        "West Virginia" => "WV",
        "Wisconsin" => "WI",
        "Wyoming" => "WY"
      }
      return states[state_name.titlecase] if states.has_key?(state_name.titlecase)
      return state_name
    end

end
