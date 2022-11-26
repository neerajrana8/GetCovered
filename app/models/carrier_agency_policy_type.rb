# == Schema Information
#
# Table name: carrier_agency_policy_types
#
#  id                     :bigint           not null, primary key
#  carrier_agency_id      :bigint
#  policy_type_id         :bigint
#  commission_strategy_id :bigint           not null
#  collector_type         :string
#  collector_id           :bigint
#
##
# CarrierAgencyPolicyType Model
# file: +app/models/carrier_agency_policy_type.rb+

class CarrierAgencyPolicyType < ApplicationRecord
  attr_accessor :callbacks_disabled
  attr_accessor :disable_tree_repair

  belongs_to :carrier_agency
  belongs_to :policy_type
  belongs_to :commission_strategy # the commission strategy to use for these policies
  belongs_to :collector,          # who will collect payments on these (null = get covered)
             polymorphic: true,
             optional: true
    
  has_one :carrier,
          through: :carrier_agency
  has_one :agency,
          through: :carrier_agency
  
  accepts_nested_attributes_for :commission_strategy
  
  def parent_carrier_agency_policy_type(include_top_level = false) # iff true, for top-level agency, includes master agency record
    ::CarrierAgencyPolicyType.references(:carrier_agencies).includes(:carrier_agency)
                             .where(carrier_agencies: { carrier_id: self.carrier_id, agency_id: (include_top_level && self.carrier_agency.agency.agency_id.nil? ? ::Agency.where(master_agency: true).take.id : self.carrier_agency.agency.agency_id) }, policy_type_id: self.policy_type_id).take
  end

  def child_carrier_agency_policy_types(include_top_level = false) # iff true, for master agency, includes CAPTs for top-level agencies
    ::CarrierAgencyPolicyType.references(carrier_agencies: :agencies).includes(carrier_agency: :agency)
                             .where(carrier_agencies: { carrier_id: self.carrier_id, agencies: { agency_id: [self.agency_id] + (include_top_level && self.agency.master_agency ? [nil] : []) }}, policy_type_id: self.policy_type_id)
                             .where.not(id: self.id)
      .where(carrier_agencies: { carrier_id: carrier_id, agency_id: carrier_agency.agency.agency_id }, policy_type_id: policy_type_id).take
  end

  def carrier_policy_type
    ::CarrierPolicyType.where(policy_type_id: policy_type_id, carrier_id: carrier_agency.carrier_id).take
  end

  def carrier_agency_authorizations
    ::CarrierAgencyAuthorization.where(policy_type_id: policy_type_id, carrier_agency_id: carrier_agency_id)
  end

  def billing_strategies
    ::BillingStrategy.where(policy_type_id: policy_type_id, carrier_id: carrier_agency.carrier_id, agency_id: carrier_agency.agency_id)
  end

  def agency_id
    carrier_agency.agency_id
  end

  def carrier_id
    carrier_agency.carrier_id
  end
  
  before_validation :manipulate_dem_nested_boiz_like_a_boss, # this cannot be a before_create, or the CS will already have been saved
                    unless: proc { |capt| capt.callbacks_disabled }
  after_create :create_authorizations,
               unless: proc { |capt| capt.callbacks_disabled }
  after_create :set_billing_strategies,
    unless: Proc.new{|capt| capt.callbacks_disabled }
  after_create :set_carrier_preferences
  after_update :repair_commission_strategy_tree,
    if: Proc.new{|capt| !capt.disable_tree_repair && capt.saved_change_to_attribute?('commission_strategy_id') }
  before_destroy :refuse_to_perish_if_a_parent
  before_destroy :remove_authorizations,
                 :disable_billing_strategies

  private
    
    def create_authorizations
      # Prevent Alaska & Hawaii as being set as available; prevent already-created CAAs from being recreated
      blocked_states = [0, 11]
      skipped_states = ::CarrierAgencyAuthorization.where(carrier_agency_id: carrier_agency_id, policy_type_id: policy_type_id).map { |caa| caa.read_attribute_before_type_cast(:state) }
      51.times do |state|
        next if skipped_states.include?(state)

        ::CarrierAgencyAuthorization.create!(
          carrier_agency_id: carrier_agency_id,
          policy_type_id: policy_type_id,
          state: state,
          available: blocked_states.include?(state) ? false : true
        )
      end
    end

    def refuse_to_perish_if_a_parent
      chillenz = self.child_carrier_agency_policy_types(true)
      unless chillenz.blank?
        errors.add(:base, "cannot be destroyed due to presence of child CAPTs (IDs #{chillenz.map{|c| c.id }.join(', ')})")
        raise ActiveRecord::RecordNotDestroyed, self
      end
    end

    def set_billing_strategies
      # Create billing strategies as dups of GC's billing strategies, unless we already have some
      return if agency.master_agency

      strats = ::BillingStrategy.where(agency_id: [agency_id, ::Agency.where(master_agency: true).take.id], carrier_id: carrier_id, policy_type: policy_type_id).order("created_at desc")
      if strats.any? { |bs| bs.agency_id == agency_id }
        # our agency already has billing strats... so for each enabled GC billing strategy, verify we have a corresponding enabled one; otherwise enable one of ours that corresponds, or create a new one for us
        strats = strats.group_by{|bs| bs.agency_id == agency_id }
                       .transform_values{|bses| bses.group_by{|bs| "#{bs.title}#{bs.carrier_code}" } }
        strats[false]&.each do |tcc, bses|
          gc_bs = bses.find{|bumble| bumble.enabled }
          next unless gc_bs
          # make sure at least one is enabled
          ag_bses = strats[true][tcc] || []
          unless ag_bses.any?{|bs| bs.enabled }
            if ag_bses.blank?
              new_bs = gc_bs.dup
              new_bs.agency_id = agency_id
              new_bs.save!
            else
              ag_bses.first.update!(enabled: true)
            end
          end
        end
      else
        # only GC billing strategies exist, so create some for our agency
        strats.each do |bs|
          new_bs = bs.dup
          new_bs.agency_id = agency_id
          new_bs.save!
        end
      end
    end

    def remove_authorizations
      carrier_agency_authorizations.destroy_all
    end

    def disable_authorizations
      carrier_agency_authorizations.each { |caa| caa.update available: false } # this isn't actually used right now...
    end

    def disable_billing_strategies
      billing_strategies.update_all(enabled: false)
    end
    
    def set_carrier_preferences
      cs = self.agency.reload.carrier_preferences
      cs ||= { 'by_policy_type' => {} }
      cs['by_policy_type'][self.policy_type_id.to_s] ||= ::Address.states.keys.map{|s| [s.to_s, { 'carrier_ids' => [] }] }.to_h
      ::Address.states.keys.each do |state|
        cs['by_policy_type'][self.policy_type_id.to_s][state.to_s] ||= { 'carrier_ids' => [] }
        cs['by_policy_type'][self.policy_type_id.to_s][state.to_s]['carrier_ids'].push(self.carrier_id) unless cs['by_policy_type'][self.policy_type_id.to_s][state.to_s]['carrier_ids']&.include?(self.carrier_id)
      end
      self.agency.update(carrier_preferences: cs)
    end
    
    # fills out appropriate defaults for passed CommissionStrategy nested attributes or unsaved associated model;
    # if no commission strategy is passed and our parent CommissionStrategy (i.e. our parent agency's corresponding CAPT's commission strategy, or if no parent agency, our corresponding CarrierPolicyType's commission strategy)
    # has recipient == self.agency, we go ahead and create a child CommissionStrategy with the same data but a more descriptive title (assuming no one creates CAPTs whose CS recipient is not the CAPT's agency, this
    # can only happen when self.agency == GetCovered, since the parent CS will belong to a CarrierPolicyType and they always have recipient GetCovered)
    def manipulate_dem_nested_boiz_like_a_boss
      if self.commission_strategy.nil?
        meesa_own_daddy = self.carrier_agency.agency.agency_id.nil? ?
          self.carrier_policy_type.commission_strategy
          : parent_carrier_agency_policy_type.commission_strategy
        if meesa_own_daddy && meesa_own_daddy.recipient == self.carrier_agency.agency
          self.commission_strategy = ::CommissionStrategy.new(
            title: "#{self.carrier_agency.agency.title} / #{self.carrier_agency.carrier.title} #{self.policy_type.title} Commission",
            percentage: meesa_own_daddy.percentage,
            recipient: self.carrier_agency.agency,
            commission_strategy: meesa_own_daddy
          )
        end
      elsif self.commission_strategy.id.nil?
        cs = self.commission_strategy
        cs.title = "#{self.carrier_agency.agency.title} / #{self.carrier_agency.carrier.title} #{self.policy_type.title} Commission" if cs.title.blank?
        cs.recipient = self.carrier_agency.agency if cs.recipient_id.nil? && cs.recipient_type.nil?
        if cs.commission_strategy_id.nil?
          meesa_own_daddy = self.carrier_agency.agency.agency_id.nil? ?
            self.carrier_policy_type.commission_strategy
            : ::CarrierAgencyPolicyType.references(:carrier_agencies).includes(:carrier_agency)
                                       .where(carrier_agencies: { carrier_id: self.carrier_id, agency_id: self.carrier_agency.agency.agency_id }, policy_type_id: self.policy_type_id).take.commission_strategy
          cs.commission_strategy = meesa_own_daddy
        end
        if cs.recipient == cs.commission_strategy.recipient
          cs.percentage = cs.commission_strategy.percentage
        end
      end
    end

    def repair_commission_strategy_tree
      our_agency = self.agency
      old_id = self.attribute_before_last_save('commission_strategy_id')
      # fix siblings if we are master agency
      if our_agency.master_agency
        cpt = self.carrier_policy_type
        cpt.update_columns(commission_strategy_id: self.commission_strategy_id) unless cpt.commission_strategy_id == self.commission_strategy_id # NOTE: we are using update_columns here to intentionally skip callbacks! we don't want to set off a recursive loop
        siblings = ::CarrierAgencyPolicyType.references(:commission_strategies, carrier_agencies: :agencies).includes(:commission_strategy, carrier_agency: :agency)
                    .where(
                      policy_type_id: self.policy_type_id,
                      commission_strategies: { commission_strategy_id: old_id },
                      carrier_agencies: { carrier_id: self.carrier_id, agencies: { agency_id: nil } }
                    )
        begin
          siblings.each do |sibling|
            next if sibling == self
            unless sibling.update(commission_strategy_attributes: ::CommissionStrategy
                                                                     .column_names
                                                                     .select{|cn| !['updated_at', 'created_at'].include?(cn) }
                                                                     .map{|cn| [cn.to_sym, cn == 'commission_strategy_id' ? self.commission_strategy_id : sibling.commission_strategy.send(cn)] }
                                                                     .to_h)
              errors.add(:commission_strategy, "failed to update sibling records during repair_commission_strategy_tree execution (CarrierAgencyPolicyType #{sibling.id} update encountered an error: #{sibling.errors.to_h})")
              raise ActiveRecord::RecordInvalid, self
            end
          end
        rescue ActiveRecord::RecordInvalid => err
          errors.add(:commission_strategy, "failed to update sibling records during repair_commission_strategy_tree execution (CarrierAgencyPolicyType #{err.record.id} update encountered an error: #{err.record.errors.to_h})")
          raise ActiveRecord::RecordInvalid, self
        end
      end
      # fix children whether we're a master agency or not
      kiddos = ::CarrierAgencyPolicyType.references(:commission_strategies, carrier_agencies: :agencies).includes(:commission_strategy, carrier_agency: :agency)
                 .where(
                    policy_type_id: self.policy_type_id,
                    commission_strategies: { commission_strategy_id: old_id },
                    carrier_agencies: { carrier_id: self.carrier_id, agencies: { agency_id: our_agency.id } }
                  )
      begin
        kiddos.each do |kiddo|
          unless kiddo.update(commission_strategy_attributes: ::CommissionStrategy
                                                                   .column_names
                                                                   .select{|cn| !['updated_at', 'created_at'].include?(cn) }
                                                                   .map{|cn| [cn.to_sym, cn == 'commission_strategy_id' ? self.commission_strategy_id : kiddo.commission_strategy.send(cn)] }
                                                                   .to_h)
            errors.add(:commission_strategy, "failed to update child records during repair_commission_strategy_tree execution (CarrierAgencyPolicyType #{kiddo.id} update encountered an error: #{kiddo.errors.to_h})")
            raise ActiveRecord::RecordInvalid, self
          end
        end
      rescue ActiveRecord::RecordInvalid => err
        errors.add(:commission_strategy, "failed to update child records during repair_commission_strategy_tree execution (CarrierAgencyPolicyType #{err.record.id} update encountered an error: #{err.record.errors.to_h})")
        raise ActiveRecord::RecordInvalid, self
      end
    end
end

















