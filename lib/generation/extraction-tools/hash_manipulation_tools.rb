


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
  (scheme['models'] || {}).each do |m_name, m_data|
    # check for non-existent associations
    
    # expand
    
    pool = m_data['associations']
    # get leaves
    branches = pool.map{|a_name, a_data| a_data['through'] }.compact.uniq
    leaves = pool.select{|a_name, a_data| !a_data['through'].nil? && !branches.include?(m_name) }.keys
    # remove leaves from pool
    leaves.each do |a_name|
      branch = pool[pool[a_name]['through']]
      
    end
  
  
  
  
  
  
  
    to_delete = []
    convergence_reached = false
    something_changed = true

    while !convergence_reached
      convergence_reached = true unless something_changed
      something_changed = false
      (m_data['associations'] || {}).keys.select{|a_name| !to_delete.include?(a_name) }.each do |a_name|
        through = m_data['associations'][a_name]['through']
        unless through.nil?
          if m_data['associations'].has_key?(through)
            something_changed = true
            to_delete.push(a_name)
            m_data['associations'][through]['wherethrough'] = {} unless m_data['associations'][through].has_key?('wherethrough')
            m_data['associations'][through]['wherethrough'][a_name] = m_data['associations'][a_name].select{|k,v| k != 'through' }
          else
            next unless convergence_reached
            block.call(m_name, a_name, through) unless block.nil?
          end
        end
      end
    end
    
    (m_data['associations'] || {}).delete_if{|k,v| to_delete.include?(k) }
  end
end
