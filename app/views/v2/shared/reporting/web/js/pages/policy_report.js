
class PolicyReportPage extends ReportPage {
  constructor(app, urlToken, stateParams, reportId, reportShowEndpoint, reportIndexEndpoint, reportLatestEndpoint) {
    super(app, urlToken, stateParams);
    this.reportShowEndpoint = "/v2/reporting/latest/policy-report";
    this.reportIndexEndpoint = "/v2/reporting/policy-reports";
    this.reportLatestEndpoint = "/v2/reporting/latest/policy-report";
  }
}
