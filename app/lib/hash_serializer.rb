class HashSerializer
  def self.dump(hash)
    hash.transform_values { |val| ActiveModel::Type::Boolean.new.cast(val) }
  end

  def self.load(hash)
    hash || {}
  end
end
