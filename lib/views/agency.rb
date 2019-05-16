@view = {
  table_name: "agencies",
  relationship_plural: [
    "staffs": { index: false, show: true, short: false }
  ], # List has many models included on views (optional)
  relationship_singular: [
    "staff": { index: false, show: true, short: false }
  ], # List belongs to included on views (optional)
  short: [ :id, :title, :created_at, :updated_at ], # list of fields to include in _short form defined as a string or symbol
  namespaces: [
    utility: {
      available: true,
      exclusions: {
        models: [], # model name to be excluded from view in this namespace
        fields: [ :stripe_id ], # field name to be excluded from view in this namespace 
      }
    },
    staff: {
      available: true,
      exclusions: {
        models: [ :staffs ], # model name to be excluded from view in this namespace, defined as a string or symbol
        fields: [ :stripe_id, :whitelabel, :tos_accepted, 
                  :tos_accepted_at, :tos_acceptance_ip ], # field name to be excluded from view in this namespace, defined as a string or symbol
      }      
    },
    user: {
      available: false      
    },
    public: {
      available: false     
    }
  ]
}

return @view