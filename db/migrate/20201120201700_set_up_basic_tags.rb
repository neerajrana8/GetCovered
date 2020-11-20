class SetUpBasicTags < ActiveRecord::Migration[5.2]
  def up
    {
      'Confie' => nil
    }.each do |title, description|
      ::Tag.create(title: title, description: description) # if it fails due to non-uniqueness, we don't care...
    end
  end
end
