class AddBrandingProfileIdToPoliciesAndPolicyApplications < ActiveRecord::Migration[5.2]
  def up
    add_column :policy_applications, :branding_profile_id, :integer
    add_column :policies, :branding_profile_id, :integer

    set_branding_profiles
  end

  def down
    remove_column :policy_applications, :branding_profile_id
    remove_column :policies, :branding_profile_id, :integer
  end

  private

  def set_branding_profiles
    PolicyApplication.
      where.not(policy_type_id: [PolicyType::MASTER_COVERAGE_ID, PolicyType::MASTER_ID]).each do |policy_application|
      policy_application.update(branding_profile: BrandingProfiles::FindByObject.run!(object: policy_application))
    end

    Policy.
      where(policy_in_system: true).
      where.not(policy_type_id: [PolicyType::MASTER_COVERAGE_ID, PolicyType::MASTER_ID]).each do |policy|
      policy.update(branding_profile: BrandingProfiles::FindByObject.run!(object: policy))
    end
  end
end
