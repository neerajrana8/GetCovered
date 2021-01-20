module GlobalAgencyPermissions
  module AvailablePermissions
    AVAILABLE_PERMISSIONS = [
      { key: 'dashboard.leads', default_value: true },
      { key: 'dashboard.properties', default_value: true }
    ].freeze
  end
end
