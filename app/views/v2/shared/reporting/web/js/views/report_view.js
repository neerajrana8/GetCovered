

class FilterDialog extends Dialog {

  constructor(app, containingDiv) {
    super(app, containingDiv);
    this.domNode.innerHTML = "";
    this.filterMethods = [];
    this.currentFilterMethodIndex = 0;
  }
  
  interact(column, filters, caller) {
    return(new Promise((resolve, reject) => {
      if(!column['filters']) {
        resolve(null);
        return;
      }
      // prepare to prepare the dialog
      let filterMethods = [];
      if(column['filters'].includes('scalar') || column['filters'].includes('like') || (column['filters'].includes('array') && column['data_type'] == 'enum'))
      {
        // here we set things up for scalar or like searches, or for enum array searches
        let div = document.createElement('div');
        let filterMethod = {
          title: "Choose Values",
          div: div,
          current: null,
          apply: () => { return(null); }
        };
        filterMethods.push(filterMethod);
        if(column['data_type'] == 'boolean') {
          // set up boolean selection
          div.innerHTML = '' +
            '<label for="filter-search-select">Value:</label>' +
            '<select name="filter-search-select">' +
              '<option value="null"' + (typeof filters[column['apiIndex']] !== 'boolean' ? ' selected' : '') + '>All</option>' +
              '<option value="true"' + (filters[column['apiIndex']] === true ? ' selected' : '') + '>' + caller.formatField(column, true) + '</option>' +
              '<option value="false"' + (filters[column['apiIndex']] === false ? ' selected' : '') + '>' + caller.formatField(column, false) + '</option>' +
            '</select>'
          ;
          if(typeof filters[column['apiIndex']] === 'boolean')
            filterMethod['current'] = true;
          filterMethod['apply'] = (() => {
            return({ "true": true, "false": false, "null": undefined }[div.querySelector('select[name="filter-search-select"]').value]);
          });
        }
        else if(column['data_type'] == 'enum') {
          if(column['filters'].includes('array')) {
            // set up enum-selecting checkboxes
            div.innerHTML = '' + (
              column['enum_values'].map((ev,ind) => {
                return(
                  '<input name="filter-search-checkbox" type="checkbox" value="'+ev+'">'+caller.formatField(column, ev)
                );
              }).join("<br>\n")
            );
            // set the checkbox values
            if(filters.hasOwnProperty(column['apiIndex'])) {
              let values = filters[column['apiIndex']];
              if(!Array.isArray(values))
                values = [values];
              else
                filterMethod['current'] = true;
              let elements = Array.from(div.querySelectorAll('input[name="filter-search-checkbox"]'));
              elements.forEach((element) => {
                if(values.includes(element.value))
                  element.checked = true;
                else
                  element.checked = false;
              });
            }
            // set up the apply function
            filterMethod['apply'] = (() => {
              return(Array.from(div.querySelectorAll('input[name="filter-search-checkbox"]')).filter((x) => (x.checked)).map((x) => x.value));
            });
          }
          else {
            // set up enum-selecting select & set its values
            div.innerHTML = '' +
              '<label for="filter-search-select">Value:</label>' +
              '<select name="filter-search-select">' +
                column['enum_values'].map((ev,ind) => {
                  let t = caller.formatField(column, ev);
                  let s = (typeof filters[column['apiIndex']] === 'string' && filters[column['apiIndex']] == ev);
                  return('<option value="'+ev+'"'+(s ? " selected" : "")+'>'+t+'</option>');
                }).join("\n") +
              '</select>'
            ;
            if(typeof filters[column['apiIndex']] === 'string')
              filterMethod['current'] = true;
            // set up the apply function
            filterMethod['apply'] = (() => {
              return(div.querySelector('select[name="filter-search-select"]').value);
            });
          }
        }
        else {
          // set up string search
          div.innerHTML = '' +
            '<label for="filter-search">Search for:</label>' +
            '<input name="filter-search" type="text" />' +
            '<br>' +
            '<label for="filter-search-exact">Exact Match</label>' + (
              column['filters'].includes('like') ? (
                  '<input name="filter-search-exact" type="checkbox" '+(column['filters'].includes('scalar') ? '' : ' disabled')+'>'
                ) : (
                  '<input name="filter-search-exact" type="checkbox" checked disabled>'
                )
            )
          ;
          // set values
          if(filters.hasOwnProperty(column['apiIndex'])) {
            if(typeof filters[column['apiIndex']] === 'string') {
              filterMethod['current'] = true;
              div.querySelector('input[name="filter-search-exact"]').checked = true;
              div.querySelector('input[name="filter-search"]').value = filters[column['apiIndex']];
            }
            else if(typeof filters[column['apiIndex']] === 'object' && filters[column['apiIndex']]['like']) {
              filterMethod['current'] = true;
              div.querySelector('input[name="filter-search-exact"]').checked = false;
              div.querySelector('input[name="filter-search"]').value = filters[column['apiIndex']]['like'];
            }
          }
          // set up the apply function
          filterMethod['apply'] = (() => {
            if(!div.querySelector('input[name="filter-search-exact"]').checked)
              return({ like: div.querySelector('input[name="filter-search"]').value });
            return(div.querySelector('input[name="filter-search"]').value);
          });
        }
      }
      if(column['filters'].includes('interval'))
      {
        // do nothing for now
      }
      // prepare the dialog
      this.domNode.innerHTML = '' +
        '<div class="centered">' +
        '  <h3>Filter ' + column['title'] + '</h3>' +
        '  <button onclick="App.current.currentDialog.apply()">Apply Filter</button>' +
        '  <button onclick="App.current.currentDialog.clear()">Clear Filter</button>' +
        '  <button onclick="App.current.currentDialog.cancel()">Cancel</button>' +
        '</div>' +
        ''
      ;
      if(filterMethods.length == 0) {
        resolve(null);
        return;
      }
      if(filterMethods.length > 1) {
        let div = document.createElement('div');
        div.innerHTML = '' +
          '<label for="filter-method-sel">Filter method:</label>' +
          '<select name="filter-method-sel" onchange="App.current.currentDialog.changeMethod(this)">' + (
            filterMethods.map((fm,fmind) => {
              return('<option value="'+fmind+'"'+(fm['current'] ? ' selected' : '')+'>'+fm['title']+'</option>');
            }).join("\n")
          ) +
          '</select>'
        ;
        this.domNode.appendChild(div);
      }
      this.filterMethods = filterMethods;
      this.currentFilterMethodIndex = this.filterMethods.findIndex((fm) => fm['current']);
      if(this.currentFilterMethodIndex == -1)
        this.currentFilterMethodIndex = 0;
      this.domNode.appendChild(this.filterMethods[this.currentFilterMethodIndex]['div']);
      // open the dialog and wait for the user to do something
      this.open((chosenFilters) => {
        console.log("closing open with ", chosenFilters);
        //if(chosenFilters)
          resolve(chosenFilters);
        //else
          //resolve(null);
      });
    }));
  }
  
  changeMethod(selectElement) {
    let oldDiv = this.filterMethods[this.currentFilterMethodIndex]['div'];
    this.currentFilterMethodIndex = selectElement.value;
    oldDiv.replaceWith(this.filterMethods[this.currentFilterMethodIndex]['div']);
  }
  
  apply() {
    this.exhaustCallbacks(this.filterMethods[this.currentFilterMethodIndex]['apply']());
    this.close();
  }
  
  clear() {
    console.log("resolving with undefined");
    this.exhaustCallbacks();//undefined);
    this.close();
  }
  
  cancel() {
    this.exhaustCallbacks(null);
    this.close();
  }
  
  prepareToOpen() {
  }
  
  prepareToClose() {
  }
}



class ReportView {
  constructor(app, parent, manifest, subreport) {
    // core setup
    this.app = app;
    this.parent = parent;
    this.sacredVow = procrastinate(); // promise used to linearize loading calls (.refreshFromServer and .initializeFromHash)
    this.manifest = manifest;
    this.subreport = subreport;
    this.uniqueness = ((!this.subreport['unique'] || (Array.isArray(this.subreport['unique']) && this.subreport['unique'].length == 0))
      ? null
      : [
          (
            Array.isArray(this.subreport['unique']) ? this.subreport['unique'] : [this.subreport['unique']]
          ).map((prop) => this.subreport['columns'].find((c) => (c['title'] == prop)))
        ].map((val) => (val.some((col) => !col) ? null : val))[0] // refuse to accept the uniqueness list if columns are missing
    ); // array of column specifications for those columns used to determine uniqueness--or null if does not exist
    // MOOSE WARNING: error handling for if no such subreport exists
    // requests etc
    this.pendingLoads = 0; // how many loading statuses are pending
    // set up our filter dialog
    this.filterDialog = this.app.getDialog('report_view.filter') || this.app.registerDialog('report_view.filter', new FilterDialog(this.app));
    // selections
    this.selectedRows = [];
    this.cachedResults = []; // cache of the originally selected rows + the last results from the server put into the table
    this.cachedResultsFirstIndex = 0; // first index at which cached results begin (for carried over columns)
    // pagination, sorting, filtering
    this.totalPages = 0;
    this.totalEntries = 0;
    this.currentPage = 0;
    this.pagination = this.subreport['pagination'] || {
      page: (this.subreport['pagination'] && this.subreport['pagination']['page']) ? +this.subreport['pagination']['page'] : 0,
      per: (this.subreport['pagination'] && this.subreport['pagination']['per']) ? +this.subreport['pagination']['per'] : 50,
    };
    this.sort = {
      column: (this.subreport['sort'] && this.subreport['sort']['column']) ? this.subreport['sort']['column'] : [],
      direction: (this.subreport['sort'] && this.subreport['sort']['direction']) ? this.subreport['sort']['direction'] : [],
    };
    this.filter = {}; // MOOSE WARNING: implement this.subreport default filter loading
    // dom nodes for loading screen
    this.loadingNode = document.createElement('div');
    this.loadingNode.textContent = "Loading...";
    // dom nodes for table
    this.loadedNode = document.createElement('div');
    this.paginationNode = document.createElement('div');
      this.paginationNode.classList.add("paginator");
      this.loadedNode.appendChild(this.paginationNode);
      this.refreshPaginationNode();
    this.tableNode = document.createElement('table');
      this.tableNode.className = "report-view-table";
      this.populateTable([]);
      this.loadedNode.appendChild(this.tableNode);
    // parent dom node
    this.domNode = document.createElement('div');
    this.domNode.className = "report-view-container";
    this.domNode.appendChild(this.loadingNode);
  }
  
  // parent page can call this to get the options it should create header buttons for
  refreshNavigationOptions() {
    let navopts = [];
    navopts = this.manifest['subreport_links'].filter(
      (srl) => (srl['origin'] == this.subreport['title'])
    ).sort(
      (a,b) => a['title'].localeCompare(b['title'])
    ).map(
      (link) => link['title']
    );
    if(this.selectedRows.length == 0) {
      navopts = navopts.map((opt) => {
        return({
          title: opt,
          params: null,
          enabled: false,
          tooltip: "Select a row first!"
        });
      });
    }
    else {
      navopts = navopts.map((opt) => {
        return({
          title: opt,
          params: null,
          enabled: true,
          tooltip: null
        });
      });
    }
    if(this.parent && this.parent.receiveNavigationOptions) {
      this.parent.receiveNavigationOptions(this, navopts);
    }
  }
  
  // parent page can call this to get navigation parameters after a nav option button is pressed
  getNavigationParams(navigationOption, optionParams) { // MOOSE WARNING: needs update for multiselect
    let foundIndex = this.manifest['subreport_links'].findIndex((srl) => (srl['origin'] == this.subreport['title'] && srl['title'] == navigationOption));
    if(foundIndex == -1)
      return({});
    let found = this.manifest['subreport_links'][foundIndex];
    // MOOSE WARNING: this needs to updated to support things like nested keys
    // make sure we have all the necessary keys
    //Object.entries(found['fixed_filters'] || {}).concat(found['copied_columns'].map((cc)=>[null,cc])).map((entry) => {
    //  if(!selectedValues.hasOwnProperty(entry[1]))
    //    selectedValues[entry[1]] = this.selectedRows[0][this.subreport.columns.find((c) => (c['title'] == entry[1]))['apiIndex']]
    //});
    // build the necessary parameters
    let fixed = {};
    Object.entries(found['fixed_filters']).forEach((entry) => {
      fixed[entry[0]] = this.selectedRows[0][this.subreport.columns.find((c) => (c['title'] == entry[1]))['apiIndex']];
    });
    return({
      srl: foundIndex,
      sr: found['destination'],
      f2: fixed
    });
    /*
    {
      srl: foundIndex,
      f2: this.subreport['fixed_filters'].map(
    }
    
      p1: this.pagination['page'],
      p2: this.pagination['per'],
      s1: this.sort['column'],
      s2: this.sort['direction'],
      f1: this.filter,
      f2: this.fixedFilter,
      sr: !this.uniqueness ? [] : this.selectedRows.map((selrow) => this.uniqueness.map((col) => selrow[col['apiIndex']]))
    // done
    return(sv);
    */
    return(null);
  }
  
  refreshPaginationNode() {
    this.paginationNode.innerHTML = '' +
      '<span class="pagination-left">' +
      '</span>' +
      '<span class="pagination-center">' +
      '  <span class="pagination-disp">Page: ' + (1+this.currentPage) +' / ' + this.totalPages + '</span>' +
      '  <span class="pagination-per">' +
      '    (' +
      '    <label for="pagination-per-select">per page:</label>' +
      '    <select class="pagination-select" name="pagination-per-select">' +
      '      <option value="10"'+(this.pagination['per']==10?' selected':'')+'>10</option>' +
      '      <option value="50"'+(this.pagination['per']==50?' selected':'')+'>50</option>' +
      '      <option value="100"'+(this.pagination['per']==100?' selected':'')+'>100</option>' +
      '    </select>' +
      '    )' +
      '  </span>' +
      '</span>' +
      '<span class="pagination-right">' +
      '</span>'
    ;
    // left pagination button
    let leftArrow = this.paginationNode.querySelector(".pagination-left");
    if(this.currentPage <= 0) {
      leftArrow.textContent = "\u25C1";
      leftArrow.classList.add("liar");
    }
    else {
      leftArrow.classList.add("honest-fella");
      leftArrow.textContent = "\u25C0";
      leftArrow.addEventListener('click', (evt) => {
        this.pagination['page'] -= 1;
        this.getData();
      });
    }
    // right pagination button
    let rightArrow = this.paginationNode.querySelector(".pagination-right");
    if(this.currentPage >= this.totalPages - 1) {
      rightArrow.textContent = "\u25B7";
      rightArrow.classList.add("liar");
    }
    else {
      rightArrow.classList.add("honest-fella");
      rightArrow.textContent = "\u25B6";
      rightArrow.addEventListener('click', (evt) => {
        this.pagination['page'] += 1;
        this.getData();
      });
    }
    // set up page size select reaction
    let reportView = this;
    this.paginationNode.querySelector(".pagination-select").onchange = function() {
      console.log("SELL");
      reportView.pagination['per'] = +this.options[this.selectedIndex].value;
      reportView.prepareToRefresh();
    };
  }
  
  prepareToRefresh() {
    this.getData(); // MOOSE WARNING: add timing stuff in here
  }
  
  
  stateToHash() {
    return({
      p1: this.pagination['page'],
      p2: this.pagination['per'],
      s1: this.sort['column'],
      s2: this.sort['direction'],
      f1: this.filter,
      f2: this.fixedFilter,
      sel: !this.uniqueness ? [] : this.selectedRows.map((selrow) => this.uniqueness.map((col) => selrow[col['apiIndex']])),
      sr: this.subreport['title']
    });
  }
  
  initializeFromHash(src) {
    console.log("SRC IS: ", src);
    this.startLoading();
    if(src.hasOwnProperty('p1'))
      this.pagination['page'] = src['p1'];
    if(src['p2'])
      this.pagination['per'] = src['p2'];
    if(src['s1'] && src['s2']) {
      this.sort['column'] = src['s1'];
      this.sort['direction'] = src['s2'];
    }
    if(src['f1'])
      this.filter = src['f1'];
    if(src['f2'])
      this.fixedFilter = src['f2'];
    if(!this.uniqueness || !src['sel'] || src['sel'].length == 0)
      this.selectedRows = [];
    else {
      for(let selrow of src['sel']) {
        // fetch dem fellas
        this.sacredVow = this.sacredVow.then(svr => {
          let uniqueConstraints = {};
          this.uniqueness.forEach((col,colind) => {
            uniqueConstraints[col['apiIndex']] = selrow[colind];
          });
          return(this.getUnique(uniqueConstraints).then((col) => { this.selectedRows.push(col) }));
        }).catch((error) => {
          this.selectedRows = [];
          console.log("Unable to load selected rows: encountered error:", error);
        });
      }
    }
    this.sacredVow = this.sacredVow.then((whatever) => {
      return(this.getData());
    }).catch((error) => {
      console.log("Failed to retrieve data!", error);
      this.populateTable([]);
    }).then((whatever) => {
      this.finishLoading();
    });
    return(this.sacredVow);
  }
  
  refreshFromServer() {
    this.startLoading();
    this.sacredVow = this.sacredVow.then((whatever) => {
      return(this.getData());
    }).then((whatever) => {
      this.finishLoading();
    });
    return(this.sacredVow);
  }
  
  startLoading() {
    ++this.pendingLoads;
  }
  
  finishLoading() {
    if(--this.pendingLoads == 0 && this.loadingNode.parentNode) {
      this.loadingNode.replaceWith(this.loadedNode);
    }
  }
  
  // fetches a single uniquely specified record from the API (reject if error)
  getUnique(uniqueConstraints, attempts = 1) {
    return(
      this.app.fetch(this.subreport['endpoint'], {
        method: "POST",
        body: JSON.stringify(Object.assign({}, {
          filter: Object.assign({}, this.filter, this.fixedFilter, uniqueConstraints)
        }, this.app.organizable))
      }).then(response => {
        if(Math.floor(response.status / 200) != 1) {
          if(--attempts > 0)
            return(this.getUnique(uniqueConstraints, attempts));
          throw new Error("Reload request failed!");
        }
        return(response.json().then(resp => {
          if(!Array.isArray(resp) || resp.length != 1) {
            throw new Error("Reload request returned resultset of length " + resp.length + "!");
          }
          return(resp[0]);
        }));
      })
    );
  }
  
  // fetches data from the API and populates the table with it (reject if error)
  getData(attempts = 1) {
    return(this.app.fetch(this.subreport['endpoint'], {
      method: "POST",
      body: JSON.stringify(Object.assign({}, {
        sort: this.sort,
        filter: Object.assign({}, this.filter, this.subreport['fixed_filters'], this.fixedFilter),
        pagination: this.pagination
      }, this.app.organizable))
    }).then(response => {
      if(Math.floor(response.status / 200) == 1) {
        // grab the pagination metadata
        this.totalPages = +(response.headers.get("total-pages") || 0);
        this.totalEntries = +(response.headers.get("total-entries") || 0);
        this.currentPage = +(response.headers.get("current-page") || 0);
        return(response.json());
      }
      else {
        if(--attempts > 0)
          return(this.getData(attempts - 1));
        console.log("Request failed (" + this.subreport['endpoint'] + ")");
        throw new Error("Request failed (" + this.subreport['endpoint'] + ")");
      }
    }).then(data => {
      this.populateTable(data);
      this.refreshPaginationNode();
      this.refreshNavigationOptions();
    }));
  }
  
  // formats an individual field as specified by column metadata
  formatField(column, value) {
    switch(column['data_type']) {
      case("boolean"):
        switch(column["format"]) {
          case("TF"):
            return(value ? "True" : "False");
          case("YN"):
          default:
            return(value ? "Yes" : "No");
        }
      case("enum"):
        if(column['format']) { // will be array of enum titles
          let foundIndex = column['enum_values'].findIndex((val,name) => (val == value));
          return("" + (column['format'][foundIndex] || (value == null ? "" : ("" + value))));
        }
        return(value == null ? "" : "" + value);
      case("number"): // for now MOOSE WARNING
        if(column['format'] == 'percent')
          return(value == null ? "" : (+value).toFixed(2) + "%");
        return(value == null ? "" : (+value).toFixed(2));
      case('integer'):
        return(value == null ? "" : (+value).toFixed(0));
      case('string'):
      default:
        return(value == null ? "" : "" + value);
    }
  }
  
  modifySorting(colApiIndex, direction, shiftPressed) {
    if(shiftPressed) {
      let sortIndex = this.sort['column'].indexOf(colApiIndex);
      if(sortIndex == -1) {
        this.sort['column'].push(colApiIndex);
        this.sort['direction'].push(direction);
      }
      else {
        this.sort['direction'][sortIndex] = direction;
      }
    }
    else {
      this.sort['column'] = [colApiIndex];
      this.sort['direction'] = [direction];
    }
    this.parent.refreshChildState(this, this.stateToHash());
    return(this.getData());
  }
  
  // replaces the table dom node with a new table dom node, fully populated from the provided array of data from the server
  populateTable(data) {
    // create new dom node
    let newTableNode = document.createElement('table');
    newTableNode.className = "report-view-table";
    this.tableNode.replaceWith(newTableNode);
    this.tableNode = newTableNode;
    // create the header
    let tableHeader = document.createElement('tr');
    tableHeader.classList.add("default-cursor");
    let columnIndex = -1;
    for(let column of this.subreport['columns']) {
      columnIndex += 1;
      if(!column['invisible']) {
        let sortindex = this.sort['column'].findIndex((scol) => (scol == column['apiIndex']));
        let sortdir = this.sort['direction'][sortindex];
        let cell = document.createElement('th');
        cell.innerHTML = '' +
          '<div class="report-view-col-title">' + column['title'] + '</div>' +
          '<div class="report-view-col-filter">' +
          '  <img class="filter-icon" src="assets/' + (
            this.filter.hasOwnProperty(column['apiIndex']) ? 'filter_hot.png' : 'filter_cold.png'
          ) + '">' +
          '  </img>' +
          '</div>' +
          '<div class="report-view-col-ctrl">' +
          (!column['sortable'] ? "" : (
            '  <div>' +
            '    <img class="upsort" src="assets/up_'+(sortdir == "asc" ? "hot" : "cold")+'.png"></img>' +
            '  </div>' +
            '  <div>' +
                 (sortindex == -1 ? "&nbsp;" : (sortindex+1)) +
            '  </div>' +
            '  <div>' +
            '    <img  class="downsort" src="assets/down_'+(sortdir == "desc" ? "hot" : "cold")+'.png"></img>' +
            '  </div>'
          )) +
          '</div>'
        ;
        let colind = columnIndex;
        cell.querySelector('.filter-icon').addEventListener('click', (evt) => {
          this.filterDialog.interact(this.subreport['columns'][colind], this.filter, this).then((result) => {
            if(result == null) {
              if(typeof result === 'undefined')
                delete this.filter[this.subreport['columns'][colind]['apiIndex']];
              else
                return;
            }
            else
              this.filter[this.subreport['columns'][colind]['apiIndex']] = result;
            this.parent.refreshChildState(this, this.stateToHash());
            this.getData();
          });
        });
        let datUpsort = cell.querySelector('.upsort')
        if(datUpsort) {
          datUpsort.addEventListener('click', (evt) => {
            this.modifySorting(this.subreport['columns'][colind]['apiIndex'], "asc", evt.shiftKey);
          });
        }
        let datDownsort = cell.querySelector('.downsort');
        if(datDownsort) {
          datDownsort.addEventListener('click', (evt) => {
            this.modifySorting(this.subreport['columns'][colind]['apiIndex'], "desc", evt.shiftKey);
          });
        }
        tableHeader.appendChild(cell);
      }
    }
    this.tableNode.appendChild(tableHeader);
    // update selected row indices
    let negatory = 0; // minimal negative index relative to the start of the queried data that any selected column has
    if(this.selectedRows.length > 0 && this.subreport['unique']) {
      let criterion = (Array.isArray(this.subreport['unique']) ? this.subreport['unique'] : [this.subreport['unique']])
                           .map((prop) => this.subreport['columns'].find((c) => (c['title'] == prop)))
      if(criterion.some((c) => !c)) {
        // error
        this.selectedRows = [];
        console.log("Dropped row selections due to lack of match for unique criterion columns!")
      }
      else {
        this.selectedRows.forEach((selrow) => {
          let foundIndex = data.findIndex(
            (row) => criterion.every((col) => (row[col['apiIndex']] == selrow[col['apiIndex']]))
          );
          selrow['FRONTEND_INDEX'] = (foundIndex == -1 ? --negatory : foundIndex);
        });
        this.selectedRows = this.selectedRows.sort((a,b) => (a['FRONTEND_INDEX'] - b['FRONTEND_INDEX']));
        // now the selectedRows have negative FRONTEND_INDEX values if not also in the query, otherwise nonnegative, and are sorted in ascending order
      }
    }
    else {
      if(this.selectedRows.length == 0)
        this.selectedRows = [];
      else {
        console.log("Dropped row selections due to lack of uniqueness criterion!", this.subreport['unique']);
      }
    }
    // put everything together into one nice array
    this.cachedResults = this.selectedRows.filter(sr => (sr['FRONTEND_INDEX'] < 0)).concat(data);
    // bring in any carried over selected rows that aren't also in the query
    let rowIndex = -1;
    let selrowindex = 0;
    for(; selrowindex < this.selectedRows.length && this.selectedRows[selrowindex]['FRONTEND_INDEX'] < 0; ++selrowindex) {
      rowIndex += 1;
      let currentRowIndex = rowIndex; // this is stupidly necessary for JS to keep the old value, even with let...
      let row = document.createElement('tr');
      row.classList.add("default-cursor");
      for(let column of this.subreport['columns']) {
        if(column['invisible'])
          continue;
        let cell = document.createElement('td');
        cell.textContent = this.formatField(column, this.selectedRows[selrowindex][column['apiIndex']])
        row.appendChild(cell);
      }
      this.selectedRows[selrowindex]['FRONTEND_INDEX'] = rowIndex; // we rewrite the frontend index to actually represent position in the table and in this.cachedResults
      row.classList.add("selected-row");
      // add selection callback
      row.addEventListener('click', () => {
        this.rowSelectionChange(currentRowIndex);
      });
      this.tableNode.appendChild(row);
    }
    // now selrowindex is at the first non-negatory selectedRow; we need to add abs(negatory) (the lowest negatative FRONTEND_INDEX we originally used) to them since we updated the selected row frontend indices too
    for(; selrowindex < this.selectedRows.length; ++selrowindex)
      this.selectedRows[selrowindex]['FRONTEND_INDEX'] -= negatory;
    // bring in the data from the request
    this.cachedResultsFirstIndex = rowIndex + 1;
    for(let i = 0; i < data.length; ++i) {
      rowIndex += 1;
      // create the row
      let row = document.createElement('tr');
      row.classList.add("default-cursor");
      for(let column of this.subreport['columns']) {
        if(column['invisible'])
          continue;
        let cell = document.createElement('td');
        cell.textContent = this.formatField(column, data[i][column['apiIndex']])
        row.appendChild(cell);
      }
      // select the row if necessary (commented out old code)
      if(this.cachedResults[rowIndex].hasOwnProperty('FRONTEND_INDEX'))
        row.classList.add("selected-row");
      //let found = this.selectedRows.find((selrow) => (selrow['FRONTEND_INDEX'] == i));
      //if(found) {
      //  found['FRONTEND_INDEX'] = rowIndex;
      //  row.classList.add("selected-row");
      //}
      // add selection callback
      let currentRowIndex = rowIndex; // this is necessary for JS to capture the right value
      row.addEventListener('click', () => {
        this.rowSelectionChange(currentRowIndex);
      });
      // chuck it on the pile
      this.tableNode.appendChild(row);
    }
    this.parent.refreshChildState(this, this.stateToHash());
    this.refreshNavigationOptions();
  }
  
  rowSelectionChange(index) {
    // index is the index of the row in the physical table (with the header as -1), which means the index in cachedResults
    // cachedResults is the originally selected folk + whatever has been pulled in by query (selected elements not necessarily first, cause sorting applies to them if they are also among the query results)
    // cachedResultsFirstIndex is the index in cachedResults of the first fellow from the query
    // someRow['FRONTEND_INDEX'] exists only on currently selected rows and is of the same format as index
    console.log("RSC: ", index);
    // prepare
    let singleSelectionOnly = true; // MOOSE WARNING: set for now to prohibit multi-select
    let row = this.tableNode.rows[index+1]; //+1 to account for the header
    if(!row || index == -1)
      return; // no need to have everything break if some bug occurred, just silently ignore the selection request
    // select/deselect
    let sel = this.selectedRows.find((selrow) => (selrow['FRONTEND_INDEX'] == index));
    if(sel) {
      row.classList.remove("selected-row");
      delete sel['FRONTEND_INDEX'];
      this.selectedRows = this.selectedRows.filter((sr) => (sr != sel));
    }
    else {
      if(singleSelectionOnly) {
        this.selectedRows.forEach((sr) => {
          this.tableNode.rows[1 + sr['FRONTEND_INDEX']].classList.remove("selected-row");
          delete this.cachedResults[sr['FRONTEND_INDEX']]['FRONTEND_INDEX'];
        });
        this.selectedRows = [];
      }
      row.classList.add("selected-row");
      this.cachedResults[index]['FRONTEND_INDEX'] = index;
      this.selectedRows.push(this.cachedResults[index]);
      // it's called cachedResultsFirstIndex because the extra selected rows aren't part of it. 
    }
    // done
    this.parent.refreshChildState(this, this.stateToHash());
    this.refreshNavigationOptions();
  }
  
};
