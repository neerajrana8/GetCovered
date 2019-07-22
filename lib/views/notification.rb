# frozen_string_literal: true

@view = {
  table_name: 'notifications',
  relationship_plural: [],
  relationship_singular: [
    "notifiable": { index: false, show: true, short: false },
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
      available: true,
      exclusions: {
        models: [],
        fields: []
      }
    }
  ]
}

return @view
