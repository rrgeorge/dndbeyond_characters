var storedCalls = [];

var open_proto_orig = XMLHttpRequest.prototype.open;
var open_proto_repl = function open(method, url, async, user, password) {
    this._url = url;
    return open_proto_orig.apply(this, arguments);
};
var send_proto_orig = XMLHttpRequest.prototype.send;
var send_proto_repl = function send(data) {
    var call = new Object();
    var dataObj = JSON.parse(data);
    if (this._url.startsWith("/api/")) {
        Object.defineProperty(this,'readyState', { configurable: true, writable: true, });
        Object.defineProperty(this,'status', { configurable: true, writable: true, });
        Object.defineProperty(this,'statusText', { configurable: true, writable: true, });
        Object.defineProperty(this,'response', { configurable: true, writable: true, });
        Object.defineProperty(this,'responseText', { configurable: true, writable: true, });
        Object.defineProperty(this,'responseURL', { configurable: true, writable: true, });
        Object.defineProperty(this,'responseType', { configurable: true, writable: true, });
        this.status = 200;
        this.statusText = "OK";
        if (this._url.startsWith("http")) {
            this.responseURL = this._url;
        } else {
            this.responseURL = document.location.protocol + "//" + document.location.host + this._url;
        }
        this.onerror = null;
        if (this._url.startsWith("/api/config/json") && typeof jsonconfig !== 'undefined') {
            this.response = jsonconfig;
            this.responseText = jsonconfig;
        } else if (this._url.startsWith("/api/character/services") && typeof jsoncharsvc !== 'undefined') {
            this.response = jsoncharsvc;
            this.responseText = jsoncharsvc;
        } else if (this._url.startsWith("/api/spells/list/json") && typeof jsonspells !== 'undefined') {
            var qregex = /(characterClassId)=?([^&]*)/;
            var qmatch = qregex.exec(this._url);
            if (qmatch && qmatch[2] && jsonspells[qmatch[2]]) {
                this.response = jsonspells[qmatch[2]];
                this.responseText = jsonspells[qmatch[2]];
            }
        } else if (this._url.startsWith("/api/equipment/list/json") && typeof jsonequip !== 'undefined') {
            this.response = jsonequip;
            this.responseText = jsonequip;
        } else {
            var respObj = new Object();
            if (dataObj && dataObj.characterId) {
                respObj.id = dataObj.characterId;
            }
            respObj.success = true;
            respObj.message = "Success";
            respObj.result = new Object();
            this.response = JSON.stringify(respObj);
            this.responseText = JSON.stringify(respObj);
        }
        this.readyState = 4;
        this.onreadystatechange(4);
    } else if (document.getElementById("character-sheet-target") && this._url.endsWith(document.getElementById("character-sheet-target").getAttribute("data-character-endpoint")) && typeof jsonfile !== 'undefined'){
        Object.defineProperty(this,'readyState', { configurable: true, writable: true, });
        Object.defineProperty(this,'status', { configurable: true, writable: true, });
        Object.defineProperty(this,'statusText', { configurable: true, writable: true, });
        Object.defineProperty(this,'response', { configurable: true, writable: true, });
        Object.defineProperty(this,'responseText', { configurable: true, writable: true, });
        Object.defineProperty(this,'responseURL', { configurable: true, writable: true, });
        Object.defineProperty(this,'responseType', { configurable: true, writable: true, });
        this.status = 200;
        this.statusText = "OK";
        if (this._url.startsWith("http")) {
            this.responseURL = this._url;
        } else {
            this.responseURL = document.location.protocol + "//" + document.location.host + this._url;
        }
        this.response = jsonfile;
        this.responseText = jsonfile
        this.onerror = null;
        this.readyState = 4;
        this.onreadystatechange(4);
    }
    storedCalls.push(call);
};
var fetch_orig = window.fetch;
var fetch_repl = function() {
    if(arguments[0].endsWith("cobalt-token")) {
        return Promise.resolve({
                               json: () =>
                               Promise.resolve({ token: "XXXXX", ttl: 1 } )
                               });
    } else if (arguments[0].startsWith("https://sentry.io/api")){
        return Promise.resolve({
                               json: () =>
                               Promise.resolve({ ok: true } )
                               });
    } else {
        return fetch_orig.apply(this,arguments);
    }
}

function updateOnlineStatus() {
    if(navigator.onLine) {
        //        window.webkit.messageHandlers.captureCall.postMessage("Online")
        window.XMLHttpRequest.prototype.open = open_proto_orig;
        window.XMLHttpRequest.prototype.send = send_proto_orig;
        window.fetch = fetch_orig;
        if (storedCalls.length > 0) {
            for(var i=0,len=storedCalls.length;i<len;i++) {
                storedCalls[i].req.send(storedCalls[i].data);
            }
        }
    } else {
        storedCalls = [];
        //        window.webkit.messageHandlers.captureCall.postMessage("Offline")
        window.fetch = fetch_repl;
        window.XMLHttpRequest.prototype.open = open_proto_repl;
        window.XMLHttpRequest.prototype.send = send_proto_repl;
    }
}
window.addEventListener('offline', updateOnlineStatus, false);
window.addEventListener('online', updateOnlineStatus, false);
updateOnlineStatus();
var config = { attributes: true, childList: true, subtree: true };

var callback = function(mutationsList, observer) {
    
    var siteBar = document.getElementsByClassName('site-bar');
    var siteHeader = document.getElementsByClassName('main');
    if (siteBar[0]) {
        siteBar[0].remove()
    }
    if (siteHeader[0] && siteHeader[0].id != "content") {
        siteHeader[0].remove();
    }
    var headerSize = parseInt(window.getComputedStyle(document.getElementById('site-main')).paddingTop);
    document.getElementById('site-main').style.paddingTop = 0;
    var charSheet = document.getElementsByClassName('ct-character-sheet-mobile');
    if (charSheet[0]) { var padding = parseInt(window.getComputedStyle(charSheet[0]).paddingTop); charSheet[0].style.paddingTop = padding - headerSize; }
    var charHeader = document.getElementsByClassName('ct-character-sheet-mobile__header');
    if (charHeader[0]) { charHeader[0].style.top = 0; }
    var charBHeader = document.getElementsByClassName('builder-sections');
    if (charBHeader[0]) { charBHeader[0].style.top = 0; }
    
    var popoutmenu = document.getElementsByClassName("ct-popout-menu");
    if (popoutmenu[0] && !document.getElementById("backtolistitem")) {
        for(var i=0,len=popoutmenu[0].children.length;i<len;i++){
            if (popoutmenu[0].children[i].children[0] && popoutmenu[0].children[i].children[0].tagName == "FORM") {
                popoutmenu[0].children[i].remove();
            }
        }
        var menuitem = document.createElement("div");
        var menuitema = document.createElement("div");
        var menuitemb = document.createElement("div");
        var menuicon = document.createElement("i");
        menuitem.id = "backtolistitem";
        menuitem.className = "ct-popout-menu__item"
        menuicon.className = "i-menu-portrait";
        menuitema.className = "ct-popout-menu__item-preview";
        menuitemb.className = "ct-popout-menu__item-label";
        menuitemb.innerText="Character List";
        menuitema.appendChild(menuicon);
        menuitem.appendChild(menuitema);
        menuitem.appendChild(menuitemb);
        popoutmenu[0].appendChild(menuitem);
        menuitem.addEventListener("click", function(){window.location='/my-characters';});
    }
    if (document.location.pathname == "/my-characters") {
        if (document.getElementById('footer')) {
            document.getElementById('footer').remove()
        }
    }
}
setTimeout(1000,callback.call());
var observer = new MutationObserver(callback);
observer.observe(document, config);

