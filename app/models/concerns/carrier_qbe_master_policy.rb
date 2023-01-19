# =QBE Master Policy Functions Concern
# file: +app/models/concerns/carrier_qbe_master_policy.rb+

module CarrierQbeMasterPolicy
  extend ActiveSupport::Concern

  included do

    def qbe_master_build_coverage_options
      [
        { title: "Liability Coverage", designation: "liability_coverage", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Expanded Liability Coverage", designation: "expanded_liability", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Pet Damage", designation: "pet_damage", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Loss of Rent", designation: "loss_of_rents", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Tenant Contingent Contents", designation: "tenant_contingent_contents", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Landlord Supplemental", designation: "landlord_supplemental", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Bed Bug Remediation", designation: "bed_bug_remediation", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Mold Remediation", designation: "mold_remediation", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Bodily Injury", designation: "bodily_injury", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Additional Living Expense", designation: "additional_living_expense", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Automatic Coverage", designation: "automatic_coverage", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Intentional Damage", designation: "intentional_damage", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false },
        { title: "Break in Damage", designation: "break_in_damage", limit: 0, occurrence_limit: 0, deductible: 0, enabled: false }
      ].each do |coverage|
        self.policy_coverages.new(coverage)
      end
    end

    def qbe_master_get_coverage_option_limit(designation:, limit:)
      raise ArgumentError.new(
        "#{ limit } is not available field coverage limit"
      ) unless %w[limit occurrence_limit aggregate_limit external_payments_limit].include?(limit)

      if self.policy_coverages.exists?(designation: designation)
        coverage = self.policy_coverages.where(designation: designation).take
        return coverage.send(limit)
      else
        return nil
      end
    end

    def qbe_specialty_issue_coverage(insurable, users, start_coverage, force = false, primary_user: nil)
      to_return = false

      coverage = self.policies.new(
        number: "#{ self.number }-" + (self.policies.count + 1).to_s,
        effective_date: start_coverage,
        agency_id: self.agency_id,
        account_id: self.account_id,
        carrier_id: self.carrier_id,
        status: "BOUND",
        policy_type_id: 3,
        force_placed: force
      )

      if coverage.save!
        to_return = true
        coverage.insurables << insurable
        users.sort_by { |user| primary_user == user ? -1 : 0 } unless primary_user.nil?
        users.each do |user|
          coverage.users << user
          Compliance::PolicyMailer.with(organization: self.account ? self.account : self.agency)
                                  .enrolled_in_master(user: user,
                                                      community: insurable.parent_community(),
                                                      force: force).deliver_now
        end
      end

      return to_return
    end

    def qbe_specialty_evict_master_coverage
      if self.status == "BOUND"
        eviction_time = Time.current
        self.update status: "CANCELLED", cancellation_date: eviction_time, expiration_date: eviction_time
      end
    end

    def qbe_specialty_issue_policy
      %w[evidence_of_insurance premises_liability_endorsement property_coverage_endorsement].each do |document|
        qbe_generate_master_document(document, {
          :@user => primary_user(),
          :@coverage => self,
          :@master_policy => self.policy
        })
      end
    end

    def qbe_generate_master_document(document, args)
      raise ArgumentError.new(
        "#{ document.gsub("_", " ").titlecase } no supported"
      ) unless %w[evidence_of_insurance premises_liability_endorsement property_coverage_endorsement].include?(document)

      document_file_title = "qbe-master-#{ document.gsub('_', '-') }-#{ id }-#{ Time.current.strftime("%Y%m%d-%H%M%S") }.pdf"

      pdf = WickedPdf.new.pdf_from_string(
        ActionController::Base.new.render_to_string(
          "v2/qbe_specialty/#{ document }",
          locals: args
        ),
        page_size: 'A4',
        encoding: 'UTF-8',
        disable_smart_shrinking: true
      )

      # then save to a file
      FileUtils::mkdir_p "#{ Rails.root }/tmp/eois/qbe/master-policy"
      save_path = Rails.root.join('tmp/eois/qbe/master-policy', document_file_title)

      File.open(save_path, 'wb') do |file|
        file << pdf
      end

      if documents.attach(io: File.open(save_path), filename: "evidence-of-insurance.pdf", content_type: 'application/pdf')
        File.delete(save_path) if File.exist?(save_path) unless %w[local development].include?(ENV["RAILS_ENV"])
      end
    end

    def get_unit_ids
      unit_ids = []
      self.insurables.where(insurable_type_id: InsurableType::RESIDENTIAL_COMMUNITIES_IDS).each do |ins|
        unit_ids += ins.units.pluck(:id)
      end
      return unit_ids.blank? ? nil : unit_ids
    end

    def find_closest_master_policy_configuration(insurable = nil, cutoff_date = nil)
      cutoff_date = DateTime.current.to_date if cutoff_date.nil?
      master_policy_configuration = nil

      unless insurable.nil?
        community = nil
        if ::InsurableType::RESIDENTIAL_COMMUNITIES_IDS.include?(insurable.insurable_type_id)
          community = insurable
        elsif (::InsurableType::RESIDENTIAL_BUILDINGS_IDS + ::InsurableType::RESIDENTIAL_UNITS_IDS).include?(insurable.insurable_type_id)
          community = insurable.parent_community
        end

        if !community.nil? && self.insurables.include?(community)
          carrier_policy_type = CarrierPolicyType.where(carrier_id: self.carrier_id, policy_type: self.policy_type_id).take
          closest_link = nil
          if community.master_policy_configurations.where(carrier_policy_type: carrier_policy_type).count > 0
            master_policy_configuration = community.master_policy_configurations
                                                   .where(carrier_policy_type: carrier_policy_type)
                                                   .where("program_start_date < ?", cutoff_date)
                                                   .order("program_start_date desc").limit(1).take
            closest_link = "community"
          elsif !self.master_policy_configurations.nil? && closest_link.nil?
            master_policy_configuration = self.master_policy_configurations
                                              .where("program_start_date < ?", cutoff_date)
                                              .order("program_start_date desc").limit(1).take
            closest_link = "master_policy"
          elsif self.account.master_policy_configurations.where(carrier_policy_type: carrier_policy_type).count > 0 && closest_link.nil?
            master_policy_configuration = self.account.master_policy_configurations
                                                      .where(carrier_policy_type: carrier_policy_type)
                                                      .where("program_start_date < ?", cutoff_date)
                                                      .order("program_start_date desc").limit(1).take
          end
        end
      end

      return master_policy_configuration
    end

  end
end
