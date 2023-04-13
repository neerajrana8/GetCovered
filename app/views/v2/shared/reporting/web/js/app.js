//////////////////////////// polyfill //////////////////////////////////
function fromEntries(entries){
  var toReturn = {};
  for(var i = 0; i < entries.length; ++i)
    toReturn[entries[i][0]] = entries[i][1];
  return(toReturn);
}
if(!Object.fromEntries)
  Object.fromEntries = fromEntries;
  
  
//////////////////////////// utilities /////////////////////////////////

// might as well obfuscate the localStorage so a simple automatic script can't pull the keys
// NOTE: passes nullish, boolean, and numeric values through unchanged!
function obfuscateString(str) {
  return(("" + str).split("").map((c) => String.fromCharCode((c.charCodeAt() * 23) & 127)).join(""));
}
function deobfuscateString(str) {
  return(("" + str).split("").map((c) => String.fromCharCode((c.charCodeAt() * 39) & 127)).join(""));
}


// convenient for launching code asynchronously (e.g. `procrastinate().then((whatever) => { do_something(); })`)
function procrastinate(value = undefined) {
  return(new Promise((resolve, reject) => resolve(value)));
}





//////////////////////////////// App ///////////////////////////////////



// the app itself
class App {
  static userFields() { // fields besides id to store from the user upon login (WARNING: saved to localStorage)
    return(["email", "profile.first_name", "profile.last_name", "organizable_id", "organizable_type"]);
  }

  constructor(apiUrl) {
    App.current = this;
    this.apiUrl = apiUrl;
    // stuff for authentication
    this.user = null;
    this.authHeaders = {};
    this.extractAuthHeaders = procrastinate();
    this.organizable = {}; //{ organizable_type: "Account", organizable_id: 32 };
    // important divs
    this.yggdrasil = document.getElementById("yggdrasil");
    if(!this.yggdrasil) {
      this.yggdrasil = document.createElement("div");
      this.yggdrasil.setAttribute('class', 'yggdrasil');
      this.yggdrasil.innerHTML = '' +
      '<div class="app-main-div">' +
      '  <div class="app-navbar-div"></div>' +
      '  <div class="app-page-container-div">' +
      '    <div class="app-header-div">' +
      '      <div class="app-breadcrumbs-div"></div>' +
      '      <div class="app-page-header-div"></div>' +
      '    </div>' +
      '    <div class="app-page-body-div"></div>' +
      '  </div>' +
      '</div>' +
      '<div class="app-dialog-div">' +
      '  <div class="app-dialog-login-div"></div>' +
      '</div>';
    }
    this.mainDiv =        this.yggdrasil.querySelector(".app-main-div");
    this.navbarDiv =        this.yggdrasil.querySelector(".app-navbar-div");
    this.headerDiv =        this.yggdrasil.querySelector(".app-header-div");
    this.breadcrumbsDiv =     this.yggdrasil.querySelector(".app-breadcrumbs-div");
    this.pageHeaderDiv =      this.yggdrasil.querySelector(".app-page-header-div");
    this.pageBodyDiv =      this.yggdrasil.querySelector(".app-page-body-div");
    this.dialogDiv =      this.yggdrasil.querySelector(".app-dialog-div");
    this.dialogLoginDiv =   this.dialogDiv.querySelector(".app-dialog-login-div");
    // useful components
    this.navbar = new Navbar(this, this.navbarDiv);
    this.loginDialog = new LoginDialog(this, this.dialogLoginDiv);
    this.dialogRegistry = { "root.login": this.loginDialog };
    this.dialogStack = [];
    // page state
    this.pages = [new HomePage(this)];
    this.activePage = null;
    // load from disk and url
    let baseUrl = window.location.href.split("/");
    baseUrl = baseUrl[baseUrl.length-1];
    baseUrl = baseUrl.split("?");
    baseUrl = baseUrl[baseUrl.length-1];
    this.loadSavedSession().then((whatever) => {
      this.goTo(
        baseUrl.startsWith("p=") ? decodeURIComponent(baseUrl.split("p=")[1]) : "/",
        false // false = replace state rather than pushing state
      );
    });
  }
  
  get currentDialog() {
    return(this.dialogStack[this.dialogStack.length - 1]);
  }
  
  hasDialog(name) {
    return(this.dialogRegistry.hasOwnProperty(name));
  }
  
  getDialog(name) {
    return(this.dialogRegistry[name]);
  }
  
  registerDialog(name, dialog) {
    if(this.hasDialog(name))
      return(null);
    this.dialogRegistry[name] = dialog;
    return(dialog);
  }
  
  // only used in constructor, but would've been ugly there
  loadSavedSession() {
    return(new Promise((resolve, reject) => {
      let userId = deobfuscateString(window.localStorage.getItem("gcrs_auth_ui"));
      if(!userId || userId == deobfuscateString("null"))
        return(resolve(false));
      else {
        this.authHeaders = {
          'access-token': deobfuscateString(window.localStorage.getItem("gcrs_auth_at")),
          'client': deobfuscateString(window.localStorage.getItem("gcrs_auth_c")),
          'expiry': deobfuscateString(window.localStorage.getItem("gcrs_auth_e")),
          'token-type': deobfuscateString(window.localStorage.getItem("gcrs_auth_tt")),
          'uid': deobfuscateString(window.localStorage.getItem("gcrs_auth_u"))
        };
        this.extractAuthHeaders = procrastinate();
        // verify that the stored headers actually work
        this.fetch('/v2/reporting/verify-login', {
          method: 'GET'
        }).catch((error) => {
          return({ status: 401 });
        }).then((response) => {
          if(response.status == 200) {
            this.user = { id: userId };
            for(let field of App.userFields()) {
              let splat = field.split(".");
              let temp = this.user;
              for(let i = 0; i < splat.length - 1; ++i)
                temp = (temp[splat[i]] ||= {});
              temp[splat[splat.length-1]] = deobfuscateString(window.localStorage.getItem("gcrs_auth_u_" + obfuscateString(field)));
            }
            this.userHasAdminAuthority = (this.user && this.user.id && this.user['organizable_type'] == "Agency" && this.user['organizable_id'] == 1);
            this.userIsAdmin = (this.user && this.user.id && this.user.hasAdminAuthority && this.organizable.hasOwnProperty('organizable_type') == false);
            this.navbar.refresh();
            if(this.activePage)
              this.activePage.refresh();
            return(resolve(true)); // just wanna return to ensure execution stops
          }
          else
            return(reject());
        });
      }
    }));
  }
  
  
  setUser(user) {
    this.user = user;
    if(this.user && this.user.id)
      window.localStorage.setItem("gcrs_auth_ui", obfuscateString(this.user.id));
    else
      window.localStorage.removeItem("gcrs_auth_ui");
    for(let field of App.userFields()) {
      let splat = field.split(".");
      let temp = (this.user || {});
      for(let i = 0; i < splat.length - 1; ++i)
        temp = (temp[splat[i]] || {});
      if(this.user && this.user.id)
        window.localStorage.setItem("gcrs_auth_u_" + obfuscateString(field), obfuscateString(temp[splat[splat.length-1]]));
      else
        window.localStorage.removeItem("gcrs_auth_u_" + obfuscateString(field));
    }
    this.userHasAdminAuthority = (this.user && this.user.id && this.user['organizable_type'] == "Agency" && this.user['organizable_id'] == 1);
    this.userIsAdmin = (this.user && this.user.id && this.user.hasAdminAuthority && this.organizable.hasOwnProperty('organizable_type') == false);
    this.navbar.refresh();
    if(this.activePage)
      this.activePage.refresh();
  }
  
  encode(strang) {
    return(encodeURIComponent(strang));
  }
  
  decode(strang) {
    return(decodeURIComponent(strang));
  }
  
  goToParams(url, params, backable = true) {
    return(this.goTo(url + "?" + this.encode(params), backable));
  }
  
  
  // takes a url like "/coverage-reports?parent_id=3/omg-second-page/?whaaat=yup"; no "/" = relative to current
  goTo(url, backable = true) {
    console.log("GOTO: ", url);
    // handle special cases
    if(url.length == 0)
      url = "/";
    if(url.charAt(0) == "/") {
      // turn absolute path into relative path; we'll skip pieces of it if we have them already
      let cururl = this.generateUrl(true).split("/");
      let newurl = url.split("/");
      let minlength = (cururl.length < newurl.length ? cururl.length : newurl.length);
      let firstDifferent = 1;
      for(let i = 1; i < minlength; ++i) {
        if(cururl[i] == newurl[i])
          ++firstDifferent;
        else
          break;
      } 
      if(firstDifferent == 1) {
        // they are utterly different, so just start over
        url = url.slice(1); // remove leading "/"
        this.pages = [new HomePage(this)];
      }
      else {
        // they share a common start, so tell ourselves to go back to it
        url = newurl.slice(firstDifferent).join("/");
        for(let i = cururl.length; i > firstDifferent; --i) {
          url = "../" + url;
        }
      }
    }
    else if(url.startsWith("http://") || url.startsWith("https://")) {
      // straight-up go to some site
      window.open(url);
      return(procrastinate());
    }
    // grab for capture
    this.pages = this.pages.map((p) => p); // refresh array so it isn't the same object as in previous goTo requests
    let pageArray = this.pages;
    let activePageIndex = pageArray.findIndex((p) => (p == this.activePage));
    if(activePageIndex == -1)
      activePageIndex = pageArray.length - 1;
    let navigationPromise = procrastinate();
    // relative path handling
    // set up entire page sequence
    for(let token of url.split("/")) {
      let splatToken = token.split("?");
      if(splatToken[0] == ".") {
        if(splatToken.length == 1 || splatToken[1].length == 0)
          ; // do nothing
        else
          navigationPromise = navigationPromise.then((whatever) => { if(activePageIndex != -1) pageArray[activePageIndex].resolveParams(this.decode(splatToken[1])); return("nevermind"); });
      }
      else if(splatToken[0] == "..") {
        navigationPromise = navigationPromise.then((whatever) => {
          if(activePageIndex < 1)
            return("nevermind");
          activePageIndex -= 1;
          if(splatToken.length > 1 && splatToken[1].length > 0)
            pageArray[activePageIndex].resolveParams(this.decode(splatToken[1]));
        });
      }
      else if(splatToken[0] == "...") {
        navigationPromise = navigationPromise.then((whatever) => {
          if(activePageIndex == -1 || (activePageIndex + 1 >= pageArray.length))
            return("nevermind");
          activePageIndex += 1;
          if(splatToken.length > 1 && splatToken[1].length > 0)
            pageArray[activePageIndex].resolveParams(this.decode(splatToken[1]));
          return("nevermind");
        });
      }
      else {
        navigationPromise = navigationPromise.then((whatever) => {
          return(pageArray[activePageIndex].resolve(splatToken[0], this.decode(splatToken[1])));
        }).catch((resolutionError) => {
          // rethrow after resolution errors, unless it's a login required, in which case give them a chance to log in first
          switch(resolutionError.message) {
            case("login_required"):
              if(this.pages == pageArray) { // only if we're actually still trying to load this
                return(
                  this.loginViaGui().then((whatever) => {
                    return((pageArray[activePageIndex] || new HomePage(this)).resolve(splatToken[0], this.decode(splatToken[1])));
                  }).catch((whatever) => {
                    throw new Error("Access Denied");
                  })
                );
              }
              throw new Error("Access Denied");
            case("unauthorized_user"):
              throw new Error("Access Denied");
          }
          console.log("RESOLUTION ERROR: ", resolutionError);
          throw new Error("Internal Routing Error");
        }).then((childPage) => {
          // if resolution succeeded (possibly after login), add the page to the pages array
          if(!childPage) { // null means go back
            if(activePageIndex > 1)
              activePageIndex -= 1;
            return("nevermind");
          }
          if(childPage == pageArray[activePageIndex])
            return("nevermind");
          //if(splatToken[0] != "" && splatToken[0] != "." && splatToken[0] != "..")
          //  childPage.learnOfBirth(token[0], token[1]);
          //return(childPage.prepareBreadcrumbTitle().then((whatever) => {
          //  pageArray.push(childPage);
          //}));
          while(pageArray.length - 1 > activePageIndex)
            pageArray.pop();
          pageArray.push(childPage);
          activePageIndex += 1;
          return("nevermind");
        });
      }
    }
    // activate the new active page
    navigationPromise = navigationPromise.then((whatever) => {
      if(this.pages == pageArray) { // only if the user hasn't superseded the routing request with another one
        this.activatePage(pageArray[activePageIndex]);
        return(true);
      }
      return(false);
    }).catch((error) => {
      if(this.pages == pageArray) {
        console.log("Navigation error: ", error);
        this.pages = [new HomePage(this), new LostPage(this, 'lost')];
        this.activatePage(this.pages[this.pages.length-1]);
        return(true);
      }
      return(false);
    });;
    // change url and log state
    navigationPromise = navigationPromise.then((shouldLogState) => {
      if(shouldLogState) {
        let newUrl = this.generateUrl();
        if(backable) // backable is true, push state
          window.history.pushState({ p: newUrl }, "", "index.html?p=" + encodeURIComponent(newUrl));
        else if(backable == null)
          ; // do nothing, this is a back button press response
        else // backable is false, replace state
          window.history.replaceState({ p: newUrl }, "", "index.html?p=" + encodeURIComponent(newUrl));
      }
    });
    // done
    return(navigationPromise);
  }
  
  // generates a URL to save the current state
  // NOTE: due to this being a single-file page, we have to do index.html?p=${encodeURIComponent(generateUrl())} to get a real url for the browser
  generateUrl() {
    let activePageIndex = this.pages.indexOf(this.activePage);
    if(activePageIndex == -1)
      activePageIndex = this.pages[this.pages.length-1];
    let toReturn = this.pages.map((p) => {
      let stateParams = p.getStateParams();
      if(!stateParams || Object.entries(stateParams).length == 0)
        return(p.getUrlToken());
      return(p.getUrlToken() + "?" + this.encode(p.getStateParams()));
    }).join("/");
    for(let i = this.pages.length-1; i > activePageIndex; --i)
      toReturn += "/..";
    return(toReturn);
  }
  
  // control app visibility
  show() {
    if(!this.yggdrasil.parentNode)
      document.body.appendChild(this.yggdrasil);
    App.current = this;
    window.onpopstate = ((evt) => {
      console.log("BACK! ", event.state);
      if(event.state && event.state['p']) {
        this.goTo(event.state['p'], null);
      }
    });
  }
  
  hide() {
    if(this.yggdrasil.parentNode)
      this.yggdrasil.parentNode.removeChild(this.yggdrasil);
    if(App.current == this)
      App.current = null;
  }
  
  activatePage(page) {
    if(this.activePage != page) { // no need for activation logic if the page is already active
      // switch activation to new page
      if(this.activePage) {
        this.activePage.deactivate();
        this.activePage = null;
      }
      this.breadcrumbsDiv.innerHTML = "";
      this.pageHeaderDiv.innerHTML = "";
      this.pageBodyDiv.innerHTML = "";
      this.activePage = page;
      this.activePage.activate();
      // insert page dom nodes
      let header = this.activePage.getHeaderNode();
      this.pageHeaderDiv.appendChild(header);
      let body = this.activePage.getBodyNode();
      this.pageBodyDiv.appendChild(body);
      this.refreshBreadcrumbs(null);
    }
  }
  
  refreshState(callingPage) {
    if(callingPage && !this.pages.includes(callingPage))
      return(false);    
    let newUrl = this.generateUrl();
    window.history.replaceState({ p: newUrl }, "", "index.html?p=" + encodeURIComponent(newUrl));
  }
  
  refreshBreadcrumbs(callingPage) {
    if(callingPage && !this.pages.includes(callingPage))
      return(false);
    let activePageIndex = this.pages.indexOf(this.activePage);
    if(activePageIndex == -1)
      return(false);
    this.breadcrumbsDiv.innerHTML = "";
    for(let i = 0; i < this.pages.length; ++i) {
      if(i != 0) {
        let separator = document.createTextNode('\u21D2');
        this.breadcrumbsDiv.appendChild(separator);
      }
      let crumb = document.createElement("a");
      if(i == activePageIndex)
        crumb.classList.add("selected");
      crumb.appendChild(document.createTextNode(crumb.title = this.pages[i].getBreadcrumbTitle()));
      let href = "javascript:App.current.goTo('";
      if(i <= activePageIndex)
        for(let j = i; j < activePageIndex; ++j)
          href += "../";
      else
        for(let j = activePageIndex; j < i; ++j)
          href += ".../";
      href += ".');";
      crumb.href = href;
      this.breadcrumbsDiv.appendChild(crumb);
    }
  }
  
  // user management
  loginViaGui() {
    return(new Promise((resolve, reject) => {
      this.loginDialog.open((resultingUser) => {
        if(resultingUser)
          resolve(resultingUser);
        else
          reject(null);
      });
    }));
  }
  
  login(userEmail, userPassword) {
    return(
      this.fetch('/v2/staff/auth/sign_in', {
        method: 'POST',
        body: JSON.stringify(Object.assign({}, {
          email: userEmail,
          password: userPassword
        }
        ))//, this.organizable))
      }).catch((error) => {
        throw new Error("Error communicating with server.");
      }).then((response) => {
        if(response.status == 200) {
          return(response.json().then((val) => {
            this.setUser(val);
            return(this.user);
          }));
        }
        else if(response.status == 401) {
          throw new Error("Incorrect username or password; please try again.");
        }
        else {
          throw new Error("Server error.");
        }
        return(response);
      })
    );
  }
  
  logout() {
    return(this.fetch('/v2/staff/auth/sign_out', { method: "DELETE" }).then(whatever => {
      this.setUser(null);
    }).catch(whatever => {
      this.setUser(null);
    }));
  }
  
  // api interaction
  
  // ensures requests run one-at-a-time and that auth headers are kept updated
  fetch(endpoint, options) {
    if(!this.apiUrl.startsWith("https://"))
      throw new Error("API must be accessed via https."); // just in case, to prevent flinging sensitive data around the internet accidentally
    // get promise for making the request; it is dependent on the prior request completing & having its auth headers extracted
    let makeRequest = this.extractAuthHeaders.then(
      (whatever) => {
        options = Object.assign({}, options, { headers: Object.assign({
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }, options.headers || {}, this.authHeaders, this.organizable || {})});
        return(fetch(this.apiUrl + endpoint, options));
      }
    );
    // update extractAuthHeaders so it's a promise to extract from the just-made request
    this.extractAuthHeaders = makeRequest.then(
      (response) => {
        this.authHeaders = {
          "access-token": response.headers.get("access-token") || this.authHeaders["access-token"],
          "client": response.headers.get("client") || this.authHeaders["client"],
          "expiry": response.headers.get("expiry") || this.authHeaders["expiry"],
          "token-type": response.headers.get("token-type") || this.authHeaders["token-type"],
          "uid": response.headers.get("uid") || this.authHeaders["uid"]
        };
        window.localStorage.setItem("gcrs_auth_at", obfuscateString(this.authHeaders["access-token"]));
        window.localStorage.setItem("gcrs_auth_c", obfuscateString(this.authHeaders["client"]));
        window.localStorage.setItem("gcrs_auth_e", obfuscateString(this.authHeaders["expiry"]));
        window.localStorage.setItem("gcrs_auth_tt", obfuscateString(this.authHeaders["token-type"]));
        window.localStorage.setItem("gcrs_auth_u", obfuscateString(this.authHeaders["uid"]));
        return(response);
      }
    ).catch((error) => { console.log("App.current.fetch error at endpoint " + endpoint + ":", error); });
    // return the promise to make the request
    return(makeRequest);
  }


  encode(obj) {
    return(this.subEncode(obj).map((enc) => {
      let compressed = [];
      let wasNull = false;
      for(let i = 0; i < enc.length - 1; ++i) {
        if(enc[i] == null) { // or undefined, but w/e
          wasNull = true;
        }
        else if(wasNull) {
          wasNull = false;
          compressed[compressed.length-1] = compressed[compressed.length-1] + "[" + enc[i] + "]";
        }
        else {
          compressed.push(enc[i]);
        }
      }
      return(compressed.join(".") + "=" + enc[enc.length-1]);
    }).join("&"));
  }
  
  subEncode(obj) {
    let toReturn = [];
    if(Array.isArray(obj)) {
      if(obj.length == 0)
        return("_(A)");
      for(let i = 0; i < obj.length; ++i) {
        this.subEncode(obj[i]).forEach((enc) => {
          toReturn.push([null, i].concat(enc));
        });
      }
    }
    else if(typeof obj === 'object' && obj != null) {
      let entries = Object.entries(obj);
      if(entries.length == 0)
        return("_(O)"); // representing an empty object
      entries.forEach((entry) => {
        this.subEncode(entry[1]).forEach((enc) => {
          toReturn.push([encodeURIComponent(entry[0]).replace('.', '%2E')].concat(enc));
        });
      });
    }
    else {
      return([this.encodeValue(obj)]);
    }
    return(toReturn);
  }
  
  encodeValue(val) {
    if(val === null)
      return("_(N)");
    else if(typeof val === 'number')
      return("_(+" + val + ")");
    else if(val === true)
      return("_(T)");
    else if(val === false)
      return("_(F)");
    return(encodeURIComponent("" + val).replace('.', '%2E'));
  }
  
  decode(str) {
    if(str == null)
      return(undefined);
    let toReturn = {};
    str.split("&").map((x) => x.split("=")).forEach((v) => {
      let steps = v[0].split(".");
      // drill down as necessary
      let base = toReturn;
      for(let i = 0; i < steps.length; ++i) {
        if(steps[i].endsWith("]")) {
          // support nested array syntax
          let splat = steps[i].split(/[\[\]]+/); // whatever[3][2] is now ['whatever', '3', '2']
          let comp = decodeURIComponent(splat[0].replace('%2E', '.'));
          if(!base.hasOwnProperty(comp))
            base[comp] = [];
          let arrayBase = base[splat[0]];
          for(let j = 1; j < splat.length - 1; ++j) {
            if(typeof arrayBase[+splat[j]] === 'undefined')
              arrayBase = (arrayBase[+splat[j]] = []);
            else
              arrayBase = arrayBase[+splat[j]];
          }
          if(i == steps.length - 1)
            arrayBase[+splat[splat.length-1]] = this.decodeValue(v[1]);
          else
            base = (typeof arrayBase[+splat[splat.length-1]] === 'undefined' ? (arrayBase[+splat[splat.length-1]] = {}) : arrayBase[+splat[splat.length-1]]);
        }
        else {
          // support nested object syntax
          let comp = decodeURIComponent(steps[i].replace('%2E', '.'));
          if(i == steps.length - 1)
            base[comp] = this.decodeValue(v[1]);
          else
            base = (base.hasOwnProperty(comp) ? base[comp] : (base[comp] = {}));
        }
      }
    });
    return(toReturn);
  }
  
  decodeValue(val) {
    switch(val) {
      case("_(O)"):  return({});
      case("_(A)"):  return([]);
      case("_(N)"):  return(null);
      case("_(T)"):  return(true);
      case("_(F)"):  return(false);
    }
    if(val.startsWith("_(+"))
      return(+val.substring(3,val.length-1));
    return(decodeURIComponent(val.replace('%2E', '.')));
  }
  

}







/////////////////////////// LoginDialog ////////////////////////////////



class LoginDialog extends Dialog {

  constructor(app, containingDiv) {
    super(app, containingDiv);
    this.domNode.innerHTML = `
      <div style="text-align:right;"><button onclick="App.current.loginDialog.close()">X</button></div>
      <div class="logindialogerror"></div>
      <form action="none">
        <label>Email</label>
        <input type="text" name="email" class="logindialogemail" autofocus />
        <br />
        <label>Password</label>
        <input type="password" name="password" class="logindialogpassword" />
        <br />
        <button type="button" onclick="App.current.loginDialog.attemptLogin()">Log In</button>
      </form>
    `;
  }
  
  // will call callback(user) when successful or exited
  prepareToOpen() {
    this.domNode.querySelector(".logindialogerror").innerHTML = "";
  }
  
  prepareToClose() {
  }
  
  fail(msg = null) {
    this.domNode.querySelector(".logindialogerror").textContent = (msg ||"Incorrect email or password.");
    this.domNode.querySelector(".logindialogpassword").value = "";
  }
  
  attemptLogin() {
    let userEmail = this.domNode.querySelector(".logindialogemail").value;
    let userPassword = this.domNode.querySelector(".logindialogpassword").value;
    return(this.app.login(userEmail, userPassword).then(
      (newUser) => {
        let oldCallbacks = this.callbacks;
        this.callbacks = [];
        oldCallbacks.forEach((callback) => callback(newUser));
        this.close();
      },
      (error) => {
        this.fail(error);
      }
    ));
  }
  
}










