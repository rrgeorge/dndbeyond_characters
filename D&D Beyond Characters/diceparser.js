var mods=[];
var abilities=document.getElementsByClassName('ct-ability-summary');
var saves=document.getElementsByClassName('ct-saving-throws-summary');
if (saves[0]) saves=saves[0].children;
for(var i=0,len=abilities.length;i<len;i++){
    (mod={}).stat=abilities[i].children[0].children[1].innerText;
    for(var s=0,slen=saves.length;s<slen;s++)
        if(saves[s].children[1].innerText.toUpperCase()===mod.stat.toUpperCase()){
            var smod=saves[s].children[2].children[0].children;
            mod.save=Number(smod[0].innerText+smod[1].innerText);
        }
    var modifier=abilities[i].children[1].children[0].children;
    mod.modifier=Number(modifier[0].innerText+modifier[1].innerText);
    mods.push(mod);
}
if (abilities.length == 0) {
    abilities=document.getElementsByClassName('ddbc-ability-summary')
    saves=document.getElementsByClassName('ddbc-saving-throws-summary');
    for(var i=0,len=abilities.length;i<len;i++){
        (mod={}).stat=abilities[i].getElementsByClassName('ddbc-ability-summary__abbr')[0].innerText;
        mod.save=parseInt(saves[0].getElementsByClassName('ddbc-saving-throws-summary__ability--' + mod.stat)[0].getElementsByClassName('ddbc-signed-number')[0].textContent);
        mod.modifier = parseInt(abilities[i].getElementsByClassName('ddbc-signed-number')[0].textContent);
        mods.push(mod)
    }
}
var skills=document.getElementsByClassName('ct-skills__item');
for(i=0,len=skills.length;i<len;i++){
    var mod;
    (mod={}).skill=skills[i].getElementsByClassName("ct-skills__col--skill")[0].innerText;
    mod.modifier=parseInt(skills[i].getElementsByClassName("ct-skills__col--modifier")[0].textContent);
    mods.push(mod);
}
var attacks=document.getElementsByClassName('ct-combat-attack');
if (attacks.length == 0) attacks=document.getElementsByClassName('ddbc-combat-attack');
for(i=0,len=attacks.length;i<len;i++){
    var mod;
    (mod={}).attack=attacks[i].getElementsByClassName("ddbc-combat-attack__label")[0].textContent;
    if (attacks[i].getElementsByClassName("ddbc-combat-attack__tohit").length > 0) {
        mod.tohit = parseInt(attacks[i].getElementsByClassName("ddbc-combat-attack__tohit")[0].textContent)
    } else {
        mod.attack += " (DC: " + attacks[i].getElementsByClassName("ddbc-combat-attack__save-value")[0].textContent + " " + attacks[i].getElementsByClassName("ddbc-combat-attack__save-label")[0].textContent + ")";
    }
    mod.damage=attacks[i].getElementsByClassName("ddbc-damage__value")[0].textContent;
    if (attacks[i].getElementsByClassName("ddbc-damage__value")[1]) mod.damage += "\n" + attacks[i].getElementsByClassName("ddbc-damage__value")[1].textContent;
    if (attacks[i].getElementsByClassName("ddbc-tooltip").length > 0) mod.damagetype = attacks[i].getElementsByClassName("ddbc-tooltip")[0].getAttribute("data-original-title");
        mods.push(mod);
}
var spellList = document.getElementsByClassName('ct-spells-level');
for(s=0,slen=spellList.length;s<slen;s++) {
    var spellLevel = spellList[s].parentNode.parentNode.getElementsByClassName("ct-content-group__header-content")[0].textContent;
    var spells = spellList[s].getElementsByClassName('ct-spells-spell');
    for(i=0,len=spells.length;i<len;i++) {
        if (spells[i].getElementsByClassName('ct-spell-damage-effect__damages').length > 0 || spells[i].getElementsByClassName('ddbc-spell-damage-effect__damages').length > 0) {
            var mod;
            var spellName = spells[i].getElementsByClassName("ct-spells-spell__name")[0].getElementsByClassName("ct-spells-spell__label")[0].textContent;
            var damage = spells[i].getElementsByClassName("ddbc-damage__value")[0].textContent;
            (mod={}).attack=spellLevel + " " + spellName;
            if (spells[i].children[4].children[0].children[0]) {
                var modifier = spells[i].getElementsByClassName("ct-spells-spell__tohit");
                
                if (modifier[0]) {
                    mod.tohit=parseInt(modifier[0].textContent);
                } else {
                    var dc1 = spells[i].getElementsByClassName("ct-spells-spell__save-value")[0].textContent;
                    var dc2 = spells[i].getElementsByClassName("ct-spells-spell__save-label")[0].textContent;
                    mod.attack += " (DC: " + dc1 + " " + dc2 + ")";
                }
            }
            mod.damage=damage;
            if(spells[i].getElementsByClassName("ct-tooltip")[1]) mod.damagetype = spells[i].getElementsByClassName("ct-tooltip")[1].getAttribute("data-original-title");
            mods.push(mod);
        }
    }
}
var sidebar = document.getElementsByClassName("ct-sidebar--visible")[0];
if (sidebar) {
    var newMods = [];
    if (sidebar.getElementsByClassName("ct-spell-name")[0] || sidebar.getElementsByClassName("ddbc-spell-name")[0]) {
        var spellName = sidebar.getElementsByClassName("ct-spell-name")[0]? sidebar.getElementsByClassName("ct-spell-name")[0].innerText : sidebar.getElementsByClassName("ddbc-spell-name")[0].innerText;
        var spellAttacks = sidebar.getElementsByClassName("ct-spell-caster__modifier--damage");
        var properties =  sidebar.getElementsByClassName("ct-property-list__property");
        var spelllvlbx = sidebar.getElementsByClassName("ct-spell-detail__level-school");
        var spelllevel = 0;
        var castlvlbx = sidebar.getElementsByClassName("ct-spell-caster__casting-level-current");
        if (spelllvlbx.length > 0) {
            var lvltxt = spelllvlbx[0].innerText;
            var levelregex = /([0-9]+).* Level/;
            if (levelregex.test(lvltxt)) {
                spelllevel = parseInt(levelregex.exec(lvltxt)[1]);
            }
        }
        var castlevel = spelllevel;
        var castlevelt = "";
        if (castlvlbx.length > 0) {
            var castlvlt = castlvlbx[0].innerText;
            castlevel = parseInt(castlvlt);
            castlevelt = castlvlt + " Level ";
        }
        var save = null;
        for(i=0,len=properties.length;i<len;i++){
            if (properties[i].children[0] && properties[i].children[0].innerText == "Attack/Save:") {
                save = properties[i].children[1].innerText;
            }
        }
        if (spellAttacks.length > 0) {
            for(i=0,len=spellAttacks.length;i<len;i++){
                var mod = {};
                var damage = spellAttacks[i].children[0].innerText;
                mod.attack = spellName;
                mod.damage = damage;
                if (spellAttacks[i].children[2]) mod.attack += " " + spellAttacks[i].children[2].innerText.trim();
                if (spellAttacks[i].children[1] && spellAttacks[i].children[1].children[0] && spellAttacks[i].children[1].children[0].children[0]) {
                    mod.damagetype = spellAttacks[i].children[1].children[0].children[0].getAttribute("data-original-title");
                }
                if (save != null) mod.attack += " (DC: " + save + ")";
                newMods.push(mod);
            }
        } else {
            var spelltext = sidebar.getElementsByClassName('ct-spell-detail__description')[0].innerText;
            var diceregex = /([0-9]+)d([0-9]+)([+-][0-9]*)?/;
            var uplvlregex = /At Higher Levels.*each slot.*above ([0-9]+).*/;
            if (diceregex.test(spelltext)) {
                var mod = {};
                var dicematch = diceregex.exec(spelltext);
                var dice = parseInt(dicematch[1]);
                var die = parseInt(dicematch[2]);
                mod.damage = dicematch[0];
                mod.damagetype = spellName;
                mod.attack = castlevelt + spellName;
                if (uplvlregex.test(spelltext) && castlevel > spelllevel) {
                    var upmatch = uplvlregex.exec(spelltext);
                    if (parseInt(upmatch[1]) < castlevel) {
                        if (diceregex.test(upmatch[0])) {
                            var dmatch = diceregex.exec(upmatch[0]);
                            if (die == parseInt(dmatch[2])) {
                                dice += (parseInt(dmatch[1]) * (castlevel - spelllevel));
                                mod.damage = dice.toString() + "d" + die.toString();
                            }
                        }
                    }
                }
                newMods.push(mod);
            }
        }
    }
    if (newMods.length > 0) mods = newMods;
}
