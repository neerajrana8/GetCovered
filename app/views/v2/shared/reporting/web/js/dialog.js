
class Dialog {

  constructor(app, parentDomNode = document.body) {
    this.app = app;
    this.callbacks = [];
    this.domNode = document.createElement('dialog');
      parentDomNode.appendChild(this.domNode);
  }
  
  //// overridable ////
  
  prepareToOpen() {
  }
  
  prepareToClose() {
  }
  
  //// internal logic ////
  
  open(callback) {
    this.callbacks.push(callback);
    console.log("Pushing to dialog stack...");
    this.app.dialogStack.push(this);
    this.prepareToOpen();
    this.domNode.showModal();
  }
  
  close() {
    this.prepareToClose();
    this.app.dialogStack.pop();
    this.domNode.close();
    let oldCallbacks = this.callbacks;
    this.callbacks = [];
    oldCallbacks.forEach((callback) => callback(null));
  }
  
  exhaustCallbacks(param) {
    let oldCallbacks = this.callbacks;
    this.callbacks = [];
    oldCallbacks.forEach((callback) => callback(param));
  }
  
}

