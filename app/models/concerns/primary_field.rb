module PrimaryField
  extend ActiveSupport::Concern

  included do
    @primary_field_parameters = {
      switch_others_primary: false
    }

    before_create :set_first_as_primary
    after_save :switch_others_primary
  end

  class_methods do
    attr_reader :primary_field_parameters

    private

    def primary_field(options)
      permitted_params = %i[
        switch_others_primary
        field
        relation_name
      ]

      @primary_field_parameters.merge!(options.slice(*permitted_params))
    end
  end

  private

  def primary_field_parameters
    self.class.primary_field_parameters
  end

  def set_first_as_primary
    unless assignable.nil?
      self.primary = true if primary_field_relation.count.zero?
    end
  end

  def primary_field_relation
    field = primary_field_parameters[:field]
    relation_name = primary_field_parameters[:relation_name]
    send(field).send(relation_name)
  end

  def switch_others_primary
    if primary_field_parameters[:switch_others_primary] && primary
      primary_field_relation.where.not(id: id).update_all(primary: false)
    end
  end
end
