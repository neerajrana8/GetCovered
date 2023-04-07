# Preview all emails at http://localhost:3000/rails/mailers/policy
class PolicyPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/policy/coverage_proof_uploaded
  def coverage_proof_uploaded
    policy = Policy.where.not(agency_id: nil, branding_profile_id: nil).last
    PolicyMailer.with(policy: policy).coverage_proof_uploaded
  end
end
