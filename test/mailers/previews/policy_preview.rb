# Preview all emails at http://localhost:3000/rails/mailers/policy
class PolicyPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/policy/coverage_proof_uploaded
  def coverage_proof_uploaded
    PolicyMailer.with(policy: Policy.first).coverage_proof_uploaded
  end
end
