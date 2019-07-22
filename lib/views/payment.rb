# frozen_string_literal: true

@view = {
  table_name: 'payments',
  relationship_plural: [
    "histories": { index: true, show: true, short: false }
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
      available: true,
      exclusions: {
        models: [:user],
        fields: [:stripe_id]
      }
    },
    public: {
      available: false
    }
  ]
}

return @view
