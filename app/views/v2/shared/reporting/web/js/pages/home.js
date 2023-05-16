

class HomePage extends Page {
  constructor(app, urlToken = "", urlParams = null) {
    super(app, urlToken, urlParams);
    this.activated = false;
    this.wasLoggedIn = false;
  }
  
  getBreadcrumbTitle() {
    return("Home");
  }
  
  activate() {
    if(this.activated && (this.wasLoggedIn == (this.app.user ? true : false)))
      return;
    this.activated = true;
    this.headerNode.innerHTML = "<h1>Get Covered Reporting System</h1>";
    this.bodyNode.innerHTML = "<div><p>Welcome to the Get Covered Reporting system.</p>"
    if(!this.app.user) {
      this.wasLoggedIn = false;
      this.bodyNode.innerHTML += "<p>Please log in.</p>";
    }
    else {
      this.wasLoggedIn = true;
      this.bodyNode.innerHTML += "<p>Available report types are listed in the navigation bar to the left. Some reports contain multiple subreports; navigation options will be enabled in the top right when a row is selected by clicking it. The filter icon in table headers can be used to filter the visible rows. The arrow buttons allow you to sort in ascending or descending order; by holding the SHIFT key, you can sort by multiple columns at once.</p></div>";
    }
  }
  
  refresh() {
    this.activate();
  }
  
  onDeactivation() {
    if(!this.activated)
      return;
    this.activated = false;
  }
  
  resolve(token, stateParams) {
    if(token == "coverage-reports") {
      if(!this.app.user)
        throw new Error("login_required");
      return(new CoverageReportPage(this.app, token, stateParams));
    }
    if(token == "policy-reports") {
      if(!this.app.user)
        throw new Error("login_required");
      return(new PolicyReportPage(this.app, token, stateParams));
    }
    return(this);
  }
  
}
