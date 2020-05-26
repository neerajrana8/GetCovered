class InsurableRateConfiguration < ApplicationRecord
  belongs_to :configurable, polymorphic: true
  belongs_to :carrier
  
  def validate_coverages
    # Coverage schema:
    #{
    #  "title"         => string,
    #  "uid"           => string,
    #  "description"   => string (optional)",
    #  "required"      => boolean,
    #  "category"      => 'limit' or 'deductible',
    #  "options_type"  => ["none", "multiple_choice", "min_max"],
    #  "options"       => depends on options_type:
    #     none: omittable,
    #     multiple_choice: array of numerical values
    #     min_max: { min: number, max: number, step: +number }, with step optional & defaulting to 1 only if min & max are both integers
    #}
    self.coverages.each.with_index do |cov,i|
      disp_title = cov["title"].blank? ? "coverage ##{i}" : cov["title"]
      errors.add(:coverage_title, "cannot be blank (#{disp_title})") if cov["title"].blank?
      errors.add(:coverage_uid, "cannot be blank (#{disp_title})") if cov["uid"].blank?
      # description can be blank
      errors.add(:coverage_required, "must be true or false (#{disp_title})") unless [true,false].include?(cov["required"])
      errors.add(:coverage_cateogry, "must be 'limit', or 'deductible'") unless ['limit', 'deductible'].include?(cov["category"])
      case cov["options_type"]
        when "none"
          # all good
        when "multiple_choice"
          errors.add(:coverage_options, "must be a set of numerical options (#{disp_title})") unless cov["options"].class == ::Array # MOOSE WARNING: check numericality
        when "min_max"
          if cov["options"].class !== ::Hash
            erros.add(:coverage_options, "must specify min/max values (#{disp_title})")
          elsif !cov["options"]["min"]
            errors.add(:coverage_options, "must specify min (#{disp_title})")
          elsif !cov["options"]["max"]
            errors.add(:coverage_options, "must specify max (#{disp_title})")
          elsif cov["options"]["min"].to_f > cov["options"]["max"].to_f
            errors.add(:coverage_options_min, "cannot exceed max (#{disp_title})")
          elsif cov["options"]["step"].nil? && (cov["options"]["min"] % 1 != 0 || cov["options"]["max"] % 1 != 0)
            errors.add(:coverage_options, "must specify step for non-integer min and max values (#{disp_title})")
          elsif !cov["options"]["step"].nil? && cov["options"]["step"].to_f <= 0
            errors.add(:coverage_options, "step must be greater than 0 (#{disp_title})")
          end
        else
          errors.add(:coverage_options_type, "must be 'none', 'multiple_choice', or 'min_max' (#{disp_title})")
      end
    end
  end
  
  def validate_rules
    #Rules schema:
    #{
    #  "title"   => string,
    #  "message" => string,
    #  "code" => recursive combination of [operator, ...arguments] arrays
    #}
    
    
  end
  
  def annotate_options(selections)
    # selections should be a hash of form { uid => true (selected)/false(not selected)/some # (for the selected option) }
    to_return = self.coverages.map do |cov|
      
    end
  end
  
  
  
  
  
  
end
