# frozen_string_literal: true

@view = {
  table_name: 'events',
  relationship_plural: [],
  relationship_singular: [
    "eventable": { index: false, show: true, short: false }
  ],
  short: [],
  namespaces: [
    utility: {
      available: true,
      exclusions: {
        models: [],
        fields: []
      }
    },
    staff: {
      available: true,
      exclusions: {
        models: [],
        fields: []
      }
    },
    user: {
      available: true,
      exclusions: {
        models: [],
        fields: []
      }
    },
    public: {
      available: false
    }
  ]
}

return @view
