class AddBackTraceAndDescriptionToModelError < ActiveRecord::Migration[6.1]
  def change
    add_column :model_errors, :backtrace, :jsonb
    add_column :model_errors, :description, :text
  end
end
