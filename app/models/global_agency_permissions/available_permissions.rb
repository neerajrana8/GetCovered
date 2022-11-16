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
      'requests.cancellations' => true,
      'property_management.accounts' => true,
      'property_management.managers' => true,
      'property_management.users' => true,
      'agencies.details' => true,
      'agencies.agents' => true,
      'agencies.manage_agents' => true,
      'agencies.carriers' => true,
      'insurables.create' => true,
      'insurables.communities' => true,
      'insurables.buildings' => true,
      'insurables.units' => true,
      'leases.leases' => true
    }.freeze
  end
end
