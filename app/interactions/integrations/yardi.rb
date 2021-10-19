module Integrations
  class Yardi < ActiveInteraction::Base
    def execute
      response = request
      ap response.env.url
      print response.body
    end

    private

    def request
      faraday_connection.post do |req|
        req.url '/8223tp7s7dev/webservices/itfCommonData.asmx'
        req.headers['Content-Type'] = 'text/xml;charset=utf-8'
        req.headers['Host'] = 'www.yardipcv.com'
        req.headers['SOAPAction'] = "\"http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentData/GetPropertyList\""
        req.headers['Content-Length'] = template_property_list.length.to_s
        req.headers.each{ |k,v| print "#{k}: #{v}\n" }
        req.body = template_property_list
      end
    end

    def template_property_list
      <<~XML
        <?xml version="1.0" encoding="utf-8"?>
        <soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                       xmlns:xsd="http://www.w3.org/2001/XMLSchema"
                       xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
          <soap:Body>
            <GetPropertyList xmlns="http://tempuri.org/YSI.Interfaces.WebServices/ItfResidentData">
              <UserName>getcoveredws</UserName>
              <Password>101912</Password>
              <ServerName>afqoml_itf70dev7</ServerName>
              <Database>afqoml_itf70dev7</Database>
              <Platform>SQL Server</Platform>
              <InterfaceEntity>Get Covered Billing</InterfaceEntity>
              <InterfaceLicense>MIIBEAYJKwYBBAGCN1gDoIIBATCB/gYKKwYBBAGCN1gDAaCB7zCB7AIDAgABAgJoAQICAIAEAAQQO9ulf+P3+1yvVzCb5kK7pgSByB9BthgUfl71yjQ2wT0+XnPDBxRDP3LkkrVsU2yzxtZfVOWBhMwZGU2VxAtQQJDxiykZwPUMUlx9p9tA6QR8dTXqr+yHovmYYWOcmURgwK2GhyqQ8lp+mCTmyKtmpnK7XvX6lFw9FjCeZDZNL4bYuUhxvV0F+M0uS7OBwx/6qz98XLivXqtdsrXJJHDvO7XDVfkWbCrp4qSxAYyr3Yo84z58+aRCzdAOl6fCmBEGHG1iPD7mtVlhLOcdNLaeGevXJrBGrFW7s8KP</InterfaceLicense>
              <YardiPropertyId>getcov00</YardiPropertyId>
            </GetPropertyList>
          </soap:Body>
        </soap:Envelope>
      XML
    end

    def faraday_connection
      Faraday.new(:url => "https://www.yardipcv.com/8223tp7s7dev/webservices/itfresidentdata.asmx?WSDL") do |faraday|
        faraday.adapter  Faraday.default_adapter
      end
    end
  end
end
