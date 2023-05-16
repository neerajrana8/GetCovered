
class ReportPage extends Page {
  constructor(app, urlToken, stateParams, reportId, reportShowEndpoint, reportIndexEndpoint, reportLatestEndpoint) {
    super(app, urlToken, stateParams);
    // report id and endpoints
    this.reportId = reportId;
    this.reportShowEndpoint = reportShowEndpoint; // use ":report_id" to replace with id
    this.reportIndexEndpoint = reportIndexEndpoint;
    this.reportLatestEndpoint = reportLatestEndpoint;
    // other stuff
    this.breadcrumbTitle = "Report";
    this.isReady = null; // null means not initialized yet, false means working but waiting for something, true means all good
    this.manifest = null;
    this.forcedRoot = null; // set to a subreport in your derived class's constructor to force it to be report root
    this.subreport = null;
    this.reportViewParams = null;
    this.stateParams ||= {};
    this.reportId ||= this.stateParams['rid'];
    this.stateParams['rid'] ||= this.reportId;
    this.reportViewParams = this.stateParams['rv'] ? JSON.parse(decodeURIComponent(this.stateParams['rv'])) : {};
    if(this.stateParams['sr']) {
      this.reportViewParams['sr'] = this.stateParams['sr'];
      delete this.stateParams['sr'];
    }
    if(this.reportViewParams['sr']) {
      this.subreport = this.reportViewParams['sr']; // set to string for now, .initialize() will make it into an object
    }
    if(this.stateParams['fr']) {
      this.forcedRoot = decodeURIComponent(this.stateParams['fr']);
    }
    // this wasn't designed to run until the page is activated, but it's the easiest way to refresh the breadcrumb title
    procrastinate().then(() => { this.isActivated(); }); // procrastinate so that parent constructor can run first
  }
  
  initialize(manifest, subreport = null) {
    this.isReady = false;
    // core setup
    this.manifest = manifest;
    if(this.forcedRoot)
      this.manifest['root_subreport'] = this.forcedRoot;
    this.subreport = ( subreport || this.subreport || (this.manifest['subreports'].find((x) => (x["title"] == this.manifest["root_subreport"]))) );
    if(typeof this.subreport === 'string' || this.subreport instanceof String)
      this.subreport = this.manifest['subreports'].find((x) => (x["title"] == this.subreport));
    this.breadcrumbTitle = (this.subreport['title'] == this.manifest['root_subreport'] && this.manifest['title'] != this.subreport['title']) ? (this.manifest['title'] + ": " + this.subreport['title']) : this.subreport['title']; // WARNING: not perfect, in case some report eventually reuses the root subrep type as a child... but good enough for now
    this.app.refreshBreadcrumbs(this);
    this.reportView = new ReportView(this.app, this, this.manifest, this.subreport);
    // body display
    this.bodyNode.appendChild(this.reportView.domNode);
    // header display
    this.headerWrapper = document.createElement('div');
      this.headerWrapper.classList.add('page-report-header');
      this.headerNode.appendChild(this.headerWrapper);
    this.headerLeft = document.createElement('div');
      this.headerLeft.classList.add('page-report-header-left');
      this.headerLeft.innerHTML = '<h1>' + this.subreport['title'] + '</h1>';
      this.headerWrapper.appendChild(this.headerLeft);
    this.navnode = document.createElement('div');
      this.navnode.classList.add('page-report-navopts');
      this.headerWrapper.appendChild(this.navnode);
    // get data
    return(Object.entries(this.reportViewParams).length > 1 ? this.reportView.initializeFromHash(this.reportViewParams) : this.reportView.refreshFromServer());
  }
  
  refreshChildState(child, state) {
    if(child == this.reportView) {
      this.stateParams['rv'] = encodeURIComponent(JSON.stringify(state));
      this.app.refreshState();
    }
  }
  
  receiveNavigationOptions(origin, navopts) {
    if(origin != this.reportView)
      return;
    this.navnode.innerHTML = '';
    for(let opt of navopts) {
      if(opt['enabled'] != null) {
        let button = document.createElement('button');
        button.textContent = opt['title'];
        if(!opt['enabled'])
          button.disabled = true;
        if(opt['tooltip'] && opt['tooltip'].length > 0)
          button.title = opt['tooltip'];
        button.onclick = (() => {
          this.navigationOptionClicked(opt['title'], opt['params']);
        });
        this.navnode.appendChild(button);
        this.navnode.appendChild(document.createElement('br'));
      }
    }
  }
  
  navigationOptionClicked(option, params) {
    let navigationParams = this.reportView.getNavigationParams(option, params);
    if(!navigationParams)
      return(null);
    this.app.goTo('sub?rid=' + this.reportId + '&rv=' + encodeURIComponent(JSON.stringify(navigationParams)));
  }

  //////////////////////// superclass overrides ///////////////////////
  
  getBreadcrumbTitle() {
    return(this.breadcrumbTitle);
  }
  
  // called when the logged-in user has changed etc.
  refresh() {
    if(!this.app.user) {
      this.app.goTo("/");
      return;
    }
    if(this.isReady) {
      // do anything?
    }
  }
  
  // headerNode and bodyNode are about to become visible
  isActivated() {
    if(this.isReady == null) { // null means not initialized, false means initialized but waiting for something, true means all good
      this.isReady = false;
      if(this.stateParams.hasOwnProperty('rid') && this.stateParams['rid']) {
        this.reportId = this.stateParams['rid'];
        // we have been called with parameters specifying which coverage report to use
        this.app.fetch(this.reportShowEndpoint.replace(':report_id', this.reportId), {
          method: "POST",
          body: JSON.stringify(Object.assign({}, this.app.organizable))
        }).then(response => {
          if(Math.floor(response.status / 200) != 1) {
            return(null);
          }
          return(response.json());
        }).then(data => {
          if(!data)
            return(null);
          if(this.stateParams.hasOwnProperty('sr')) {
            return(this.initialize(data['manifest'], this.stateParams['sr']));
          }
          // no subreport has been provided, use the default
          return(this.initialize(data['manifest']));
        });
      }
      else {
        // we have been called with no parameters, default to the latest available coverage report
        this.app.fetch(this.reportLatestEndpoint, {
          method: "POST",
          body: JSON.stringify(this.app.organizable)
        }).then(response => {
          if(Math.floor(response.status / 200) != 1) {
            return(null);
          }
          return(response.json());
        }).then(data => {
          if(!data)
            return(null);
          this.reportId = data['id'];
          this.stateParams['rid'] = data['id'];
          this.app.refreshState();
          return(this.initialize(data['manifest']));
        });
      }
    }
  }
  
  // synchronous
  // headerNode and bodyNode have just become invisible
  isDeactivated() {
  }

  // synchronous or promise
  // return the Page to route to (e.g. "page?x=3&y=5" will appear as .resolve("page", "x=3&y=5")
  //   null means die and go to previous page; this means stay on current page; anything else should be a new page to travel to
  resolve(token, stateParams) {
    if(token == "sub")
      return(new ReportPage(this.app, token, stateParams,
        this.reportId,
        this.reportShowEndpoint,
        this.reportIndexEndpoint,
        this.reportLatestEndpoint
      ));
    return(this);
  }
  
  // synchronous or promise
  // return is irrelevant; we have been given additional params after creation by a routing call to a relative url like ".?z=4" or from a parent via "..?z=4"
  resolveParams(stateParams) {
    return(this);
  }
}
