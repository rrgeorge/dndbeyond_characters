//
//  ViewController.swift
//  D&D Beyond Characters
//
//  Created by Robert George on 7/10/19.
//  Copyright © 2019 Robert George. All rights reserved.
//

import UIKit
import WebKit

struct modifier : Codable {
    let skill:String?
    let stat:String?
    let attack:String?
    let save:Int?
    let modifier:Int?
    let tohit:Int?
    let damage:String?
    let damagetype:String?
}

class ViewController: UIViewController, WKUIDelegate, UIActionSheetDelegate, UIGestureRecognizerDelegate {

    var webView: WKWebView!
    var pinchGesture: UIPinchGestureRecognizer!
    
    var modifiers = [modifier]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let webConfiguration = WKWebViewConfiguration()
        let webDataStore = WKWebsiteDataStore.default()
        webConfiguration.websiteDataStore = webDataStore
        webConfiguration.dataDetectorTypes = []
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.frame = view.frame
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        
        let myURL = URL(string:"https://www.dndbeyond.com/my-characters")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)

        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(self.pinchRecognized(_:)))
        pinchGesture.delegate = self
        self.view.addGestureRecognizer(pinchGesture)
        
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        
    }
    
    @objc func pinchRecognized(_ pinch: UIPinchGestureRecognizer) {
        returnHome()
    }
    
    func returnHome() {
        //let myURL = URL(string:"https://www.dndbeyond.com/my-characters")
        //let myRequest = URLRequest(url: myURL!)
        //webView.load(myRequest)
        webView.goBack()
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake && checkIfCharacterSheet(wV: webView){
            let js = """
var mods=Array();
var abilities=document.getElementsByClassName('ct-ability-summary');
var saves=document.getElementsByClassName('ct-saving-throws-summary');
if (saves[0]) saves=saves[0].children;
for(var i=0,len=abilities.length;i<len;i++){
    (mod=new Object).stat=abilities[i].children[0].children[1].innerText;
    for(var s=0,slen=saves.length;s<slen;s++)
        if(saves[s].children[1].innerText.toUpperCase()===mod.stat.toUpperCase()){
            var smod=saves[s].children[2].children[0].children;
            mod.save=Number(smod[0].innerText+smod[1].innerText)
        }
        var modifier=abilities[i].children[1].children[0].children;
        mod.modifier=Number(modifier[0].innerText+modifier[1].innerText);
        mods.push(mod)
}
var skills=document.getElementsByClassName('ct-skills__item');
for(i=0,len=skills.length;i<len;i++){
    var mod;
    (mod=new Object).skill=skills[i].children[2].innerText;
    var modifier=skills[i].children[3].children[0].children;
    mod.modifier=Number(modifier[0].innerText+modifier[1].innerText);
    mods.push(mod);
}
var attacks=document.getElementsByClassName('ct-combat-attack');
for(i=0,len=attacks.length;i<len;i++){
    var mod;
    (mod=new Object).attack=attacks[i].children[1].children[0].innerText;
    var modifier=attacks[i].children[3].children[0].children[0].children;
    mod.tohit=Number(modifier[0].innerText+modifier[1].innerText);
    mod.damage=attacks[i].children[4].innerText.trim();
    if (attacks[i].getElementsByClassName("ct-tooltip")[0]) mod.damagetype =attacks[i].getElementsByClassName("ct-tooltip")[0].getAttribute("data-original-title")
    mods.push(mod);
}
JSON.stringify(mods);
"""
            webView.evaluateJavaScript(js) { mods,error in
                do {
                    let decoder = JSONDecoder()
                    let json = (mods as! String).data(using: .utf8)!
                    self.modifiers = try decoder.decode([modifier].self, from: json)
                    self.rollDice()
                } catch {
                    print(error)
                }
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        if keyPath == "estimatedProgress" {
            if Float(webView.estimatedProgress) == 1 {
                let js = """
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
}
setTimeout(1000,callback.call());
var observer = new MutationObserver(callback);
observer.observe(document, config);
"""
                self.webView.evaluateJavaScript(js)
            }
        }
    }
    
    func checkIfCharacterSheet(wV: WKWebView) -> Bool {
        let url = wV.url!
        let range = NSRange(location: 0, length: (url.absoluteString as NSString).length)
        let regex = try! NSRegularExpression(pattern: "http[s]?:\\/\\/(www\\.)?dndbeyond.com\\/profile\\/([^\\/]*)\\/characters\\/.*")
        let matches = regex.numberOfMatches(in: url.absoluteString, options: [], range: range)
        if matches > 0 {
            return true
        } else {
            return false
        }
    }
    
    func checkIfCharacterSheetBuilderScores(wV: WKWebView) -> Bool {
        let url = wV.url!
        let range = NSRange(location: 0, length: (url.absoluteString as NSString).length)
        let regex = try! NSRegularExpression(pattern: "http[s]?:\\/\\/(www\\.)?dndbeyond.com\\/profile\\/([^\\/]*)\\/characters\\/.*ability-scores\\/.*")
        let matches = regex.numberOfMatches(in: url.absoluteString, options: [], range: range)
        if matches > 0 {
            return true
        } else {
            return false
        }
    }
    
    func rollWithMod(roll: String, mod: Int) {
        let rolled = Int.random(in: 1...20)
        var dieRoll = "You rolled: "
        if rolled == 1 {
            dieRoll = "Natural 1!" + "(" + String(rolled + mod) + ")"
        } else if rolled == 20 {
            dieRoll = "Natural 20!" + "(" + String(rolled + mod) + ")"
        } else {
            dieRoll = "You rolled " + String(rolled + mod)
        }
        if mod != 0 {
            dieRoll += "\n" + "(Rolled: " + String(rolled) + "+" + String(mod) + ")"
        }
        let rollDialog = UIAlertController(title: roll, message: dieRoll,preferredStyle: .alert)
        rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.view.addSubview(UIView())
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func rollSomeDice(roll: String, die: Int, dice: Int) {
        var rolledString = ""
        var rolled = 0
        var rolledDice: [Int] = []
        var dropped = -1
        if (dice == -3) {
            for _ in 1...4 {
                rolledDice.append(Int.random(in: 1...die))
            }
            rolledDice.sort(by: >)
            dropped = rolledDice.popLast() ?? 0
            rolled = rolledDice.reduce(0, +)
        } else {
            for _ in 1...dice {
                rolledDice.append(Int.random(in: 1...die))
                if rolledString != "" {
                    rolledString += "+"
                }
                rolled = rolledDice.reduce(0, +)
                rolledString += String(rolled)
            }
        }
        var theRoll = "You rolled " + String(rolled)
        if (rolledDice.count > 1) {
            rolledString = rolledDice.map(String.init).joined(separator: "+")
            if dropped > 0 {
                rolledString += ", dropped " + String(dropped)
            }
            theRoll += "\n(Rolled: " + rolledString + ")"
        }
        let rollDialog = UIAlertController(title: roll, message: theRoll,preferredStyle: .alert)
        rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: {action in self.tryToInputStat(stat: String(rolled))}))
        rollDialog.view.addSubview(UIView())
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func tryToInputStat(stat: String) {
        let js = "var element = document.activeElement;\n"
            + "if (element.tagName == \"INPUT\" && element.className == \"builder-field-value\");\n"
            + "element.value=\"" + stat + "\";\n"
        webView.evaluateJavaScript(js)
    }
    
    func rollAttack(roll: String, mod: Int, damage: String, damagetype: String) {
        let rolled = Int.random(in: 1...20)
        var dieRoll = "You rolled: "
        var crit = false
        if rolled == 1 {
            dieRoll = "Natural 1!" + " (" + String(rolled + mod) + ")"
        } else if rolled == 20 {
            dieRoll = "Natural 20!" + " (" + String(rolled + mod) + ")"
            crit = true
        } else {
            dieRoll = "You rolled " + String(rolled + mod)
        }
        if mod != 0 {
            dieRoll += "\n" + "(Rolled: " + String(rolled) + "+" + String(mod) + ")"
        }
        if damage == "--" {
            dieRoll += "\n" + "(This attack has no damage)"
        }
        let rollDialog = UIAlertController(title: roll, message: dieRoll,preferredStyle: .alert)
        if damage != "--" {
            let range = NSRange(location: 0, length: (damage as NSString).length)
            let regex = try! NSRegularExpression(pattern: "([0-9]*)d([0-9]*)([+-][0-9]*)?[\n]?(([0-9]*)d([0-9]*)([+-][0-9]*)?)?")
            let match = regex.firstMatch(in: damage, options: [], range: range)
            var die = 1
            var mod = 0
            var dice = 1
            var addlOpt = false
            var die2 = 1
            var mod2 = 0
            var dice2 = 1
            if match?.numberOfRanges ?? 0 > 0 {
                if let matchrange = match?.range(at:1) {
                    if let diceRange = Range(matchrange, in:damage) {
                        dice = Int(damage[diceRange]) ?? 1
                    }
                }
                if let matchrange = match?.range(at:2) {
                    if let diceRange = Range(matchrange, in:damage) {
                        die = Int(damage[diceRange]) ?? 6
                    }
                }
                if let matchrange = match?.range(at:3) {
                    if let diceRange = Range(matchrange, in:damage) {
                        mod = Int(damage[diceRange]) ?? 0
                    }
                }
                if let matchrange = match?.range(at:4) {
                    if matchrange.length > 0 {
                        addlOpt = true
                    }
                    if let matchrange = match?.range(at:5) {
                        if let diceRange = Range(matchrange, in:damage) {
                            dice2 = Int(damage[diceRange]) ?? 1
                        }
                    }
                    if let matchrange = match?.range(at:6) {
                        if let diceRange = Range(matchrange, in:damage) {
                            die2 = Int(damage[diceRange]) ?? 6
                        }
                    }
                    if let matchrange = match?.range(at:7) {
                        if let diceRange = Range(matchrange, in:damage) {
                            mod2 = Int(damage[diceRange]) ?? 0
                        }
                    }
                }
            }
            if crit { dice *= 2 }
            var damageRoll = String(dice) + "d" + String(die)
            if mod > 0 {
                damageRoll += "+" + String(mod)
            } else if mod < 0 {
                damageRoll += String(mod)
            }
            rollDialog.addAction(UIAlertAction(title: "Roll " + damageRoll + " " + damagetype + " Damage", style: UIAlertAction.Style.default, handler: {action in self.rollDamage(roll: roll, dice: dice, die: die, mod: mod, damagetype: damagetype)}))
            if addlOpt == true {
                if crit { dice2 *= 2 }
                var damageRoll = String(dice2) + "d" + String(die2)
                if mod > 0 {
                    damageRoll += "+" + String(mod)
                } else if mod < 0 {
                    damageRoll += String(mod)
                }
                rollDialog.addAction(UIAlertAction(title: "Roll " + damageRoll + " " + damagetype + " Damage", style: UIAlertAction.Style.default, handler: {action in self.rollDamage(roll: roll, dice: dice2, die: die2, mod: mod2, damagetype: damagetype)}))
            }
        }
        rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.view.addSubview(UIView())
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func rollDamage(roll: String, dice: Int, die: Int, mod: Int, damagetype: String) {
        var rolled = 0
        var rolledString = ""
        for _ in 1...dice {
            rolled += Int.random(in: 1...die)
            if rolledString != "" {
                rolledString += "+"
            }
            rolledString += String(rolled)
        }
        var dieRoll = String(rolled) + " " + damagetype + " Damage!"
        if mod != 0 {
            dieRoll = String(rolled + mod) + " " + damagetype + " Damage!"
        }
        if (rolled + mod) <= 0 {
            dieRoll = "0 Damage!"
        }
        
        if mod < 0 {
            dieRoll += "\n" + "(Rolled: " + rolledString + String(mod) + ")"
        } else if mod > 0 {
            dieRoll += "\n" + "(Rolled: " + rolledString + "+" + String(mod) + ")"
        } else if (rolled + mod) <= 0 {
            dieRoll += "\n" + "(Rolled: " + rolledString + ")"
        }
        let rollDialog = UIAlertController(title: roll, message: dieRoll,preferredStyle: .alert)
        rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.view.addSubview(UIView())
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func rollDice() {
        let rollDialog = UIAlertController(title: "Virtual Dice Roll", message: "What would you like to roll for?",preferredStyle: .actionSheet)
        for mod in modifiers {
            var item = "Roll!"
            if mod.attack != nil {
                item = mod.attack ?? ""
                rollDialog.addAction(UIAlertAction(title: item + " Attack", style: UIAlertAction.Style.default, handler: {action in self.rollAttack(roll: item + " Attack", mod: mod.tohit ?? 0, damage: mod.damage ?? "", damagetype: mod.damagetype ?? "")}))
            } else {
                if mod.stat != nil {
                    switch mod.stat {
                    case "str": item = "Strength"; break;
                    case "dex": item = "Dexterity"; break;
                    case "con": item = "Constitution"; break;
                    case "int": item = "Inteligence"; break;
                    case "wis": item = "Wisdom"; break;
                    case "cha": item = "Charisma"; break;
                    case .none:
                        break
                    case .some(_):
                        break
                    }
                    rollDialog.addAction(UIAlertAction(title: item + " Save", style: UIAlertAction.Style.default, handler: {action in self.rollWithMod(roll: item + " Save", mod: mod.save ?? 0)}))
                } else {
                    item = mod.skill ?? ""
                }
                rollDialog.addAction(UIAlertAction(title: item + " Check", style: UIAlertAction.Style.default, handler: {action in self.rollWithMod(roll: item + " Check", mod: mod.modifier ?? 0)}))
            }
        }
        if checkIfCharacterSheetBuilderScores(wV: webView) {
            rollDialog.addAction(UIAlertAction(title: "Roll 3d6", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "3d6 Roll", die: 6, dice: 3)}))
            rollDialog.addAction(UIAlertAction(title: "Roll 4d6 and Drop Lowest", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "4d6 Roll", die: 6, dice: -3)}))
        }
        if rollDialog.actions.count < 1 {
            rollDialog.addAction(UIAlertAction(title: "Roll a D4", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "D4 Roll", die: 4,dice: 1)}))
            rollDialog.addAction(UIAlertAction(title: "Roll a D6", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "D6 Roll", die: 6,dice: 1)}))
            rollDialog.addAction(UIAlertAction(title: "Roll a D8", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "D8 Roll", die: 8,dice: 1)}))
            rollDialog.addAction(UIAlertAction(title: "Roll a D10", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "D10 Roll", die: 10,dice: 1)}))
            rollDialog.addAction(UIAlertAction(title: "Roll a D12", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "D12 Roll", die: 12,dice: 1)}))
            rollDialog.addAction(UIAlertAction(title: "Roll a D20", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "D20 Roll", die: 20,dice: 1)}))
            rollDialog.addAction(UIAlertAction(title: "Roll a D100", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "D100 Roll", die: 100,dice: 1)}))
        }
        rollDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.view.addSubview(UIView())
        self.present(rollDialog, animated: true, completion: nil)
    }
}
