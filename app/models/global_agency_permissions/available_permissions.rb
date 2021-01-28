module GlobalAgencyPermissions
  module AvailablePermissions
    # key => default_value
    AVAILABLE_PERMISSIONS = {
      'dashboard.leads' => true,
      'dashboard.properties' => true,
      'policies.policies' => true,
      'policies.master' => true,
      'policies.rent_mass_import' => true,
      'policies.claims' => true,
      'policies.coverage_proof' => true,
      'requests.refunds' => true,
      'property_management.accounts' => true,
      'property_management.managers' => true,
      'property_management.users' => true,
      'agencies.details' => true,
      'agencies.carriers' => true,
      'agencies.agents' => true,
      'agencies.manage_agents' => true,
      'insurables.communities' => true,
      'insurables.buildings' => true,
      'insurables.units' => true,
      'insurables.create' => true
    }.freeze
  end
end
