
class CoverageReportPage extends ReportPage {
  constructor(app, urlToken, stateParams, reportId, reportShowEndpoint, reportIndexEndpoint, reportLatestEndpoint) {
    super(app, urlToken, stateParams);
    this.reportShowEndpoint = "/v2/reporting/coverage-reports/:report_id/show";
    this.reportIndexEndpoint = "/v2/reporting/coverage-reports";
    this.reportLatestEndpoint = "/v2/reporting/latest/coverage-report";
  }
}
