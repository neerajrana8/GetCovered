@view = {
  table_name: 'line_items',
  relationship_singular: [
    "invoice": { index: true, show: true, short: false }
  ], # List belongs to included on views (optional)
  short: %i[id title price], # list of fields to include in _short form defined as a string or symbol
  namespaces: [
    staff: {
      available: true,
      exclusions: {
        models: [], # model name to be excluded from view in this namespace, defined as a string or symbol
        fields: [] # field name to be excluded from view in this namespace, defined as a string or symbol
      }
    },
    user: {
      available: true,
      exclusions: {
        models: [], # model name to be excluded from view in this namespace, defined as a string or symbol
        fields: [] # field name to be excluded from view in this namespace, defined as a string or symbol
      }
    },
    public: {
      available: false
    }
  ]
}

return @view