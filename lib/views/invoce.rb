# frozen_string_literal: true

@view = {
  table_name: 'invoices',
  relationship_plural: [
    "charges": { index: false, show: true, short: false },
    "refunds": { index: false, show: true, short: false },
    "disputes": { index: false, show: true, short: false },
    "line_items": { index: false, show: true, short: false },
    "modifiers": { index: false, show: true, short: false },
    "histories": { index: false, show: true, short: false },
    "notifications": { index: false, show: true, short: false }
  ],
  relationship_singular: [
    "user": { index: false, show: true, short: false }
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
        models: [:user],
        fields: []
      }
    },
    public: {
      available: false
    }
  ]
}

return @view
