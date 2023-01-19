# ExpandedCovered Concern
# file: +app/models/concerns/expanded_covered.rb+

module ExpandedCovered
  extend ActiveSupport::Concern

  included do

    def add_to_covered(policy_type_id, policy_id)
      if policy_type_id.present? && policy_id.present?
        self.expanded_covered[policy_type_id.to_s] = [] unless self.expanded_covered.has_key?(policy_type_id.to_s)
        self.expanded_covered[policy_type_id.to_s] << policy_id unless self.expanded_covered[policy_type_id.to_s].include?(policy_id)

        # NOTE: https://getcoveredllc.atlassian.net/browse/GCVR2-768
        return coverage_action_error(policy_type_id, policy_id) if expanded_covered[policy_type_id.to_s].length > 1

        self.covered = true

        Rails.logger.info "#DEBUG expanded_covered=#{expanded_covered}"

        if policy_type_id == 1
          if self.expanded_covered.has_key?("3") && self.expanded_covered["3"].length > 0
            self.expanded_covered["3"].each do |master_coverage_policy_id|
              if Policy.exists?(id: master_coverage_policy_id)
                master_coverage = Policy.find(master_coverage_policy_id)
                master_coverage.qbe_specialty_evict_master_coverage
              end
            end
          end
        end

        save()
        # self.coverage_action_error(policy_type_id, policy_id) if self.expanded_covered[policy_type_id.to_s].length > 1
      end
    end

    def remove_from_covered(policy_type_id, policy_id)
      if policy_type_id.present? && policy_id.present?
        if self.expanded_covered.has_key?(policy_type_id.to_s)
          self.expanded_covered[policy_type_id.to_s].delete(policy_id) if self.expanded_covered[policy_type_id.to_s].include?(policy_id)
          self.expanded_covered.delete(policy_type_id.to_s) if self.expanded_covered[policy_type_id.to_s].blank?
        end
        self.covered = false if self.expanded_covered.blank?
        save()
      end
    end

    def coverage_action_error(policy_type_id, policy_id)
      if policy_type_id.present? && policy_id.present?
        policy_type = PolicyType.find(policy_type_id)

        message = String.new
        message += '<strong>Possible Duplicate Coverage Detected</strong><br><br>'
        message += self.class.to_s.gsub("_", " ").titlecase + ' ID: ' + self.id.to_s + ' may be receiving duplicate coverage '
        message += 'from a ' + policy_type.title + ' policy.  Policy ID: ' + policy_id.to_s + ' was added on '
        message += Time.current.strftime('%B %d, %Y, %H:%I:%S') + '.  This ' + self.class.to_s.gsub("_", " ").titlecase
        message += ' currently has ' + self.expanded_covered[policy_type_id.to_s].count.to_s + ' policies.  If this is an '
        message += 'error, please notify the dev team as soon as possible.'

        @error = ModelError.create!(
          kind: "duplicate_#{ policy_type.slug }_coverage_error",
          model_type: self.class,
          model_id: self.id,
          description: message
        )
      end
    end

  end
end
