
class Navbar {
  constructor(app, domDiv) {
    this.app = app;
    this.items = [];
    this.domNode = domDiv; // must be div
    this.availableOwners = null;
    this.refresh();
  }
  
  refresh(evenRequests = false) {
    // construct the logo
    let logo = document.createElement("div");
    logo.className = "navbar-logo-container";
    logo.innerHTML = "<img src=\"assets/logo2.png\" class=\"navbar-logo\"></img>";
    // construct the special section
    let specialSection = document.createElement('div');
    if(this.app.userHasAdminAuthority) {
      if(this.availableOwners && !evenRequests) {
        this.prepareBrowseAs(specialSection);
      }
      else {
        this.app.fetch('/v2/reporting/owner-list', {
          method: "GET"
        }).then(response => {
          if(Math.floor(response.status / 200) != 1)
            return(null);
          return(response.json());
        }).catch(err => {
          return(null);
        }).then((result) => {
          this.availableOwners = result || []; // [{ type: Account, id: 1, title: "Get Covered" }, ...]
          if(result && result.length > 0) {
            this.prepareBrowseAs(specialSection);
          }
        });
      }
    }
    // construct the list
    this.items = this.getNavbarItems();
    let list = document.createElement("ul");
    this.items.forEach((item) => {
      this.makeItemWithChildren(item, list);
    });
    // attach the pieces
    this.domNode.innerHTML = "";
    this.domNode.appendChild(logo);
    this.domNode.appendChild(specialSection);
    this.domNode.appendChild(list);
  }
  
  prepareBrowseAs(specialSection) {
    specialSection.innerHTML = '' +
      '<label for="owner-select">Browse as:</label>' +
      '<select name="owner-select">' +
        this.availableOwners.map((ao,ind) => {
          return('<option value="'+ind+'" '+(this.app.organizable['organizable_type'] == ao['type'] && this.app.organizable['organizable_id'] == ao['id'] ? 'selected' : '')+'>'+ao['title']+'</option>');
        }).join("\n") +
      '</select>'
    ;
    let meesa = this;
    specialSection.querySelector('select[name="owner-select"]').onchange = function(evt) {
      let found = meesa.availableOwners[+evt.target.value];
      if(found) {
        meesa.app.organizable = { organizable_type: found['type'], organizable_id: found['id'] };
        meesa.app.goTo('.').then(() => { meesa.refresh(); });
      }
    };
  }

  getNavbarItems() {
    return(!App.current.user ? [
      {
        label: "Log In",
        url: "javascript:App.current.loginViaGui();"
      }
    ] : [
      {
        label: "Log Out",
        url: "javascript:App.current.logout();"
      },
      {
        label: "Coverage Reports",
        children: [
          {
            label: "Full Report",
            url: "javascript:App.current.goTo('/coverage-reports');"
          },
          {
            label: "All Leases",
            url: "javascript:App.current.goTo('/coverage-reports?fr=Leases');"
          },
          {
            label: "All Residents",
            url: "javascript:App.current.goTo('/coverage-reports?fr=Residents');"
          }
        ]
      },
      {
        label: "Policies",
        children: [
          {
            label: "All Policies",
            url: "javascript:App.current.goTo('/policy-reports');"
          },
          {
            label: "Expiring Next 30 Days",
            url: "javascript:App.current.goTo('/policy-reports?sr=Expiring%20within%2030%20Days');"
          },
          {
            label: "Expired Last 30 Days",
            url: "javascript:App.current.goTo('/policy-reports?sr=Expired%20within%2030%20Days');"
          }
        ]
      }
    ]);
  }
  
  makeItemWithChildren(item, papa) {
    let created = document.createElement('li');
    if(item['url'])
      created.innerHTML = "<a href=\"" + item['url'] + "\">" + item['label'] + "</a>";
    else
      created.textContent = item['label'];
    papa.appendChild(created);
    if(!item['children'] || item['children'].length == 0)
      return;
    let newGrandpapa = document.createElement('li');
    papa.appendChild(newGrandpapa);
    let newPapa = document.createElement('ul');
    newGrandpapa.appendChild(newPapa);
    for(let child of item['children'])
      this.makeItemWithChildren(child, newPapa);
  }
}
