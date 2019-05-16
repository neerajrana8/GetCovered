@view = {
  table_name: "agencies",
  has_many: [
    "staffs": { index: false, show: true, short: false }
  ], # List has many models included on views (optional)
  has_one: [], # List has one included on views (optional)
  belongs_to: [
    "staff": { index: false, show: true, short: false }
  ], # List belongs to included on views (optional)
  namespaces: [
    utility: {
      available: true,
      exclusions: {
        models: [], # model name to be excluded from view in this namespace
        fields: [], # field name to be excluded from view in this namespace 
      }
    },
    account: {
      available: true,
      exclusions: {
        models: [], # model name to be excluded from view in this namespace
        fields: [], # field name to be excluded from view in this namespace 
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