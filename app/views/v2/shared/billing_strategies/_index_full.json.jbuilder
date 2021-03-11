json.partial! 'v2/shared/billing_strategies/fields.json.jbuilder',
              billing_strategy: billing_strategy

json.agency_title billing_strategy.agency&.title
