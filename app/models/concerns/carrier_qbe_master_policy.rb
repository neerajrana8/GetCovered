# =QBE Master Policy Functions Concern
# file: +app/models/concerns/carrier_qbe_master_policy.rb+

module CarrierQbeMasterPolicy
  extend ActiveSupport::Concern

  included do

    def build_coverage_options
      [
        { title: "Liability Coverage", designation: "liability_coverage", limit: 10000000, occurrence_limit: 1000000, deductible: 0, enabled: true },
        { title: "Expanded Liability Coverage", designation: "expanded_liability", limit: 10000000, occurrence_limit: 1000000, deductible: 0, enabled: true },
        { title: "Pet Damage", designation: "pet_damage", limit: 10000000, occurrence_limit: 1000000, deductible: rand(25000..100000).round(-3), enabled: true },
        { title: "Loss of Rent", designation: "loss_of_rents", limit: 10000000, occurrence_limit: 1000000, deductible: 0, enabled: true },
        { title: "Tenant Contingent Contents", designation: "tenant_contingent_contents", limit: 10000000, occurrence_limit: 1000000, deductible: 0, enabled: true },
        { title: "Contingent Contents", designation: "contingent_liability_options", limit: 10000000, occurrence_limit: 1000000, deductible: 0, enabled: true },
        { title: "Landlord Supplemental", designation: "landlord_supplemental", limit: 10000000, occurrence_limit: 1000000, deductible: 0, enabled: true }
      ].each do |coverage|
        self.policy_coverages.create!(coverage)
      end
    end

    def qbe_specialty_issue_coverage(insurable, users, start_coverage)
      coverage = self.policies.new(
        number: "#{ self.number }-" + (self.policies.count + 1).to_s,
        effective_date: start_coverage,
        agency_id: self.agency_id,
        account_id: self.account_id,
        carrier_id: self.carrier_id,
        status: "BOUND",
        policy_type_id: 3
      )

      if coverage.save!
        coverage.insurables << insurable
        users.each do |user|
          coverage.users << user
        end
      end
    end

    def qbe_specialty_issue_policy
      users.each do |user|
        qbe_generate_master_document("evidence_of_insurance", {
          :@user => user,
          :@coverage => self,
          :@master_policy => self.policy
        })
      end
    end

    def qbe_generate_master_document(document, args)
      raise ArgumentError.new(
        "#{ document.gsub("_", " ").titlecase } no supported"
      ) unless %w[evidence_of_insurance premises_liability_endorsement property_coverage_endorsement].include?(document)

      document_file_title = "eoi-qbe-master-#{ id }-#{ document }-#{ Time.current.strftime("%Y%m%d-%H%M%S") }.pdf"

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
      FileUtils::mkdir_p "#{ Rails.root }/tmp/eois"
      save_path = Rails.root.join('tmp/eois', document_file_title)

      File.open(save_path, 'wb') do |file|
        file << pdf
      end

      # if documents.attach(io: File.open(save_path), filename: "evidence-of-insurance.pdf", content_type: 'application/pdf')
      #   File.delete(save_path) if File.exist?(save_path) unless %w[local development].include?(ENV["RAILS_ENV"])
      # end
    end

  end
end