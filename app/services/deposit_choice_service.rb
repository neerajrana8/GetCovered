# https://api-dev.alignfinancial.com/v1/depositchoice/v1/api/WHATEVER

# Deposit Choice Service Model
# file: app/models/deposit_choice_service.rb
#

require 'base64'
require 'fileutils'

class DepositChoiceService

  def self.carrier_id
    6
  end

  ENDPOINT_DICTIONARY = {
    address: 'Address',
    binder: 'Binder',
    insured: 'Insured',
    rate: 'Rate',
    all_rates: 'Rate/GetAll'
  }
  
  HTTP_VERB_DICTIONARY = {
    address: :get,
    binder: :post,
    insured: :post,
    rate: :get,
    all_rates: :get
  }

  include HTTParty
  include ActiveModel::Validations
  include ActiveModel::Conversion
  extend ActiveModel::Naming
  
  attr_accessor :message_content,
    :errors,
    :request,
    :action
    
  
  def initialize
    self.action = nil
    self.errors = nil
  end
  

  def build_request(action_name, **args)
    self.action = action_name
    self.errors = nil
    begin
      self.send("build_#{action_name}", **args)
    rescue ArgumentError => e
      self.errors = { arguments: e.message }
    end
    return self.errors.blank?
  end
  
  def endpoint_for(which_call)
    Rails.application.credentials.deposit_choice[:uri][ENV['RAILS_ENV'].to_sym] + "/#{ENDPOINT_DICTIONARY[which_call.to_sym]}"
  end
  

  def build_address(
    address: nil,
    address1: nil, address2: nil, city: nil, state: nil, zip_code: nil,
    **compilation_args
  )
    # make parameters sane
    if !address.nil?
      address1 ||= "#{address.street_number} #{address.street_name}"
      address2 ||= address.street_two
      city ||= address.city
      state ||= address.state
      zip_code ||= address.zip_code
    else
      # MOOSE WARNING: are these all actually optional?
      nil_fellas = {'address1'=>address1,'city'=>city,'state'=>state,'zip_code'=>zip_code}.select{|k,v| v.blank? }
      if nil_fellas.length == 0
        # we have all the fields we need; do nothing
      elsif nil_fellas.length == 4
        raise ArgumentError.new("'address' cannot be blank unless individual address fields are provided")
      else
        raise ArgumentError.new("fields '#{nil_fellas.keys.join("', '")}' cannot be blank unless 'address' provided")
      end
    end
    address2 = nil if address2.blank?
    # it's go time
    self.action = :address
    self.errors = nil
    self.message_content = {
      address1:   address1,
      address2:   address2,
      city:       city,
      stateCode:  state,
      zipCode:    zip_code
    }.compact
    return errors.blank?
  end
  
  
  def build_insured(
    address_id:, unit_id:,
    user: nil, first_name: nil, last_name: nil, email: nil,
    payment_token:
  )
    # fix user params
    if !user.nil?
      first_name ||= user.profile.first_name
      last_name ||= user.profile.last_name
      email ||= user.email
    else
      if first_name.blank?
        raise ArgumentError.new("'first_name' cannot be blank unless 'user' is provided")
      elsif last_name.blank?
        raise ArgumentError.new("'last_name' cannot be blank unless 'user' is provided")
      elsif email.blank?
        raise ArgumentError.new("'email' cannot be blank unless 'user' is provided")
      end
    end
    # go wylde
    self.action = :insured
    self.errors = nil
    self.message_content = {
      addressId: address_id,
      unitId: unit_id,
      firstName: first_name,
      lastName: last_name,
      emailAddress: email,
      paymentToken: payment_token
    }
    return errors.blank?
  end
  
  
  def build_rate(
    unit_id:, effective_date:
  )
    self.action = :rate
    self.errors = nil
    self.message_content = {
      unitId: unit_id,
      effectiveDate: effective_date.strftime("%F")
    }
    return errors.blank?
  end
  
  def build_all_rates(
  )
    self.action = :all_rates
    self.errors = nil
    self.message_content = {}
    return errors.blank?
  end
  
  def build_binder(
    insured_id:, insured_email: nil, # insured_email will be taken from primary_occupant if needed
    address_id:, unit_id:,
    move_in_date:,
    bond_amount:, rated_premium:, processing_fee:,
    primary_occupant:,
    additional_occupants: []
  )
    # get 'em, billy!
    primary_occupant = primary_occupant.get_deposit_choice_occupant_hash if primary_occupant.class == ::User
    additional_occupants.map!{|ao| ao.class == ::User ? ao.get_deposit_choice_occupant_hash : ao }
    insured_email = primary_occupant[:email] if insured_email.nil?
    # go wylde
    self.action = :binder
    self.errors = nil
    self.message_content = {
      insuredId: insured_id,
      insuredEmail: insured_email,
      addressId: address_id,
      unitId: unit_id,
      moveInDate: move_in_date.to_s, # MOOSE WARNING: format? docs have "2020-09-02T19:08:05.1511447-07:00"
      bondAmount: bond_amount,
      ratedPremium: rated_premium,
      processingFee: processing_fee,
      occupants: [primary_occupant.merge({ isPrimaryOccupant: true })] + additional_occupants.map{|ao| ao.merge({ isPrimaryOccupant: false }) }
    }
    return errors.blank?
  end
  
  
  
  
  
  
  ##
  def call
    # set up call_data
    call_data = {
      error: false,
      code: 200,
      message: nil,
      response: nil,
      data: nil
    }
    # grab authorization
    access_token = nil
    auth = acquire_authorization
    if auth.code == 200 && auth.parsed_response["access_token"]
      access_token = auth.parsed_response["access_token"]
    else
      call_data = {
        error: true,
        code: auth.code,
        message: "Authorization Error: #{auth.parsed_response&.[]("error") || "remote server rejected authorization attempt"}",
        response: e
      }
      puts "\nERROR"
    end
    # try to call
    unless access_token.nil?
      begin
        # make the call
        if HTTP_VERB_DICTIONARY[self.action] == :post
          call_data[:response] = HTTParty.post(endpoint_for(self.action),
            body: message_content.to_json,
            headers: {
              'Content-Type' => 'application/json',
              'Authorization' => "Bearer #{access_token}",
              'Referer' => Rails.application.credentials.deposit_choice[:referer][ENV['RAILS_ENV'].to_sym]
            },
            ssl_version: :TLSv1_2 # MOOSE WARNING: here and in get below, we need to add the right headers etc.
          )
        else # get
          call_data[:response] = HTTParty.get(endpoint_for(self.action),
            query: message_content.transform_keys{|k| k.to_s },
            headers: {
              'Accept' => 'text/plain',
              'Authorization' => "Bearer #{access_token}",
              'Referer' => Rails.application.credentials.deposit_choice[:referer][ENV['RAILS_ENV'].to_sym]
            },
            ssl_version: :TLSv1_2
          )
        end
        # handle errors
        unless [200,201].include?(call_data[:response].code)
          call_data = {
            error: true,
            code: call_data[:response].code,
            message: "An error occurred on the remote server",
            response: call_data[:response]
          }
        end
      rescue StandardError => e
        call_data = {
          error: true,
          code: 500,
          message: 'Request Timeout',
          response: e
        }
        puts "\nERROR"
      end
    end
    # handle response
    if call_data[:error]
      puts 'ERROR ERROR ERROR'.red
      pp call_data
    else
      call_data[:data] = call_data[:response].parsed_response
    end
    # scream to the console for the benefit of any watchers
    display_status = call_data[:error] ? 'ERROR' : 'SUCCESS'
    display_status_color = call_data[:error] ? :red : :green
    puts "#{'['.yellow} #{'Deposit Choice Service'.blue} #{']'.yellow}#{'['.yellow} #{display_status.colorize(display_status_color)} #{']'.yellow}: #{action.to_s.blue}"
    # all done
    return call_data
  end
  
  

  def acquire_authorization
    result = HTTParty.post(Rails.application.credentials.deposit_choice[:identity_uri][ENV['RAILS_ENV'].to_sym],
      body: "grant_type=client_credentials&scope=depositchoice",
      headers: {
        'Content-Type' => 'application/x-www-form-urlencoded',
        'Authorization' => "Basic #{Base64.strict_encode64("#{Rails.application.credentials.deposit_choice[:identity][ENV['RAILS_ENV'].to_sym]}:#{Rails.application.credentials.deposit_choice[:client_secret][ENV['RAILS_ENV'].to_sym]}")}",
        'Referer' => Rails.application.credentials.deposit_choice[:referer][ENV['RAILS_ENV'].to_sym]
      },
      ssl_version: :TLSv1_2
    )
    return result
  end
    
    
    
    
    
  
    
    
    
    
    
end


