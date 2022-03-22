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

    def qbe_specialty_issue_coverage(insurable, users, start_coverage, force = false)
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
        users.each do |user|
          coverage.users << user
        end
      end

      return to_return
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

  end
end