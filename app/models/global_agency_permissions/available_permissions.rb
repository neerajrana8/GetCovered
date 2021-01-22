module GlobalAgencyPermissions
  module AvailablePermissions
    AVAILABLE_PERMISSIONS = [
      { key: 'dashboard.leads', default_value: true },
      { key: 'dashboard.properties', default_value: true },
      { key: 'policies', default_value: true },
      { key: 'policies.master', default_value: true },
      { key: 'policies.rent_mass_import', default_value: true },
      { key: 'policies.claims', default_value: true },
      { key: 'policies.coverage_proof', default_value: true },
      { key: 'requests.refunds', default_value: true },
      { key: 'requests.cancellations', default_value: true },
      { key: 'users', default_value: true },
      { key: 'agencies.details', default_value: true },
      { key: 'agencies.carriers', default_value: true },
      { key: 'agencies.agents', default_value: true },
      { key: 'insurables', default_value: true },
      { key: 'insurables.communities', default_value: true },
      { key: 'insurables.buildings', default_value: true },
      { key: 'insurables.units', default_value: true },
      { key: 'insurables.create', default_value: true }
    ].freeze
  end
end
