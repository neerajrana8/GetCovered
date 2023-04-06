


class Page {
  constructor(app, urlToken = "", stateParams = null) {
    this.app = app;
    this.activated = false;
    this.breadcrumbTitle = null;
    this.headerNode = document.createElement('div');
    this.bodyNode = document.createElement('div');
    this._urlToken = urlToken;
    this.stateParams = stateParams;
  }
  
  //////////////////////// OUGHTTA BE OVERRIDDEN ///////////////////////
  
  
  // synchronous
  // set and return a breadcrumb title string; null, the default here, will produce an error;
  // if you require asynchronous actions before you can generate the title, override
  // prepareBreadcrumbTitle instead
  
  getBreadcrumbTitle() {
    return(this.breadcrumbTitle);
  }
  
  // synchronous
  // called when the logged-in user has changed
  refresh() {
  }
  
  // synchronous
  // headerNode and bodyNode are about to become visible
  isActivated() {
    // do nothing by default
  }

  // synchronous
  // headerNode and bodyNode have just become invisible
  isDeactivated() {
    // do nothing by default
  }

  // synchronous or promise
  // return the Page to route to (e.g. "page?x=3&y=5" will appear as .resolve("page", "x=3&y=5")
  //   null means die and go to previous page; this means stay on current page; anything else should be a new page to travel to
  resolve(token, stateParams) {
    return(this);
  }
  
  // synchronous or promise
  // return is irrelevant; we have been given additional params after creation by a routing call to a relative url like ".?z=4" or from a parent via "..?z=4"
  resolveParams(stateParams) {
    return(this);
  }
  
  /////////////////////////// FINE AS-AS ///////////////////////////////
  
  getStateParams() {
    return(this.stateParams);
  }
  
  getUrlToken() {
    return(this._urlToken);
  }
  
  activate() {
    if(!this.activated) {
      this.activated = true;
      this.isActivated();
    }
    return(null);
  }
  
  deactivate() {
    if(this.activated) {
      this.activated = false;
      this.isDeactivated();
    }
    return(null);
  }
  
  getHeaderNode() {
    return(this.headerNode);
  }
  
  getBodyNode() {
    return(this.bodyNode);
  }
  
}
