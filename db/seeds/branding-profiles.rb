# pp BrandingProfile.find_by(title: 'GetCovered').faqs.map{|bpa| bpa.attributes.except('id', 'created_at', 'updated_at').merge(faq_questions_attributes: bpa.faq_questions.map{|fpa| fpa.attributes.except('id', 'created_at', 'updated_at', 'faq_id')})}

# Get Covered
agency = Agency.find_by_title('Get Covered')
params = {
  "url"              => "getcoveredinsurance.com",
  "default"          => false,
  "global_default"   => true,
  "styles"           =>
    { "admin"  =>
        { "colors"  =>
            { "primary" => "#000000", "warning" => "#FF0000", "highlight" => "#FFFFFF" },
          "content" => {} },
      "client" =>
        { "colors"  =>
            { "primary"   => "#1B75BA",
              "warning"   => "#FF6244",
              "highlight" => "#FFFFFF",
              "secondary" => "#00ABE2" },
          "content" =>
            { ".faq-page a"     => { "color" => "#ff6244" },
              ".right-house"    =>
                { "top"               => "0",
                  "right"             => "0",
                  "width"             => "418px",
                  "height"            => "100%",
                  "position"          => "absolute",
                  "background-repeat" => "no-repeat" },
              ".guarantee_wrap" => { "margin-top" => "0" } } } },
  "profileable_type" => "Agency",
  "profileable_id"   => agency.id,
  "logo_url"         =>
    "https://www.getcoveredinsurance.com/assets/logos/logo_blue@2x.png",
  "footer_logo_url"  =>
    "https://www.getcoveredinsurance.com/assets/logos/logo_white@2x.png",
  "subdomain"        => ""
}
branding_profile = BrandingProfile.create(params)
branding_profile_attributes_params = [{"name"=>"residential_fee",
                                       "value"=>"Get Covered",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"faq",
                                       "value"=>"Get Covered",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"faq_phone",
                                       "value"=>"800-833-3448",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"faq_email",
                                       "value"=>"CustomerCare@us.qbe.com",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"contact_email",
                                       "value"=>"info@getcoveredinsurance.com",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"contact_phone",
                                       "value"=>"917-300-8200",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"give_back_partner",
                                       "value"=>"QBE",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"term_of_use",
                                       "value"=>"getcoveredinsurance.com",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"footerCopyrightText",
                                       "value"=>"<p>Copyright @ getcovered 2023. </p><p>All rights reserved.</p>",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"show_back_button",
                                       "value"=>"false",
                                       "attribute_type"=>"boolean",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"r_header2",
                                       "value"=>
                                         "<p style=\"margin-top:15px; font-size: 18px\">4 quick steps to get you covered. </p>",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"fee_notice",
                                       "value"=>
                                         "**There is an annual administrative fee of <b>${fee}</b> charged by Get Covered to recover the reasonable costs for administrative services provided to your landlord that are not associated with the sale, solicitation, negotiation and servicing of this policy, including, but not limited to, upkeep of all mandated properties’ compliance, training and record keeping, tracking and monitoring, as well as risk management and other services not related to the premium or commission received. (this amount is included in quote above; please note the admin fee is not part of premium cost and will show as a separate charge)",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"register_account_notice",
                                       "value"=>
                                         "Registering for an account with Get Covered will allow you to make updates to your account",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"r_header1",
                                       "value"=>
                                         "<p class=\"color_primary\" style=\"font-size: 44px; font-weight: 500;\">Get covered for those<br><span style=\"position: relative; font-size: 44px; white-space: nowrap; font-weight: bold;\" class=\"color_secondary\"><svg xmlns=\"http://www.w3.org/2000/svg\" width=\"196\" height=\"7.094\" viewBox=\"0 0 196 7.094\" style=\"position: absolute; bottom: 0px; width: 200px; max-width: 100%;\">   <defs>    <style>      .cls-1 {        fill: #00abe2;        fill-rule: evenodd;      }    </style>  </defs>  <path id=\"underline.svg\" class=\"cls-1\" d=\"M452,298v-2c68.667,0,127.333-7,196-3v2C579.333,291,520.667,302,452,298Z\" transform=\"translate(-452 -291.781)\"/></svg>OH S#!%</span> moments in life </p>",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"estimate_premium_block",
                                       "value"=>
                                         "<p style=\"font-size: 24px;\">Your Estimate Premium: <br><span style=\"line-height: 50px;  font-size: 30px;  font-weight: bold;\" class=\"color_secondary\">${total}</span></p> <p style=\"font-size: 14px;\">Estimated premiums do not include taxes and fees.</p>",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"optional_addons",
                                       "value"=>"Optional Add Ons",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"background_right_logo",
                                       "value"=>
                                         "https://gc-public-dev.s3-us-west-2.amazonaws.com/uploads/getcovered.png",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id},
                                      {"name"=>"available_forms",
                                       "value"=>"[\"residential\", \"commercial\", \"rent_guarantee\"]",
                                       "attribute_type"=>"text",
                                       "branding_profile_id"=>branding_profile.id}]
BrandingProfileAttribute.create(branding_profile_attributes_params)
pages_attributes = [{"content"=>
                       "<div>  <h2>Contact Us</h2>  <p>We Are Here to Help</p>  <p>Give us a call – <a href=\"tel:917-300-8200\">917-300-8200</a></p>  <p>Send us an – email <a href=\"mailto:info@getcoveredinsurance.com\">info@getcoveredinsurance.com</a></p>\n" +
                         "</div>",
                     "title"=>"contact_us",
                     "agency_id"=>agency.id,
                     "branding_profile_id"=>branding_profile.id,
                     "styles"=>nil},
                    {"content"=>
                       "<div class=\"faq-page\">\n" +
                         "<p class=\"faq-title\">Frequently Asked Questions</p>\n" +
                         "<ol class=\"faq-question\">  <li>\n" +
                         "<p> How do I Get Covered?</p>    <ol class=\"faq-answer\">      <li><p>Get Covered is available by purchasing a policy through our website. We currently offer residential and        commercial insurance in every U.S. state except Hawaii and Alaska. In order to give you an accurate quote, you        will need to have your address, the name of your community where you will reside, when you will be moving, and        the names of all the adults living at that address. The other way is by calling one of our representatives at        800-833-3448. You will need to have all the same info to complete the quote and purchase the policy. </p></li>    </ol>  </li>  <li>\n" +
                         "<p>Are you financially rated?</p>    <ol class=\"faq-answer\">      <li><p>Yes, we’ve earned a Financial Strength Rating of A from AM Best.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>How can I reach you guys?</p>    <ol class=\"faq-answer\">      <li><p>You can get in touch with our team through the website, chat or <a href=\"mailto:info@getcoveredinsurance.com\">email</a>. </p></li>    </ol>  </li>  <li>\n" +
                         "<p>Is my information kept confidential? </p>    <ol class=\"faq-answer\">      <li><p>Your privacy is highly valuable to us. You can see our Privacy Policy <a href=\"/privacy-policy\">here</a>.        Note, we will share certain personal information (name, address, or phone number) with our partners and        providers in order to run our service and to resolve an incident, such as a water leak.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>Is Get Covered an insurance agency?</p>    <ol class=\"faq-answer\">      <li><p>Yes we are!</p></li>    </ol>  </li>\n" +
                         "</ol>  <p class=\"faq-title\">Understanding Insurance</p>\n" +
                         "<ol class=\"faq-question\">  <li>\n" +
                         "<p>What is renters insurance? </p>    <ol class=\"faq-answer\">      <li><p>Renter’s Insurance is property insurance that provides coverage for a policyholder's belongings,        liabilities and possibly living expenses in case of a loss event. This could be your personal belongings against        outside elements, i.e. fire, smoke, theft, water damage and explosion.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>What is a deductible?</p>    <ol class=\"faq-answer\">      <li><p>A deductible is the amount of money you’ll pay for losses or damages, before your insurance company steps        in and reimburses you.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>Do I need renter’s insurance even if my landlord has insurance? </p>    <ol class=\"faq-answer\">      <li><p>Yes. Although your landlord carries coverage for the apartment building itself, there is no coverage for        your personal belongings. Further, in the event you cause damage to your apartment unit or other apartment        property, you will be financially obligated to reimburse the property for those damage repairs. Covering your        personal belongings is your responsibility.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>What is liability protection?</p>    <ol class=\"faq-answer\">      <li><p>Liability Protection is a type of coverage that may help protect you from paying out of pocket for certain        costs if you are found legally responsible for injuries to other people or damage to their property. Liability        insurance policies cover both legal costs and any payouts for which the insured party would be responsible if        found legally liable. Intentional damage and contractual liabilities are generally not covered in these types of        policies.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>What if I don't have much personal property? </p>    <ol class=\"faq-answer\">      <li><p>Renters insurance is still important even if you don't have much personal property because of the liability        component. Also, chances are your personal property is worth more than you think. If you don't have much        personal property to insure, then you can save money by choosing a lower policy limit.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>What is the difference between Liability Insurance and Content Insurance?</p>    <ol class=\"faq-answer\">      <li><p>Personal Liability Coverage: Liability coverage protects you in the event of negligent damage that you may        cause to the property. </p></li>      <li><p>Contents Coverage: When your personal belongings are damaged or stolen your policy contents coverage        reimburses you up to your policy terms and limits.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>As a renter, how much coverage do I need?</p>    <ol class=\"faq-answer\">      <li><p>Your building will most likely have a set minimum policy requirement Your policy limits for coverage should        be determined by the value of your personal property. If you live alone, $10,000 is a good starting point. If        you own jewelry items that are worth more than a $1,000 per item, let us know and we will be happy to provide a        quote for their addition. For couples, we suggest starting with $20,000 - $40,000 coverage.</p></li>    </ol>  </li>\n" +
                         "</ol>\n" +
                         "<div class=\"faq-notif\"><p>**All items are subject to terms and conditions of the policy**</p></div>  <p class=\"faq-title\">Policies</p>\n" +
                         "<ol class=\"faq-question\">  <li>\n" +
                         "<p>How do I know what my policy covers?</p>    <ol class=\"faq-answer\">      <li><p>Get Covered provides you with details on each policy as well as a sample of the policy, all before you pay.        You can edit the type of coverage and settings you want such as coverage limits, deductible and start and end        dates. Once you’ve paid, you will instantly receive your issued policy on the page and via email.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>What policies does Get Covered offer?</p>    <ol class=\"faq-answer\">      <li><p>We offer HO4 and TLL for Residential properties.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>What if I want to cancel my policy?</p>    <ol class=\"faq-answer\">      <li><p>That’s not a problem! We understand life happens and cancelling your policy is just as easy as getting one.        You can cancel your policy at any time by calling or emailing customer service or through the platform. If you        do choose to cancel your policy, you will receive a refund for the rest of the period you’ve paid for. </p></li>    </ol>  </li>  <li>\n" +
                         "<p>Can I switch to Get Covered if I already have an active insurance policy?</p>    <ol class=\"faq-answer\">      <li><p>Absolutely! You can purchase your new policy, then call your current carrier to cancel your existing        policy. Make sure there is no lapse in coverage dates when making the change.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>How do I make changes to my Get Covered policy?</p>    <ol class=\"faq-answer\">      <li>\n" +
                         "<p>You can only update your billing information on the platform. You can email customer care at to make any        changes on your policy. CustomerCare@us.qbe.com or call (client specific telephone number 800-833-3448. </p>      </li>    </ol>  </li>  <li>\n" +
                         "<p>How do I pay for Get Covered?</p>    <ol class=\"faq-answer\">      <li><p>Once you pick and create your policy, you can pay using your credit or debit card or ACH. You will get        charged every month on the same day as your first transaction, unless noted otherwise. </p></li>    </ol>  </li>  <li>\n" +
                         "<p>Is my roommate covered?</p>    <ol class=\"faq-answer\">      <li>\n" +
                         "<p>In order for your roommates to be covered, simply add them as an additional insured when you enroll.</p>      </li>    </ol>  </li>  <li>\n" +
                         "<p>Is my spouse covered?</p>    <ol class=\"faq-answer\">      <li><p> Yes. Spouses and family members under the age of 18 are automatically covered. However, make sure the        content coverage you select is enough to cover all of your belongings. Don’t forget that roommates need to be        listed as an additional insured</p></li>    </ol>  </li>  <li>\n" +
                         "<p>Can I keep my policy if I move?</p>    <ol class=\"faq-answer\">      <li><p>Yes! All you need to do is update your address in the portal and you’re good to go. Keep in mind that your        rate might change when moving. Rates may vary based on location.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>What if I have a pet? </p>    <ol class=\"faq-answer\">      <li><p>Most policies allow for pet damage coverage. There are only 2 states that do not allow for pet damage        coverage to be part of the insurance policy: Connecticut and North Carolina. </p></li>    </ol>  </li>  <li>\n" +
                         "<p>Am I covered if something I own gets stolen outside of my apartment?</p>    <ol class=\"faq-answer\">      <li>\n" +
                         "<p>Yes. If your belongings are stolen from your car, home or anywhere else in the world, you're covered.</p>        <p>*only if there is a police report</p>\n" +
                         "</li>    </ol>  </li>  <li>\n" +
                         "<p>What kind of disasters am I covered for?</p>    <ol class=\"faq-answer\">      <li><p>Your policy provides coverage for theft, wind, hail, arson, riots and vandalism. Be sure to understand the        amount of coverage that you have because a lot of damage means a lot of coverage. </p></li>      <li>\n" +
                         "<p><span class=\"faq-notif\">Theft</span> - If your belongings are stolen from your car, home or anywhere else        in the world, you're covered. </p>        <p>* only if there is a police report</p>\n" +
                         "</li>      <li><p><span class=\"faq-notif\">Lightning </span> - Lightning strikes and damages your favorite things? We have you        covered. </p></li>      <li><p><span class=\"faq-notif\">Windstorm or Hail </span> - If a bad storm happens and hail or wind ruins your        outdoor furniture, we'll take care of the damage. </p></li>    </ol>  </li>  <li>\n" +
                         "<p>What kinds of things are not covered under my Get Covered policy?</p>    <ol class=\"faq-answer\">      <li><p>Unfortunately, some things aren’t covered. Things like vermin (i.e. squirrels, mice) or insect (i.e. ants,        roaches, etc) to floors, insulation or wiring. Flood damage is not included. We also don’t cover personal        property that gets broken or lost by mistake.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>Is my laptop and other expensive items covered?</p>    <ol class=\"faq-answer\">      <li><p>Yes, but only up to a certain limit! Pricey items such as jewelry and paintings are also covered under the        HO4 (Subject to terms and conditions of your policy). There is also an electronics endorsement (currently        available in AZ, CA, CO, DC, GA, IL, IN, MD, MO, OH, PA, TX, VA &amp; WA) that provides coverage for your        electronics. Make sure to check your coverage limit as that will state how much of the policy is actually        covered.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>If I report a loss or have bad credit, will my premium be affected?</p>    <ol class=\"faq-answer\">      <li><p>A credit report is not run during the time you purchase your policy and has no effect on your premium        rate. </p></li>    </ol>  </li>  <li>\n" +
                         "<p>What if I miss a premium payment?</p>    <ol class=\"faq-answer\">      <li><p>If your payment doesn’t go through, we will ask you to provide us with a different form of payment. We will        continue to notify you for 3 more times before we cancel the policy. </p></li>    </ol>  </li>  <li>\n" +
                         "<p>How do you calculate the value of my personal property during a claim?</p>    <ol class=\"faq-answer\">      <li><p>The HO4 policy has Replacement Cost Value (RCV) coverage which guarantees that a policyholder will receive        the full amount necessary to replace covered damaged items with “like” kind or quality while it is anywhere in        the world.</p></li>    </ol>  </li>  <li>\n" +
                         "<p>Do you offer earthquake coverage?</p>    <ol class=\"faq-answer\">      <li><p>Right now, earthquake coverage is an optional endorsement available in California.</p></li>    </ol>  </li>\n" +
                         "</ol>  <p class=\"faq-title\">Claims</p>\n" +
                         "<ol class=\"faq-question\">  <li>\n" +
                         "<p>How do I file a claim?</p>    <ol class=\"faq-answer\">      <li>\n" +
                         "<p>It is simple to report a claim. Please call our claims department and there you will be connected to a live        representative that can handle all your claim issues. 1-844-723-2524 (844-QBE-CLAIMS), our 24/7 hotline.</p>      </li>    </ol>  </li>  <li>\n" +
                         "<p>What do I need to file a claim?</p>    <ol class=\"faq-answer\">      <li>\n" +
                         "<p>Please provide any receipts you may have of your damaged items and images/video of the damage itself. If        you don’t have any receipts, we will try to work with you as best as possible to replace what is necessary!</p>      </li>    </ol>  </li>  <li>\n" +
                         "<p>What’s considered a claim emergency?</p>    <ol class=\"faq-answer\">      <li><p>We consider all claims urgent. You can call 1.844.QBE.CLAIMS to speak to a claims representative 24        hours/day.</p></li>    </ol>  </li>\n" +
                         "</ol>\n" +
                         "<p class=\"faq-title\">Rent Guarantee</p>\n" +
                         "<ol class=\"faq-question\">  <li>\n" +
                         "<p>Where can I find Frequently Asked Questions about Rent Guarantee?</p>    <ol class=\"faq-answer\">      <li>\n" +
                         "<p>Please click <a href=\"/rentguarantee/faq\">here</a> to access our Rent Guarantee FAQ page.</p>      </li>    </ol>  </li>\n" +
                         "</ol>\n" +
                         "</div>",
                     "title"=>"faq_page",
                     "agency_id"=>agency.id,
                     "branding_profile_id"=>branding_profile.id,
                     "styles"=>nil},
                    {"content"=>
                       "<div>\n" +
                         "  <h2>About Us</h2>\n" +
                         "  <div>\n" +
                         "    <p>Get Covered offers an automated, user-friendly solution for a variety of insurance products. Our main focus is to provide affordable insurance policies and rent protection, secured by credited, A-rated carriers.\n" +
                         "   </p>\n" +
                         "    <p>Our mission has been to simplify the process for buying insurance, maintaining the policy and making claims. The process for buying and understanding the policy is just as important as the product itself. We want to protect tenants and clients alike from life’s ‘oh S#%@’ moments.\n" +
                         "    </p>\n" +
                         "    <p>Get Covered is a leader in software solutions and technology. Our customizable interface allows participants to maximize their experience. We were founded in 2017 with a mission to bring better insurance products to the market with full transparency. Insurance can be confusing, we’re here to simplify it.\n" +
                         "    </p>\n" +
                         "  </div>\n" +
                         "</div>\n",
                     "title"=>"about_us",
                     "agency_id"=>agency.id,
                     "branding_profile_id"=>branding_profile.id,
                     "styles"=>nil}]
Page.create(pages_attributes)
faq_attributes = [{"title"=>"Rent Guarantee",
                   "branding_profile_id"=>branding_profile.id,
                   :faq_questions_attributes=>
                     [{"question"=>"How long does Pensio Tenants pay rent to my Landlord?",
                       "answer"=>
                         "When you complete your online Tenant Registration it is your option to customize your Pensio Tenants Rent Guarantee for a 3, 6 or 12-month term. The choice is yours!"},
                      {"question"=>"How much do I pay for the Rent Guarantee?",
                       "answer"=>
                         "Please use the calculator on the website to determine the Rent Guarantee fee. You will need to input the monthly rent amount and the Rent Guarantee term option. For example, if rent is $1,000 and you choose a 3-month Rent Guarantee term option, the Rent Guarantee fee is $35 a month for the year."},
                      {"question"=>
                         "How does a tenant qualify for a Pensio Tenants Rent Guarantee?",
                       "answer"=>
                         "Simply complete the online Tenant Registration enrollment. Make sure your read the <a href=\"https://gc-public-prod.s3-us-west-2.amazonaws.com/uploads/Pensio+Tenants+Rent+Guarantee+Agreement+20200403.pdf\" target=\"_blank\">Rent Guarantee Agreement</a> and <a href=\"https://gc-public-prod.s3-us-west-2.amazonaws.com/uploads/Pensio+Tenants+Rent+Guarantee+Summary+20200403.pdf\" target=\"_blank\">Rent Guarantee Summary</a> before registering in the rent guarantee program and make sure you have a valid and legal lease agreement. The qualifications are simple and clearly outlined in the agreements. We also have options for registering large groups of tenants."},
                      {"question"=>
                         "What happens if a co-tenant loses their job or becomes disabled and unable to work?",
                       "answer"=>
                         "For legal co-tenants on the lease, Pensio Tenants will pay up to 50% of the rent to the Landlord. Further details can be reviewed in the <a href=\"https://gc-public-prod.s3-us-west-2.amazonaws.com/uploads/Pensio+Tenants+Rent+Guarantee+Summary+20200403.pdf\" target=\"_blank\">Rent Guarantee Summary.</a>"},
                      {"question"=>
                         "When does rent get paid if a tenant loses their job or becomes disabled and is unable to work?",
                       "answer"=>
                         "The Rent Guarantee term begins 60 days after registration in the Rent Guarantee program. There must be a valid and legal lease agreement. When the rent guarantee renews each year, the 60-day elimination period does not apply."},
                      {"question"=>
                         "If I make a Rent Guarantee claim on the 11th month, do you still pay my rent for the term I have chosen?",
                       "answer"=>
                         "Yes. Any claim made in the 12-month period will be paid for the term you have chosen. Example: If a tenant has lost their job on the 11th month, Pensio Tenants will pay the rent to the landlord for up to the term chosen, even if the guarantee is not renewed."},
                      {"question"=>
                         "What does a tenant do if they lost their job or are unable to work because of a disability?",
                       "answer"=>
                         "Making a claim is simple and quick. To file a claim, please email <a href=\"mailto:claims@getcoveredllc.com\">claims@getcoveredllc.com</a> and specify you'd like to file a claim."},
                      {"question"=>
                         "Do Pensio Tenants pay the Landlord the rent when there is a successful claim?",
                       "answer"=>
                         "Yes. Pensio Tenants pays the landlord directly. The tenant will be asked to confirm the landlord’s information when a claim is made. Make sure the landlords full contact information is correct."},
                      {"question"=>"Do I have to pay Pensio Tenants back if rent is paid?",
                       "answer"=>
                         "No. We have great news! The rent paid by Pensio Tenants to the landlord does not need to be paid back."},
                      {"question"=>"Can a tenant quit their job and have their rent paid?",
                       "answer"=>
                         "No. The Rent Guarantee only applies to those that have been terminated involuntarily by their employer."},
                      {"question"=>
                         "If I cancel the program, do I still owe money to Pensio Tenants?",
                       "answer"=>
                         "You can cancel your Rent Guarantee payment obligation by sending a notice to <a href=\"mailto:cancel@getcoveredllc.com\">cancel@getcoveredllc.com</a>. When the notice is received we will cancel your Pensio Tenants Rent Guarantee and you will not be obligated to pay any further monthly payments up to the time of your notice to us."},
                      {"question"=>
                         "What happens if I am late paying my monthly Rent Guarantee payment?",
                       "answer"=>
                         "Pensio Tenants will send you a notice electronically to pay your late payment. You will have 30 days to pay the arrears. You will still be covered during this period. After the 30 days has elapsed, your Pensio Rent Guarantee will be cancelled. You will not be responsible for any further payments. You can enroll again as a new registrant, and the 60-day elimination period will apply again. We understand that everyone needs to manage their budget, and we want to help, not hinder you."},
                      {"question"=>"Are tenants covered if there is a Pandemic?",
                       "answer"=>
                         "In the event the federal, state, city, or county government has enacted stay in place orders, restricted public gatherings, closed non-essential businesses, suspended evictions, suspended payment of rent, or has declared a State of Emergency, during the period and for a period of fourteen (14) days thereafter the orders, restrictions, and suspensions have been canceled, the involuntary Job Loss Rent Guarantee is not applicable. The Disability and Partial Disability Rent Guarantee is not applicable if a tenants illness was related directly or indirectly with the stated epidemic or pandemic."},
                      {"question"=>"What and Who is Pensio Tenants?",
                       "answer"=>
                         "Pensio Tenants is a Rent Guarantee surety to pay a landlord rent if a tenant loses their job or become disabled and unable to work. The Pensio Tenants Rent Guarantee is NOT insurance.\n" +
                           "The Pensio Tenants Rent Guarantee is a fully insured obligation to pay based on the terms of the <a href=\"https://gc-public-prod.s3-us-west-2.amazonaws.com/uploads/Pensio+Tenants+Rent+Guarantee+Agreement+20200403.pdf\" target=\"_blank\">Rent Guarantee Agreement</a>. Pensio Tenants is a participating member of Rentalis Insurance Company, Inc., a protected cell captive insurance company reinsured by reinsurers rated AM Best A or Better.\n" +
                           "Pensio Tenants is exclusively administered and operated by World Insurance Associates LLC, licensed insurance producers in all 50 states."},
                      {"question"=>"Who can I contact if I have questions?",
                       "answer"=>
                         "For questions or to speak with a professional, call 917-924-3442 or email <a href=\"mailto:info@getcoveredllc.com\">info@getcoveredllc.com</a>."},
                      {"question"=>
                         "What exactly happens when a tenant successfully enrolls in the Rent Guarantee program?",
                       "answer"=>
                         "While actively enrolled, if a tenant cannot pay rent due to job loss or disability, the Rent Guarantee program will pay rent directly to the landlord for any legal and valid residential lease.\n"},
                      {"question"=>"Who is eligible for Rent Guarantee?",
                       "answer"=>
                         "To be eligible, a tenant must meet ALL the following requirements:\n" +
                           "<ul>\n" +
                           "<li>- Must between the ages of 18 and 64 at time of enrollment, and will not turn 65 at any time during the Rent Guarantee program term</li>\n" +
                           "<li>- They must have a valid and legal lease agreement</li>\n" +
                           "<li>- They must be current on rent</li>\n" +
                           "<li>- They either must be currently employed and have worked for at least 24 hours per week for the last 26 weeks (6 months) or are self-employed and have a verifiable services contract for the term of the Rent Guarantee option</li>\n" +
                           "<li>- They do not have and pre-existing disability or partial disability and are not currently receiving short or long-term benefits</</li>\n" +
                           "<li>- Any co-tenants must be a legal co-signatory of the lease</li>\n" +
                           "</ul>\n" +
                           "For more details, please read over the <a href=\"https://getcovered.docsend.com/view/3nkb45bwz7nxyumg\" target=\"_blank\">Eligibility Summary</a> and <a href=\"https://gc-public-prod.s3-us-west-2.amazonaws.com/uploads/Pensio+Tenants+Rent+Guarantee+Agreement+20200403.pdf\" target=\"_blank\">Rent Guarantee Agreement</a>. There are also options for registering large groups of tenants."}]},
                  {"title"=>"Renters Insurance ",
                   "branding_profile_id"=>branding_profile.id,
                   :faq_questions_attributes=>[]},
                  {"title"=>"About Get Covered ",
                   "branding_profile_id"=>branding_profile.id,
                   :faq_questions_attributes=>
                     [{"question"=>"How do I Get Covered?",
                       "answer"=>
                         "Get Covered is available by purchasing a policy through our website. We currently offer residential and commercial insurance in every U.S. state except Hawaii and Alaska. In order to give you an accurate quote, you will need to have your address, the name of your community where you will reside, when you will be moving, and the names of all the adults living at that address. The other way is by calling one of our representatives at 800-833-3448. You will need to have all the same info to complete the quote and purchase the policy."},
                      {"question"=>"Are you financially rated?",
                       "answer"=>
                         "Yes, we’ve earned a Financial Strength Rating of A from AM Best."},
                      {"question"=>"How can I reach you guys?",
                       "answer"=>
                         "You can get in touch with our team through the website, chat or <a href=\"mailto:info@getcoveredllc.com\">email</a>."},
                      {"question"=>"Is my information kept confidential?",
                       "answer"=>
                         "Your privacy is highly valuable to us. You can see our Privacy Policy <a href=\"https://www.getcoveredinsurance.com/privacy-policy\" target=\"_blank\">here</a>.\n" +
                           "Note, we will share certain personal information (name, address, or phone number) with our partners and providers in order to run our service and to resolve an incident, such as a water leak."},
                      {"question"=>"Is Get Covered an insurance agency?",
                       "answer"=>"Yes we are!"}]},
                  {"title"=>"Understanding Insurance ",
                   "branding_profile_id"=>branding_profile.id,
                   :faq_questions_attributes=>
                     [{"question"=>"What is renters insurance?",
                       "answer"=>
                         "Renter’s Insurance is property insurance that provides coverage for a policyholder's belongings, liabilities and possibly living expenses in case of a loss event. This could be your personal belongings against outside elements, i.e. fire, smoke, theft, water damage and explosion."},
                      {"question"=>"What is a deductible?",
                       "answer"=>
                         "A deductible is the amount of money you’ll pay for losses or damages, before your insurance company steps in and reimburses you."},
                      {"question"=>
                         "Do I need renter’s insurance even if my landlord has insurance?",
                       "answer"=>
                         "Yes. Although your landlord carries coverage for the apartment building itself, there is no coverage for your personal belongings. Further, in the event you cause damage to your apartment unit or other apartment property, you will be financially obligated to reimburse the property for those damage repairs. Covering your personal belongings is your responsibility."},
                      {"question"=>"What is liability protection?",
                       "answer"=>
                         "Liability Protection is a type of coverage that may help protect you from paying out of pocket for certain costs if you are found legally responsible for injuries to other people or damage to their property. Liability insurance policies cover both legal costs and any payouts for which the insured party would be responsible if found legally liable. Intentional damage and contractual liabilities are generally not covered in these types of policies."},
                      {"question"=>"What if I don't have much personal property?",
                       "answer"=>
                         "Renters insurance is still important even if you don't have much personal property because of the liability component. Also, chances are your personal property is worth more than you think. If you don't have much personal property to insure, then you can save money by choosing a lower policy limit."},
                      {"question"=>
                         "What is the difference between Liability Insurance and Content Insurance?",
                       "answer"=>
                         "<b>Personal Liability Coverage</b>: Liability coverage protects you in the event of negligent damage that you may cause to the property.</br>\n" +
                           "<b>Contents Coverage</b>: When your personal belongings are damaged or stolen your policy contents coverage reimburses you up to your policy terms and limits."},
                      {"question"=>"As a renter, how much coverage do I need?",
                       "answer"=>
                         "Your building will most likely have a set minimum policy requirement Your policy limits for coverage should be determined by the value of your personal property. If you live alone, $10,000 is a good starting point.\n" +
                           "If you own jewelry items that are worth more than a $1,000 per item, let us know and we will be happy to provide a quote for their addition.\n" +
                           "For couples, we suggest starting with $20,000 - $40,000 coverage.<br>\n" +
                           "<br>\n" +
                           "<b>**All items are subject to terms and conditions of the policy**</b>"}]},
                  {"title"=>"Policies",
                   "branding_profile_id"=>branding_profile.id,
                   :faq_questions_attributes=>
                     [{"question"=>"How do I know what my policy covers?",
                       "answer"=>
                         "Get Covered provides you with details on each policy as well as a sample of the policy, all before you pay. You can edit the type of coverage and settings you want such as coverage limits, deductible and start and end dates. Once you’ve paid, you will instantly receive your issued policy on the page and via email."},
                      {"question"=>"What policies does Get Covered offer?",
                       "answer"=>
                         "We offer HO4 and TLL for Residential properties and a Rent Guarantee for Tenants and Property Managers."},
                      {"question"=>"What if I want to cancel my policy?",
                       "answer"=>
                         "That’s not a problem! We understand life happens and cancelling your policy is just as easy as getting one. You can cancel your policy at any time by calling or emailing customer service or through the platform. If you do choose to cancel your policy, you will receive a refund for the rest of the period you’ve paid for."},
                      {"question"=>
                         "Can I switch to Get Covered if I already have an active insurance policy?",
                       "answer"=>
                         "Absolutely! You can purchase your new policy, then call your current carrier to cancel your existing policy. Make sure there is no lapse in coverage dates when making the change."},
                      {"question"=>"How do I make changes to my Get Covered policy?",
                       "answer"=>
                         "You can only update your billing information on the platform. You can email customer care at to make any changes on your policy. CustomerCare@us.qbe.com or call 800-833-3448."},
                      {"question"=>"How do I pay for Get Covered?",
                       "answer"=>
                         "Once you pick and create your policy, you can pay using your credit or debit card or ACH. You will get charged every month on the same day as your first transaction, unless noted otherwise."},
                      {"question"=>"Is my roommate covered?",
                       "answer"=>
                         "In order for your roommates to be covered, simply add them as an additional insured when you enroll."},
                      {"question"=>"Is my spouse covered?",
                       "answer"=>
                         "Yes. Spouses and family members under the age of 18 are automatically covered. However, make sure the content coverage you select is enough to cover all of your belongings. Don’t forget that roommates need to be listed as an additional insured"},
                      {"question"=>"Can I keep my policy if I move?",
                       "answer"=>
                         "Yes! All you need to do is update your address in the portal and you’re good to go. Keep in mind that your rate might change when moving. Rates may vary based on location."},
                      {"question"=>"What if I have a pet?",
                       "answer"=>
                         "Most policies allow for pet damage coverage. There are only 2 states that do not allow for pet damage coverage to be part of the insurance policy: Connecticut and North Carolina."},
                      {"question"=>
                         "Am I covered if something I own gets stolen outside of my apartment?",
                       "answer"=>
                         "Yes. If your belongings are stolen from your car, home or anywhere else in the world, you're covered.\n" +
                           "*only if there is a police report\n"},
                      {"question"=>"What kind of disasters am I covered for?",
                       "answer"=>
                         "Your policy provides coverage for theft, wind, hail, arson, riots and vandalism. Be sure to understand the amount of coverage that you have because a lot of damage means a lot of coverage.<br>\n" +
                           "<b>Theft</b> - If your belongings are stolen from your car, home or anywhere else in the world, you're covered. <br>* only if there is a police report<br>\n" +
                           "<b>Lightning</b> - Lightning strikes and damages your favorite things? We have you covered.<br>\n" +
                           "<b>Windstorm or Hail</b> - If a bad storm happens and hail or wind ruins your outdoor furniture, we'll take care of the damage."},
                      {"question"=>
                         "What kinds of things are not covered under my Get Covered policy?",
                       "answer"=>
                         "Unfortunately, some things aren’t covered. Things like vermin (i.e. squirrels, mice) or insect (i.e. ants, roaches, etc) to floors, insulation or wiring. Flood damage is not included. We also don’t cover personal property that gets broken or lost by mistake."},
                      {"question"=>"Is my laptop and other expensive items covered?",
                       "answer"=>
                         "Yes, but only up to a certain limit! Pricey items such as jewelry and paintings are also covered under the HO4 (Subject to terms and conditions of your policy). There is also an electronics endorsement (currently available in AZ, CA, CO, DC, GA, IL, IN, MD, MO, OH, PA, TX, VA & WA) that provides coverage for your electronics. Make sure to check your coverage limit as that will state how much of the policy is actually covered."},
                      {"question"=>
                         "If I report a loss or have bad credit, will my premium be affected?",
                       "answer"=>
                         "A credit report is not run during the time you purchase your policy and has no effect on your premium rate."},
                      {"question"=>"What if I miss a premium payment?",
                       "answer"=>
                         "If your payment doesn’t go through, we will ask you to provide us with a different form of payment. We will continue to notify you for 3 more times before we cancel the policy."},
                      {"question"=>
                         "How do you calculate the value of my personal property during a claim?",
                       "answer"=>
                         "The HO4 policy has Replacement Cost Value (RCV) coverage which guarantees that a policyholder will receive the full amount necessary to replace covered damaged items with “like” kind or quality while it is anywhere in the world."},
                      {"question"=>"Do you offer earthquake coverage?",
                       "answer"=>
                         "Right now, earthquake coverage is an optional endorsement available in California"}]},
                  {"title"=>"Claims ",
                   "branding_profile_id"=>branding_profile.id,
                   :faq_questions_attributes=>
                     [{"question"=>"What do I need to file a claim?",
                       "answer"=>
                         "Please provide any receipts you may have of your damaged items and images/video of the damage itself. If you don’t have any receipts, we will try to work with you as best as possible to replace what is necessary!"},
                      {"question"=>"What’s considered a claim emergency?",
                       "answer"=>
                         "We consider all claims urgent. You can call 1.844.QBE.CLAIMS to speak to a claims representative 24 hours/day."},
                      {"question"=>"How do I file a claim?",
                       "answer"=>
                         "It is simple to report a claim. Please call our claims department and there you will be connected to a live representative that can handle all your claim issues: 1-844-723-2524 (844-QBE-CLAIMS), our 24/7 hotline."}]}]
Faq.create(faq_attributes)

# Cambridge
agency = Agency.find_by_title('Cambridge')
if agency.present?
  params = {
            "url"=>"os.getcoveredinsurance.com",
            "default"=>false,
            "styles"=>
              {"admin"=>
                 {"colors"=>
                    {"primary"=>"#000000", "warning"=>"#FF0000", "highlight"=>"#FFFFFF"},
                  "content"=>{}},
               "client"=>
                 {"colors"=>
                    {"primary"=>"#1B75BA",
                     "warning"=>"#FF6244",
                     "highlight"=>"#FFFFFF",
                     "secondary"=>"#00ABE2"},
                  "content"=>
                    {".faq-page a"=>{"color"=>"#ff6244", "font-weight"=>"bold"},
                     ".rent-pensio"=>{"margin-top"=>"20px"},
                     ".right-house"=>
                       {"top"=>"0",
                        "right"=>"0",
                        "width"=>"418px",
                        "height"=>"100%",
                        "position"=>"absolute",
                        "background-repeat"=>"no-repeat"},
                     ".world-insurance-logo"=>{"display"=>"none"},
                     ".header-content .logo a"=>{"top"=>"15px", "position"=>"relative"},
                     ".rent-guarantee__notice-link"=>{"display"=>"none"}}}},
            "profileable_type"=>"Agency",
            "profileable_id"=>agency.id,
            "logo_url"=>"https://os.getcoveredinsurance.com/assets/cambridge/logo.png",
            "footer_logo_url"=>
              "https://os.getcoveredinsurance.com/assets/cambridge/logo.png",
            "subdomain"=>"os"}

  branding_profile = BrandingProfile.create(params)
  branding_profile_attributes_params = [{"name"=>"r_header1",
                                         "value"=>
                                           "<p style=\"font-size: 44px;font-weight: 500;color:#000080;\">For those unexpected moments in life</p>",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"r_header2",
                                         "value"=>
                                           "<p style=\"margin-top: 15px;font-size: 18px;\">Protect Yourself and Your Belongings </p>",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"contact_address",
                                         "value"=>
                                           "<p>We are open Mon-Fri 8 to 4 CST</p>    <p>100 Pearl Street</p>    <p>14th Floor</p>    <p>Hartford, CT 06103</p>",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"available_forms",
                                         "value"=>"[\"residential\", \"rent_guarantee\"]",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"footerCopyrightText",
                                         "value"=>
                                           "<p>This website and its content is copyright of Cambridge Insurance, Llc. (NPN 13554817).</p>          <p>All rights reserved.          Any redistribution or reproduction of part or all of the contents in            any form is prohibited.</p>",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"residential_fee",
                                         "value"=>"Cambridge Insurance-Occupant Shield",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"faq",
                                         "value"=>"Occupant Shield",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"faq_phone",
                                         "value"=>"800-833-3448",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"faq_email",
                                         "value"=>"CustomerCare@us.qbe.com",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"contact_email",
                                         "value"=>"customercare@occupantshield.com",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"contact_phone",
                                         "value"=>"888-209-2023",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"give_back_partner",
                                         "value"=>"Get Covered",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"term_of_use",
                                         "value"=>"getcoveredinsurance.com",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"register_account_notice",
                                         "value"=>
                                           "Registering for an account with Occupant Shield will allow you to make updates to your account",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"fee_notice_delete",
                                         "value"=>
                                           "**There is an annual administrative fee of <b>$35</b> charged by Cambridge Insurance-Occupant Shield to recover the reasonable costs for administrative services provided to your        landlord that are not associated with the sale, solicitation, negotiation and servicing of this policy, including, but not limited to, upkeep of all mandated properties’ compliance,        training and record keeping, tracking and monitoring, as well as risk management and other services not related to the premium or commission received. (this amount is included        in quote above; please note the admin fee is not part of premium cost and will show as a separate charge)",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"fee_notice",
                                         "value"=>
                                           "**NOTE: There is an annual administrative fee of <b>${fee}</b> (this amount is included in quote above; please note            the admin fee is not part of premium cost and will show as a separate payment) charged by Cambridge Insurance - Occupant            Shield to recover the reasonable costs for administrative services provided to your landlord that are not associated            with the sale, solicitation, negotiation and servicing of this policy, including, but not limited to, upkeep of all            mandated properties’ compliance, training and record keeping, tracking and monitoring, as well as risk management and            other services not related to the premium or commission received.",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"show_back_button",
                                         "value"=>"true",
                                         "attribute_type"=>"boolean",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"background_right_logo",
                                         "value"=>
                                           "https://gc-public-dev.s3-us-west-2.amazonaws.com/uploads/commercial-right.svg",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"to_delete",
                                         "value"=>"",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"to_delete2",
                                         "value"=>"",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id},
                                        {"name"=>"social_links",
                                         "value"=>
                                           "[{\"type\": \"facebook\",\"url\": \"https://www.facebook.com/occupantshield/\"}, {\"type\": \"twitter\", \"url\": \"https://twitter.com/occupantshield\" }, { \"type\": \"pinterest\", \"url\": \"https://www.pinterest.com/OccupantShield/\" }]",
                                         "attribute_type"=>"text",
                                         "branding_profile_id"=>branding_profile.id}]

  BrandingProfileAttribute.create(branding_profile_attributes_params)
  pages_attributes = [{"content"=>
                         "<div>  <h2>Contact Us</h2>  <p>We Are Here to Help</p>  <div>    <p>We are open Mon-Fri 8 to 4 CST</p>    <p>100 Pearl Street</p>    <p>14th Floor</p>    <p>Hartford, CT 06103</p>  </div>  <p>Give us a call – <a href=\"tel:8882092023\">888-209-2023</a></p>  <p>Send us an – email <a href=\"mailto:customercare@occupantshield.com\">customercare@occupantshield.com</a></p>\n" +
                           "</div>",
                       "title"=>"contact_us",
                       "agency_id"=>agency.id,
                       "branding_profile_id"=>branding_profile.id,
                       "styles"=>nil},
                      {"content"=>
                         "<h2>About Us</h2>  <div>    <p>Cambridge Insurance is a strategic insurance leader providing core solutions that enhance liability protection on behalf of both the owner operator as well as the resident.</p>    <p>Our talented team of professionals has over 30 years’ experience in providing risk mitigation programs to owners.</p>    <p>Our goal assisting owner operators in risk mitigation is twofold: we provide the Occupant Shield policy which is one of the most robust renters insurance policies available.  Our property specific platform serves as the platform that monitors and tracks insurance.</p>    <p>We know that renters insurance is a great idea for both owner operators and residents alike; however, not all renters insurance are created equal.</p>    <p>With Occupant Shield, you will enjoy benefits and protections that make acquiring and keeping a rental policy convenient and affordable for residents, while providing protection and customer service that make mandating renters insurance a breeze for your staff.</p>    <p>We provide all the tools required to make mandating renters insurance a success.</p>      <p>This includes hands on training and full assistance implementing our program.</p>    <p>We also provide one on one account management support catered to incorporate Occupant Shield into your current lease process.</p>    <p>Further, we also provide assistance getting your claims paid quickly.</p>  </div>",
                       "title"=>"about_us",
                       "agency_id"=>agency.id,
                       "branding_profile_id"=>branding_profile.id,
                       "styles"=>nil}]

  Page.create(pages_attributes)
end


