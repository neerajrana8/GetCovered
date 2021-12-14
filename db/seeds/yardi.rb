require './db/seeds/functions'
require 'faker'
require 'socket'


@account = Account.all.first


=begin

Integration.create!(
  integratable: @account,
  provider: 'yardi',
  enabled: true,
  credentials: {
    'voyager' => {
      'username' => 'getcovereddb',
      'password' => '101912',
      'database_server' => 'afqoml_itf70dev7',
      'database_name' => 'afqoml_itf70dev7'
    },
    'billing' => {
      'username' => 'getcoveredws',
      'password' => '101912',
      'database_server' => 'afqoml_itf70dev7',
      'database_name' => 'afqoml_itf70dev7'
    },
    'urls' => {
      'billing_and_payments' => 'https://www.yardipcv.com/8223tp7s7dev/Webservices/ItfResidentTransactions20.asmx',
      'renters_insurance' => 'https://www.yardipcv.com/8223tp7s7dev/Webservices/ItfRentersinsurance.asmx',
      'system_batch' => 'https://www.yardipcv.com/8223tp7s7dev/Webservices/ItfResidentTransactions20_SysBatch.asmx',
      'common_data' => 'https://www.yardipcv.com/8223tp7s7dev/webservices/itfCommonData.asmx',
      'resident_data' => 'https://www.yardipcv.com/8223tp7s7dev/webservices/itfresidentdata.asmx'
    }
  }
)

=end

Integration.create!(
  integratable: @account,
  provider: 'yardi',
  enabled: true,
  credentials: {
    'voyager' => {
      'username' => 'getcoveredqa',
      'password' => '101915',
      'database_server' => 'afqoml_itf_70QA',
      'database_name' => 'afqoml_itf_70QA'
    },
    'billing' => {
      'username' => 'getcoveredqa',
      'password' => '101915',
      'database_server' => 'afqoml_itf_70QA',
      'database_name' => 'afqoml_itf_70QA'
    },
    'urls' => {
      'billing_and_payments' => 'https://www.yardipcv.com/8223tp7s7qa/Webservices/ItfResidentTransactions20.asmx',
      'renters_insurance' => 'https://www.yardipcv.com/8223tp7s7qa/Webservices/ItfRentersinsurance.asmx',
      'system_batch' => 'https://www.yardipcv.com/8223tp7s7qa/Webservices/ItfResidentTransactions20_SysBatch.asmx'
    }
  }
)


