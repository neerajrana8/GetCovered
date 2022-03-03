# ExpandedCovered Concern
# file: +app/models/concerns/expanded_covered.rb+

module ExpandedCovered
  extend ActiveSupport::Concern

  included do

    def add_to_covered(policy_type_id, policy_id)
      if policy_type_id.present? && policy_id.present?
        self.expanded_covered[policy_type_id.to_s] = [] unless self.expanded_covered.has_key?(policy_type_id.to_s)
        self.expanded_covered[policy_type_id.to_s] << policy_id unless self.expanded_covered[policy_type_id.to_s].include?(policy_id)
        self.covered = true
        save()
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

  end
end
