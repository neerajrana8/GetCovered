# frozen_string_literal: true

@view = {
  table_name: 'claims',
  relationship_plural: [
    "histories": { index: false, show: true, short: false }
  ],
  relationship_singular: [
    "claimant": { index: false, show: true, short: false },
    "insurable": { index: false, show: true, short: false },
    "policy": { index: false, show: true, short: false }
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
