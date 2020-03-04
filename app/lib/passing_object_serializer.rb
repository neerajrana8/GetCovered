# This class is used in the passing unsaved active record objects to the active job
class PassingObjectSerializer
  class << self
    def serialize(data)
      Base64.encode64(Marshal.dump(data))
    end

    def deserialize(serialized_data)
      serialized_data = Base64.decode64(serialized_data)
      Marshal.load serialized_data
    end
  end
end
