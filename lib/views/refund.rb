# frozen_string_literal: true

@view = {
  table_name: 'refunds',
  relationship_plural: [
    "notifications": { index: true, show: true, short: false }
  ],
  relationship_singular: [
    "charge": { index: false, show: true, short: false }
  ],
  short: [],
  namespaces: [
    utility: {
      available: true,
      exclusions: {
        models: [],
        fields: [:stripe_id]
      }
    },
    staff: {
      available: true,
      exclusions: {
        models: [],
        fields: [:stripe_id]
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
