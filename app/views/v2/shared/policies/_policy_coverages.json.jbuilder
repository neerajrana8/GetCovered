case policy.carrier&.integration_designation
when 'msi'
  json.policy_coverages do
    json.partial! 'v2/shared/policies/policy_coverages/msi.json.jbuilder', policy_coverages: policy.policy_coverages
  end
else
  #json.policy_coverages policy.coverages

  json.policy_coverages do

    json.coverage_limits do
      json.array! policy.policy_coverages.map do |policy_coverage|
        json.designation policy_coverage.designation
        json.title policy_coverage.title
        json.limit policy_coverage.limit
      end
    end

    json.deductibles do
      json.array! policy.policy_coverages.map do |policy_coverage|
        json.designation policy_coverage.designation
        json.title policy_coverage.title
        json.deductible policy_coverage.deductible
      end
    end

    json.optional_coverages @optional_coverages
  end
end
