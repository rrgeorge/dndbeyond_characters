var storedCalls = [];
var handleOfflineAPI = function(calls) {
    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.apiCall) {
        window.webkit.messageHandlers.apiCall.postMessage(JSON.stringify(calls));
        storedCalls = [];
    } else if (AndroidApp && AndroidApp.apiCall) {
        AndroidApp.apiCall(JSON.stringify(calls));
        storedCalls = [];
    }
};
var open_proto_orig = XMLHttpRequest.prototype.open;
var open_proto_repl = function open(method, url, async, user, password) {
    this._url = url;
    return open_proto_orig.apply(this, arguments);
};
var send_proto_orig = XMLHttpRequest.prototype.send;
var send_proto_repl = function send(data) {
    var call = {};
    var dataObj = JSON.parse(data);
    if (this._url.startsWith("/api/")) {
        Object.defineProperty(this,'readyState', { configurable: true, writable: true });
        Object.defineProperty(this,'status', { configurable: true, writable: true });
        Object.defineProperty(this,'statusText', { configurable: true, writable: true });
        Object.defineProperty(this,'response', { configurable: true, writable: true });
        Object.defineProperty(this,'responseText', { configurable: true, writable: true });
        Object.defineProperty(this,'responseURL', { configurable: true, writable: true });
        Object.defineProperty(this,'responseType', { configurable: true, writable: true });
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
        } else if (this._url.startsWith("/api/monsters") && typeof jsonmonster !== 'undefined') {
            this.response = jsonmonster;
            this.responseText = jsonmonster;
        } else {
            var respObj = {};
            if (dataObj && dataObj.characterId) {
                respObj.id = dataObj.characterId;
            }
            respObj.success = true;
            respObj.message = "Success";
            respObj.result = {};
            if (this._url.startsWith("/api/character/") && typeof jsonfile !== 'undefined') {
                var character = jsonfile.character;
                var apiRegex = new RegExp(".*/api/character/([^/]+)/?([^/]*)/?(.*)");
                var characterAPI = apiRegex.exec(this._url);
		var idx,level,message;
                switch(characterAPI[1]) {
                    case "ability-score":
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            if (dataObj.type == 2) {
                                idx = character.bonusStats.findIndex(x=>x.id == dataObj.id);
                                character.bonusStats[idx] = dataObj.value;
                            }
                            if (dataObj.type == 3) {
                                idx = character.overrideStats.findIndex(x=>x.id==dataObj.id);
                                character.overrideStats[idx] = dataObj.value;
                            }
                        }
                    break;
                    case "bonus-hp":
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            character.bonusHitPoints = dataObj.bonusHitPoints;
                            respObj.result = { "miscHPBonus": dataObj.bonusHitPoints };
                        }
                    break;
                    case "character-value":
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            idx = character.characterValues.findIndex(x=>x.valueId == dataObj.valueId);
                            if (idx > -1) {
                                if (dataObj.value == null) {
                                    character.characterValues.splice(idx,1);
                                } else {
                                    character.characterValues[idx].contextId = dataObj.contextId;
                                    character.characterValues[idx].contextTypeId = dataObj.contextTypeId;
                                    character.characterValues[idx].notes = dataObj.notes;
                                    character.characterValues[idx].typeId = dataObj.typeId;
                                    character.characterValues[idx].value = dataObj.value;
                                    character.characterValues[idx].valueTypeId = dataObj.valueTypeId;
                                }
                            } else {
                                character.characterValues.push({
                                       "contextId": dataObj.contextId,
                                       "contextTypeId": dataObj.contextTypeId,
                                       "notes": dataObj.notes,
                                       "typeId": dataObj.typeId,
                                       "value": dataObj.value,
                                       "valueTypeId": dataObj.valueTypeId
                                       });
                            }
                        }
                    break;
                    case "conditions":
                        if (character.conditions && characterAPI[2] == "set") {
                            idx = character.conditions.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.conditions[idx].level = dataObj.level;
                                if (dataObj.id == 4 && dataObj.level == null) {
                                    character.conditions.splice(idx,1);
                                }
                            } else {
                                character.conditions.push({id: dataObj.id, level: dataObj.level});
                            }
                            
                        }
                        else if (character.conditions && characterAPI[2] == "remove") {
                            idx = character.conditions.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) character.conditions.splice(idx,1);
                        }
                        respObj.result = {
                                "removedHitPoints": character.removedHitPoints,
                                "temporaryHitPoints": character.temporaryHitPoints,
                                "conditions": character.conditions,
                                "modifiers": character.modifiers
                            };
                    break;
                    case "currency":
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            character.currencies.cp = dataObj.cp;
                            character.currencies.sp = dataObj.sp;
                            character.currencies.gp = dataObj.gp;
                            character.currencies.ep = dataObj.ep;
                            character.currencies.pp = dataObj.pp;
                        }
                    case "creatures":
                        if (characterAPI[2] && characterAPI[2] == "add") {
                            var maxID = 2638523;
                            var added = [];
                            character.creatures.forEach(function(item,i){if(item.id > maxID) maxID = item.id});
                            maxID += 1;
                            idx = jsonmonster.findIndex(x=>x.id==dataObj.monsterId);
                            if (idx > -1) {
                                dataObj.names.forEach(function(name,i){
                                 added.push({
                                      "id": maxID,
                                      "entityTypeId": 1295433283,
                                      "name": name,
                                      "description": null,
                                      "isActive": false,
                                      "removedHitPoints": 0,
                                      "temporaryHitPoints": null,
                                      "groupId": dataObj.groupId,
                                      "definition": JSON.parse(JSON.stringify(jsonmonster[idx])),
                                      "limitedUse": null
                                 });
                                 maxID += 1;
                                });
                            }
                            character.creatures = character.creatures.concat(added);
                            respObj.result = added;
                        }
                        if (characterAPI[2] && characterAPI[2] == "hit-points" && characterAPI[3] && characterAPI[3] == "set") {
                            idx = character.creatures.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.creatures[idx].removedHitPoints = dataObj.removedHitPoints;
                                character.creatures[idx].temporaryHitPoints = dataObj.temporaryHitPoints;
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "remove") {
                            idx = character.creatures.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.creatures.splice(idx,1);
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            idx = character.creatures.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.creatures[idx].name = dataObj.name
                            }
                        }
                    break;
                    case "damage":
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            character.removedHitPoints = dataObj.removedHitPoints;
                            character.temporaryHitPoints = dataObj.temporaryHitPoints;
                            respObj.result = {
                                "removedHitPoints": dataObj.removedHitPoints,
                                "temporaryHitPoints": dataObj.temporaryHitPoints
                            };
                        }
                    break;
                    case "equipment":
                        if (characterAPI[2] && characterAPI[2] == "equip") {
                            idx = character.inventory.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.inventory[idx].equipped = true;
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "unequip") {
                            idx = character.inventory.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.inventory[idx].equipped = false;
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "increment") {
                            idx = character.inventory.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.inventory[idx].quantity += dataObj.quantity;
                                if (character.inventory[idx].quantity < 0) {
                                    character.inventory[idx].quantity = 0;
                                }
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "decrement") {
                            idx = character.inventory.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.inventory[idx].quantity -= dataObj.quantity;
                                if (character.inventory[idx].quantity < 0) {
                                    character.inventory[idx].quantity = 0;
                                }
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "remove") {
                            idx = character.inventory.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.inventory.splice(idx,1);
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "attune") {
                            idx = character.inventory.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.inventory[idx].isAttuned = true;
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "unattune") {
                            idx = character.inventory.findIndex(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.inventory[idx].isAttuned = false;
                            }
                        }
                        if (characterAPI[2] && characterAPI[2] == "add") {
                            var maxID = 162858826;
                            var added = [];
                            character.inventory.forEach(function(item,i){if(item.id > maxID) maxID = item.id});
                            maxID += 1;
                            dataObj.equipment.forEach(function(item,i){
                                idx = jsonequip.findIndex(x=>x.id==item.entityId&&x.entityTypeId==item.entityTypeId);
                                if (idx > -1) {
                                     added.push({
                                          "id": maxID,
                                          "entityTypeId": 1439493548,
                                          "quantity": item.quantity,
                                          "isAttuned": false,
                                          "equipped": false,
                                          "definition": JSON.parse(JSON.stringify(jsonequip[idx])),
                                          "limitedUse": null
                                     });
                                }
                            });
                            character.inventory = character.inventory.concat(added);
                            respObj.result = {
                                 "addItems": added,
                                 "spells": { "item": character.spells.item },
                                 "modifiers": { "item": character.modifiers.item }
                            }
                        }
                    break;
                    case "inspiration":
                        character.inspiration = dataObj.inspiration;
                        respObj.result = { "inspiration": dataObj.inspiration };
                    break;
                    case "lifestyle":
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            character.lifestyleId = dataObj.lifestyleId;
                        }
                    break;
                    case "limiteduse":
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            idx = character.actions.class(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.actions.class[idx].limitedUse.numberUsed = dataObj.uses;
                            }
                            idx = character.actions.race(x=>x.id==dataObj.id);
                            if (idx > -1) {
                                character.actions.race[idx].limitedUse.numberUsed = dataObj.uses;
                            }
                        }
                    break;
                    case "long-rest":
                        if (characterAPI[2] && characterAPI[2].startsWith("message")) {
                            message = "Up to ";
                            level = 0;
                            character.classes.forEach(function(cl){ level += cl.level; });
                            if (level>1) { message += Math.floor(level/2).toString(); } else { message += "1"; }
                            message += " Hit Dice";
                            var slots = 0;
                            character.spellSlots.forEach(function(sl) {slots += sl.used;});
                            if (slots > 0) { message += ", " + slots.toString() + " Spell Slot"; if (slots > 1) message += "s"; }
                            slots = 0;
                            character.pactMagic.forEach(function(sl) {slots += sl.used;});
                            if (slots > 0) { message += ", " + slots.toString() + " Pact Magic Slot"; if (slots > 1) message += "s"; }
                            character.actions.class.forEach(function(cl) {
                                         if (cl.limitedUse) {
                                            if (cl.limitedUse.resetType == 1 || cl.limitedUse.resetType == 2) {
                                                message += ", " + cl.name;
                                            }
                                        }
                                    });
                            character.actions.race.forEach(function(cl) {
                                         if (cl.limitedUse) {
                                             if (cl.limitedUse.resetType == 1 || cl.limitedUse.resetType == 2) {
                                                message += ", " + cl.name;
                                             }
                                         }
                                     });
                            character.conditions.forEach(function(cl) {
                                        if (cl.id == 4 && cl.level > 0) {
                                            message += ", 1 Level of Exhaustion";
                                        }
                                    });
                            respObj.message = message;
                        } else {
                            var classes = character.classes;
                            classes.sort(function (a, b) { return a.definition.name < b.definition.name ? -1 : a.definition.name > b.definition.name ? 1 : 0; });
                            level = 0;
                            var hitdice = 1;
                            classes.forEach(function(cl){ level += cl.level; });
                            if (level>1) { hitdice = Math.floor(level/2); }
                            classes.forEach(function(cl){
                                            if (cl.hitDiceUsed <= hitdice) {
                                                hitdice = hitdice - cl.hitDiceUsed;
                                                cl.hitDiceUsed = 0;
                                            } else if (cl.hitDiceUsed > hitdice) {
                                                cl.hitDiceUsed = cl.hitDiceUsed - hitdice;
                                                hitdice = 0;
                                            }
                                        });
                            classes.sort(function (a, b) { return a.isStartingClass ? -1 : b.isStartingClass ? 1 : 0; });
                            character.spellSlots.forEach(function(sl) {sl.used = 0;});
                            character.pactMagic.forEach(function(sl) {sl.used = 0;});
                            character.actions.class.forEach(function(cl) {
                                         if (cl.limitedUse) {
                                            if (cl.limitedUse.resetType == 1 || cl.limitedUse.resetType == 2) {
                                                 cl.limitedUse.numberUsed = 0;
                                            }
                                        }
                                    });
                            character.actions.race.forEach(function(cl) {
                                         if (cl.limitedUse) {
                                             if (cl.limitedUse.resetType == 1 || cl.limitedUse.resetType == 2) {
                                                cl.limitedUse.numberUsed = 0;
                                             }
                                         }
                                     });
                            if (dataObj.resetMaxHpModifier) {
                                character.removedHitPoints = 0;
                            }
                            if (dataObj.adjustConditionLevel) {
                                    idx = character.conditions.findIndex(x=>x.id==4);
                                    if (idx > -1) {
                                        var exhaust = character.conditions[idx];
                                        exhaust.level--;
                                        if (exhaust.level < 1) {
                                            character.conditions.splice(idx,1);
                                        }
                                    }
                            }
                            respObj.result = {
                                "bonusHitPoints": character.bonusHitPoints,
                                "overrideHitPoints": character.overrideHitPoints,
                                "removedHitPoints": character.removedHitPoints,
                                "temporaryHitPoints": character.temporaryHitPoints,
                                "spellSlots": character.spellSlots,
                                "pactMagic": character.pactMagic,
                                "spells": character.spells,
                                "actions": character.actions,
                                "classes": character.classes,
                                "conditions": character.conditions,
                                "modifiers": character.modifiers
                            };
                        }
                        break;
                    case "override-hp":
                        if (characterAPI[2] && characterAPI[2] == "set") {
                            character.overrideHitPoints = dataObj.overrideHitPoints;
                            respObj.result = { "overrideHitPoints": dataObj.overrideHitPoints };
                        }
                    break;
                    case "pactMagic":
                        if (characterAPI[2] && characterAPI[2] == "slot" && characterAPI[3] && characterAPI[3] == "use") {
                            idx = character.pactMagic.findIndex(x=>x.level==dataObj.level);
                            character.pactMagic[idx].used ++;
                            if (character.pactMagic[idx].used < 0) character.pactMagic[idx].used = 0;
                        }
                        if (characterAPI[2] && characterAPI[2] == "slot" && characterAPI[3] && characterAPI[3] == "clear") {
                            idx = character.pactMagic.findIndex(x=>x.level==dataObj.level);
                            character.pactMagic[idx].used --;
                            if (character.pactMagic[idx].used < 0) character.pactMagic[idx].used = 0;
                        }
                    break;
                    case "short-rest":
                        if (characterAPI[2] && characterAPI[2].startsWith("message")) {
                            message = "";
                            character.actions.class.forEach(function(cl) {
                                         if (cl.limitedUse) {
                                            if (cl.limitedUse.resetType == 1) {
                                                if (message.length > 0) message += ", ";
                                                message += cl.name;
                                            }
                                        }
                                    });
                            character.actions.race.forEach(function(cl) {
                                         if (cl.limitedUse) {
                                             if (cl.limitedUse.resetType == 1) {
                                                if (message.length > 0) message += ", ";
                                                message += cl.name;
                                             }
                                         }
                                     });
                            respObj.message = message;
                        } else {
                            if (dataObj.resetMaxHpModifier) {
                                character.removedHitPoints = 0;
                            }
                            Object.keys(dataObj.classHitDiceUsed).forEach(function(id){
                                        character.classes.forEach(function(cl){
                                            if (cl.id == id) {
                                                cl.hitDiceUsed = dataObj.classHitDiceUsed[id];
                                            }
                                        });
                             });
                            character.actions.class.forEach(function(cl) {
                                         if (cl.limitedUse) {
                                            if (cl.limitedUse.resetType == 1) {
                                                 cl.limitedUse.numberUsed = 0;
                                            }
                                        }
                                    });
                            character.actions.race.forEach(function(cl) {
                                         if (cl.limitedUse) {
                                             if (cl.limitedUse.resetType == 1) {
                                                cl.limitedUse.numberUsed = 0;
                                             }
                                         }
                                     });
                            
                            respObj.result = {
                                "bonusHitPoints": character.bonusHitPoints,
                                "overrideHitPoints": character.overrideHitPoints,
                                "removedHitPoints": character.removedHitPoints,
                                "temporaryHitPoints": character.temporaryHitPoints,
                                "spellSlots": character.spellSlots,
                                "pactMagic": character.pactMagic,
                                "spells": character.spells,
                                "actions": character.actions,
                                "classes": character.classes,
                                "conditions": character.conditions,
                                "modifiers": character.modifiers
                            };
                        }
                        break;
                        case "spells":
                        if (characterAPI[2] && characterAPI[2] == "slot" && characterAPI[3] && characterAPI[3] == "use") {
                            idx = character.spellSlots.findIndex(x=>x.level==dataObj.level);
                            character.spellSlots[idx].used ++;
                            if (character.spellSlots[idx].used < 0) character.spellSlots[idx].used = 0;
                        }
                        if (characterAPI[2] && characterAPI[2] == "slot" && characterAPI[3] && characterAPI[3] == "clear") {
                            idx = character.spellSlots.findIndex(x=>x.level==dataObj.level);
                            character.spellSlots[idx].used --;
                            if (character.spellSlots[idx].used < 0) character.spellSlots[idx].used = 0;
                        }
                        break;

                }
            }
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
        this.responseText = jsonfile;
        this.onerror = null;
        this.readyState = 4;
        this.onreadystatechange(4);
    } else if (document.getElementById("character-sheet-target") && this._url.startsWith(document.getElementById("character-sheet-target").getAttribute("data-character-service-base-url")) && typeof jsoncharsvc !== 'undefined'){
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
        if (this._url.includes("vehicles/components?") && typeof jsonvehcomp !== 'undefined') {
            this.response = jsonvehcomp;
            this.responseText = jsonvehcomp;
        } else if (this._url.includes("vehicles?") && typeof jsonvehsvc !== 'undefined') {
            this.response = jsonvehsvc;
            this.responseText = jsonvehsvc;
        } else {
            this.response = jsoncharsvc;
            this.responseText = jsoncharsvc;
        }
        this.onerror = null;
        this.readyState = 4;
        this.onreadystatechange(4);
    } else if (typeof jsoncharsvc !== 'undefined' && jsoncharsvc.definitions && jsoncharsvc.definitions.find(x=>x.type == "vehicle") && jsoncharsvc.definitions.find(x=>x.type == "vehicle").versions && jsoncharsvc.definitions.find(x=>x.type == "vehicle").versions.find(x=>this._url.startsWith(x.baseUrl+"/v"+x.version+"/")) && typeof jsonvehicle !== 'undefined') {
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
        if (this._url.endsWith("/collection")) {
            this.response = jsonvehicle;
            this.responseText = jsonvehicle;
        } else if (this._url.endsWith("/rule-data")) {
            this.response = vehiclerules;
            this.responseText = vehiclerules;
        } else {
            var vehicleID = this._url.substr(this._url.lastIndexOf("/")+1);
            respObj = {};
            idx = jsonvehicle.data.definitionData.findIndex(x=>x.id == vehicleID);
            if (idx > -1) {
                respObj.success = true;
                respObj.message = "Success";
                respObj.data = {
                        "definitionData": jsonvehicle.data.definitionData[idx],
                        "accessTypes": jsonvehicle.data.accessTypes[vehicleID]
                }
            } else {
                respObj.statusCode = 404;
                respObj.message = "Vehicle not found: " + vehicleID;
            }
        }
        this.onerror = null;
        this.readyState = 4;
        this.onreadystatechange(4);
    }
    call.url = this._url;
    call.data = data;
    storedCalls.push(call);
    
    handleOfflineAPI(storedCalls);
};
var send_proto_repl2 = function send(data) {
    if (this._url) {
        if (typeof jsoncharsvc !== 'undefined' && jsoncharsvc.definitions && jsoncharsvc.definitions.find(x=>x.type == "vehicle") && jsoncharsvc.definitions.find(x=>x.type == "vehicle").versions && jsoncharsvc.definitions.find(x=>x.type == "vehicle").versions.find(x=>this._url.startsWith(x.baseUrl+"/v"+x.version+"/")) && typeof jsonvehicle !== 'undefined' && typeof vehiclerules !== 'undefined') {
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
            if (this._url.endsWith("/collection")) {
                this.response = jsonvehicle;
                this.responseText = jsonvehicle;
            } else if (this._url.endsWith("/rule-data")) {
                this.response = vehiclerules;
                this.responseText = vehiclerules;
            } else {
                var vehicleID = this._url.substr(this._url.lastIndexOf("/")+1);
                respObj = {};
                idx = jsonvehicle.data.definitionData.findIndex(x=>x.id == vehicleID);
                if (idx > -1) {
                    respObj.success = true;
                    respObj.message = "Success";
                    respObj.data = {
                            "definitionData": jsonvehicle.data.definitionData[idx],
                            "accessTypes": jsonvehicle.data.accessTypes[vehicleID]
                    }
                } else {
                    respObj.statusCode = 404;
                    respObj.message = "Vehicle not found: " + vehicleID;
                }
            }
            this.onerror = null;
            this.readyState = 4;
            this.onreadystatechange(4);
            return;
        } else if (this._url.startsWith("/api/equipment/list/json") && typeof jsonequip !== 'undefined') {
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
            this.response = jsonequip;
            this.responseText = jsonequip;
            this.onerror = null;
            this.readyState = 4;
            this.onreadystatechange(4);
            return;
        } else if (this._url.startsWith("/api/monsters") && typeof jsonmonster !== 'undefined') {
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
            this.response = jsonmonster;
            this.responseText = jsonmonster;
            this.onerror = null;
            this.readyState = 4;
            this.onreadystatechange(4);
            return;
        } else if (this._url.startsWith("/api/spells/list/json") && typeof jsonspells !== 'undefined') {
            var qregex = /(characterClassId)=?([^&]*)/;
            var qmatch = qregex.exec(this._url);
            if (qmatch && qmatch[2] && jsonspells[qmatch[2]]) {
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
                this.response = jsonspells[qmatch[2]];
                this.responseText = jsonspells[qmatch[2]];
                this.onerror = null;
                this.readyState = 4;
                this.onreadystatechange(4);
                return;
            }
        }
    }
    return send_proto_orig.apply(this,arguments)
}

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
};
                                                                
function updateOnlineStatus() {
    if(navigator.onLine) {
        //        window.webkit.messageHandlers.captureCall.postMessage("Online")
        window.XMLHttpRequest.prototype.open = open_proto_repl;
        window.XMLHttpRequest.prototype.send = send_proto_repl2;
        window.fetch = fetch_orig;
        if (storedCalls.length > 0) {
            handleOfflineAPI(storedCalls);
                //storedCalls[i].req.send(storedCalls[i].data);
        }
        storedCalls = [];
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
        //siteBar[0].remove()
        siteBar[0].style.height = 0;
        siteBar[0].style.display = "none";
    }
    if (siteHeader[0] && siteHeader[0].id != "content") {
        //siteHeader[0].remove();
        siteHeader[0].style.height = 0;
        siteHeader[0].style.display = "none";
    }
    if (document.getElementById('mega-menu-target')) {
        document.getElementById('mega-menu-target').style.height = 0;
        document.getElementById('mega-menu-target').style.display = "none";
    }
    if (document.getElementById('site-main')) {
        var headerSize = parseInt(window.getComputedStyle(document.getElementById('site-main')).paddingTop);
        document.getElementById('site-main').style.paddingTop = 0;
        var charSheet = document.getElementsByClassName('ct-character-sheet-mobile');
        if (charSheet[0]) {
            var padding = parseInt(window.getComputedStyle(charSheet[0]).paddingTop);
            charSheet[0].style.paddingTop = padding - headerSize;
        }
    }
    var tabletCharacterHeader = document.getElementsByClassName('ct-character-header-tablet');
    if (tabletCharacterHeader[0]) {
        document.body.style.backgroundPositionY = getComputedStyle(tabletCharacterHeader[0]).height;
    }
    var desktopCharacterHeader = document.getElementsByClassName('ct-character-header-desktop');
    if (desktopCharacterHeader[0]) {
        document.body.style.backgroundPositionY = getComputedStyle(desktopCharacterHeader[0]).height;
    }
    
    var charHeader = document.getElementsByClassName('ct-character-sheet-mobile__header');
    if (charHeader[0]) {
        charHeader[0].style.top = 0;
        if (document.getElementsByClassName("ct-component-carousel__placeholders")[0]) {
            document.getElementsByClassName("ct-component-carousel__placeholders")[0].style.top = getComputedStyle(charHeader[0]).height;
        }
    }
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
        menuitem.className = "ct-popout-menu__item";
        menuicon.className = "i-menu-portrait";
        menuitema.className = "ct-popout-menu__item-preview";
        menuitemb.className = "ct-popout-menu__item-label";
        menuitemb.innerText="Character List";
        menuitema.appendChild(menuicon);
        menuitem.appendChild(menuitema);
        menuitem.appendChild(menuitemb);
        popoutmenu[0].appendChild(menuitem);
        menuitem.addEventListener("click", function(){
                                  if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.navFunction) {
                                    window.webkit.messageHandlers.navFunction.postMessage("GoHome");
                                  } else if (AndroidApp && AndroidApp.navFunction) {
                                    AndroidApp.navFunction("GoHome");
                                  } else {
                                    window.location='/my-characters';
                                  }});
    }
    if (document.getElementsByClassName("ct-quick-nav--closed")[0]) {
        document.getElementsByClassName("ct-quick-nav--closed")[0].style.top = "";
    }
    if (document.getElementsByClassName("ct-quick-nav--opened")[0]) {
        document.getElementsByClassName("ct-quick-nav--opened")[0].style.top = 0;
    }
    if (document.getElementsByClassName("ct-quick-nav--opened")[0]) {
        document.getElementsByClassName("ct-quick-nav--opened")[0].style.top = 0;
    }
    
    if (document.location.pathname == "/my-characters") {
        if (document.getElementById('footer')) {
//            document.getElementById('footer').remove()
            document.getElementById('footer').style.display = "none";
        }
    }
};
callback.call();
setTimeout(500,callback.call());
var observer = new MutationObserver(callback);
observer.observe(document, config);

