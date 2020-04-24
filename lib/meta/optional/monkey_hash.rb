class Hash
  def +(other_hash) # why on earth isn't this native?
    throw "A-WOOGA! A-WOOGA! Invalid logic alert! Hashes can only be added to other hashes, not '#{other_hash.class.name}' objects! A-WOOGA! A-WOOGA!" unless other_hash.class == ::Hash
    self.merge(other_hash)
  end
end
