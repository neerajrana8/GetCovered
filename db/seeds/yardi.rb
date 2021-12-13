require './db/seeds/functions'
require 'faker'
require 'socket'


@account = Account.all.first


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
      'common_data' => 'https://www.yardipcv.com/8223tp7s7dev/webservices/itfCommonData.asmx', # commercial
      'resident_data' => 'https://www.yardipcv.com/8223tp7s7dev/webservices/itfresidentdata.asmx' # residential
    }
  }
)




