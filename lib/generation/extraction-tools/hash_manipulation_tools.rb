


# takes an optional block which expects args (model_name, assoc_name, through_assoc_name) to handle associations declared multiple times; returned 'handled' to proceed, otherwise oh no oh no
def contract_through_associations(scheme, &block)
  # build a fancy contracting proc
  contractor = Proc.new do |through, associations, model_name|
    associations.each do |a_name, a_data|
      # insert into associations root
      if !scheme['models'][model_name]['associations'].has_key?(a_name) || (!block.nil? && block.call(model_name, a_name, through) == 'handled')
        scheme['models'][model_name]['associations'][a_name] = a_data
        # add through & handle wherethroughs
        a_data['through'] = through
        if a_data.has_key?('wherethrough')
          if contractor.call(a_name, a_data['wherethrough'], model_name)
            a_data.delete('wherethrough')
          end
        end
        next true
      end
      # MOOSE WARNING: oh no oh no we have a duplicate key and it wasn't handled!
      next false
    end
  end
  # invoke the fancy contracting proc on all the models
  (scheme['models'] || {}).keys.each do |m_name|
    ((scheme['models'][m_name] || {})['associations'] || {}).keys.each do |a_name|
      a_data = ((scheme['models'][m_name] || {})['associations'] || {})[a_name] || {}
      if a_data.has_key?('wherethrough')
        if contractor.call(a_name, a_data['wherethrough'], m_name)
          a_data.delete('wherethrough')
        end
      end
    end
  end
end



# takes an optional block which expects args (model_name, assoc_name, through_assoc_name) to handle associations declared as through non-existent other associations
def expand_through_associations(scheme, &block)
  # check for non-existent associations
  (scheme['models'] || {}).each do |m_name, m_data|
    (m_data['associations'] || {}).keys.each do |a_name|
      a_data = m_data['associations'][a_name]
      unless a_data['through'].nil? || m_data['associations'].has_key?(a_data['through'])
      puts "WOAH"
        block.call(m_name, a_name, a_data['through'])
      end
    end
  end
  # expand
  (scheme['models'] || {}).each do |m_name, m_data|
    pool = m_data['associations']
    loop do
      # get leaves
      branches = pool.map{|a_name, a_data| a_data['through'] }.compact.uniq
      leaves = pool.select{|a_name, a_data| !a_data['through'].nil? && !branches.include?(a_name) }
      break if leaves.length == 0
      # remove leaves from pool
      leaves.each do |a_name, a_data|
        branch = pool[a_data['through']]
        a_data.delete_if{|k,v| k == 'through' }
        branch['wherethrough'] = {} unless branch.has_key?('wherethrough')
        branch['wherethrough'][a_name] = a_data
        pool.delete_if{|k,v| k == a_name }
      end
    end
  end
  # done
end
