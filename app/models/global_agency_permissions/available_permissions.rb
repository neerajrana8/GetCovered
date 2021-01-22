module GlobalAgencyPermissions
  module AvailablePermissions
    AVAILABLE_PERMISSIONS = [
      { key: 'dashboard.leads', default_value: true },
      { key: 'dashboard.properties', default_value: true },
      { key: 'policies', default_value: true },
      { key: 'policies.master', default_value: true },
      { key: 'policies.rent_mass_import', default_value: true },
      { key: 'policies.claims', default_value: true },
      { key: 'policies.coverage_proof', default_value: true }
    ].freeze
  end
end
