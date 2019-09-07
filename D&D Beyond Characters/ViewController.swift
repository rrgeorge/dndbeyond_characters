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
    let builder:Bool?
}

struct apiCall : Codable {
    let url:String?
    let data:String?
}

class ViewController: UIViewController, WKUIDelegate, UIActionSheetDelegate, UIGestureRecognizerDelegate {
    var _wknavigation: WKNavigation?
    var _wkurl: URL?
    var webView: WKWebView!
    var pinchGesture: UIPinchGestureRecognizer!
    var swipeGesture: UISwipeGestureRecognizer!
    var _archivebar: UIProgressView?
    var _cobaltAuth: String?
    var _cobaltExpires: Date?
    var modifiers = [modifier]()
    var queuedAPICalls = [apiCall]()
    var reachability: Reachability?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reachability = try! Reachability()

        let webConfiguration = WKWebViewConfiguration()
        let webDataStore = WKWebsiteDataStore.default()
        
        #if targetEnvironment(simulator)
        print ("Loading in SIMULATOR. Setting preauthorized cookie.")
        let cookie = HTTPCookie(properties: [
            .domain: ".dndbeyond.com",
            .path: "/",
            .name: "CobaltSession",
            .secure: true,
            .expires: "Thu, 02 Aug 2029 05:37:39 GMT",
            .value: "eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0..1VKctb1d5ljv7SjHnCVR9w.oNxg88HyNKxy9z4zFiF0x6paelNwwqN0XKCfRB0knOVTmGpCeVfiXiZ2BgVorvLW.bqmbE8Gq02tRmx5pn45rnA",
            ])
            HTTPCookieStorage.shared.setCookie(cookie!)
        webDataStore.httpCookieStore.setCookie(cookie!, completionHandler: nil)
        #endif
        
        webConfiguration.websiteDataStore = webDataStore
        webConfiguration.dataDetectorTypes = []
        let contentController = WKUserContentController()
        contentController.add(self,name: "captureCall")
        contentController.add(self,name: "navFunction")
        contentController.add(self,name: "apiCall")
        webConfiguration.userContentController = contentController

        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        webView.frame = view.frame
        if webView.url == nil {
            loadStaticPage()
        }
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        //webView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        let defaults = UserDefaults.standard

        let myURL = defaults.url(forKey: "activeURL") ?? URL(string:"https://www.dndbeyond.com/my-characters")
        
        queuedAPICalls = defaults.structArrayData(apiCall.self,forKey: "queuedAPICalls")
        
        let myRequest = URLRequest(url: myURL!)
        if webView.url == nil || webView.url?.absoluteString == "about:blank" {
            webView.load(myRequest)
        }

        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.estimatedProgress), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.isLoading), options: .new, context: nil)
        webView.addObserver(self, forKeyPath: #keyPath(WKWebView.url), options: .new, context: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(reachabilityChanged(note:)), name: .reachabilityChanged, object: reachability)
        do{
            try reachability?.startNotifier()
        }catch{
            print("could not start reachability notifier")
        }
        DispatchQueue.global(qos: .background).async {
            do {
                let cacheDir = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("com.dndbeyond.resourcecache", isDirectory: true)
                let cachefiles = try FileManager.default.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil, options: [])
                for cacheFile in cachefiles {
                    let cacheFileAttrib = try FileManager.default.attributesOfItem(atPath: cacheFile.path)
                    let cacheFileCreation = cacheFileAttrib[FileAttributeKey.creationDate] as! Date
                    if cacheFileCreation.timeIntervalSinceNow < -86400 {
                        try FileManager.default.removeItem(atPath: cacheFile.path)
                    }
                }
            } catch let error { print ("Could not clean cache: \(error)") }
        }
    }
    
    @objc func reachabilityChanged(note: Notification) {
        
        let reachability = note.object as! Reachability

        if reachability.connection != .unavailable {
            if self.queuedAPICalls.count > 0 {
            print("Network Available. Should send \(self.queuedAPICalls.count) API Calls");
                DispatchQueue.global(qos: .background).async {
                    var newAPIQueue = [apiCall]()
                    for call in self.queuedAPICalls {
                        let url = call.url ?? ""
                        let data = call.data ?? ""
                        if url.hasPrefix("/api") && url != "/api/character/services" && !url.hasPrefix("/api/config/json") && !url.hasPrefix("/api/subscriptionlevel") {
                            if !self.sendAPICall(url: url, data: data) {
                                newAPIQueue.append(call)
                            }
                        }
                    }
                    self.queuedAPICalls.removeAll()
                    self.queuedAPICalls.append(contentsOf: newAPIQueue)
                    let defaults = UserDefaults.standard
                    defaults.setStructArray(self.queuedAPICalls, forKey: "queuedAPICalls")
                }
            }
        }
    }

    
    func returnHome() {
        let myURL = URL(string:"https://www.dndbeyond.com/my-characters")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            parseToRollDice()
        }
    }
    
    func parseToRollDice () {
        do {
            if (checkIfCharacterSheetBuilderClasses(wV: webView)) {
                let js = """
                var hitdice = [];
                var hdElements = document.getElementsByClassName('hp-manager-hitdice-die');
                if (hdElements.length > 0) {
                    for (var i=0;i<hdElements.length;i++) {
                        var hitdie = hdElements[i].getElementsByClassName('hp-manager-data')[0];
                        if (hitdie) {
                            hitdice.push(hitdie.innerText);
                        }
                    }
                }
                hitdice;
                """
                webView.evaluateJavaScript(js) { result,error in
                    let hitdice = result as! [String]
                    if hitdice.count > 0 {
                        let rollDialog = UIAlertController(title: "Virtual Dice Roll", message: "Roll for HP",preferredStyle: .actionSheet)
                        rollDialog.addAction(UIAlertAction(title: "Roll all dice for HP", style: UIAlertAction.Style.default, handler: {action in self.rollHP(hitdice: hitdice,true)}))
                        rollDialog.addAction(UIAlertAction(title: "Increase HP by one hit die", style: UIAlertAction.Style.default, handler: {action in self.rollHP(hitdice: hitdice)}))
                        rollDialog.addAction(UIAlertAction(title: "Roll Standard Dice", style: UIAlertAction.Style.default, handler: {action in self.rollStandardDice()}))
                        rollDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
                        rollDialog.view.addSubview(UIView())
                        rollDialog.popoverPresentationController?.sourceView = self.view
                        self.present(rollDialog, animated: true, completion: nil)
                    } else {
                        self.rollDice()
                    }
                }
                return
            }
            let js = try String(contentsOfFile: Bundle.main.path(forResource: "diceparser", ofType: "js")!) + "\nJSON.stringify(mods);\n"
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
        } catch {
            print ("MISSING DICE PARSER")
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            if Float(webView.estimatedProgress) == 1 {
                if !(self.webView.url?.absoluteString.hasSuffix(".webarchive"))! {
                    do {
                        let js = try String(contentsOfFile: Bundle.main.path(forResource: "prep", ofType: "js")!)
                        self.webView.evaluateJavaScript(js)
                        if (self.checkIfCharacterSheet(wV: webView)) {
                            let imgjs = """
                            (function() {
                            var maincontent = document.getElementById("content");
                            if (maincontent) {
                                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.navFunction) {
                                    var maincontentobserver = new MutationObserver(function(m,o){window.webkit.messageHandlers.navFunction.postMessage("LoadImages");o.disconnect();});
                                    maincontentobserver.observe(maincontent,{ attributes: true, childList: true, subtree: true });
                                }
                            }
                            })();
                            """
                            self.webView.evaluateJavaScript(imgjs)
                            /*
                            let imgjs = try String(contentsOfFile: Bundle.main.path(forResource: "imgpreload", ofType: "js")!)
                            print("Loading imgjs...")
                            self.webView.evaluateJavaScript(imgjs) { result, error in
                                for res in result as! Array<String> {
                                    print(res)
                                }
                                if self.webView.url != nil && !(self.webView.url?.absoluteString.hasSuffix(".webarchive"))! {
                                    self.makeWebArchive(result as! Array<String>,self.webView.url!)
                                }
                            }*/
                        } else if self.webView.url?.absoluteString == "https://www.dndbeyond.com/my-characters" {
                            let resjs = """
                            var resourceURLS = [];
                            var resources = window.performance.getEntriesByType("resource");
                            resources.forEach(function (resource) {
                                              resourceURLS.push(resource.name);
                                              });
                            resourceURLS;
                            """
                            self.webView.evaluateJavaScript(resjs) { result, error in
                                self.makeWebArchive(result as! Array<String>,self.webView.url!)
                            }
                        }
                    } catch {
                        print ("MISSING ASSETS")
                    }
                }
            }
        } else if keyPath == "URL" {
            if let url = webView.url {
                let range = NSRange(location: 0, length: (url.absoluteString as NSString).length)
                let regex = try! NSRegularExpression(pattern: "http[s]?:\\/\\/(www\\.)?dndbeyond.com[\\/]?$")
                let matches = regex.numberOfMatches(in: url.absoluteString, options: [], range: range)
                if matches > 0 {
                    let myURL = URL(string:"https://www.dndbeyond.com/my-characters")
                    let myRequest = URLRequest(url: myURL!)
                    webView.load(myRequest)
                } else {
                    saveCurrentURL(theURL: webView.url?.absoluteString)
                }
            }
        }
    }
    
    func checkIfCharacterSheet(wV: WKWebView) -> Bool {
        if let url = wV.url {
            if (wV.url?.absoluteString.hasSuffix(".webarchive"))! && (wV.url?.absoluteString.hasPrefix("file://"))! && !(wV.url?.absoluteString.hasSuffix("my-characters.webarchive"))! {
                return true
            }
            let range = NSRange(location: 0, length: (url.absoluteString as NSString).length)
            let regex = try! NSRegularExpression(pattern: "http[s]?:\\/\\/(www\\.)?dndbeyond.com\\/profile\\/([^\\/]*)\\/characters\\/[0-9]*$")
            let matches = regex.numberOfMatches(in: url.absoluteString, options: [], range: range)
            if matches > 0 {
                return true
            } else {
                return false
            }
        } else {
            return true
        }
    }
    
    func checkIfCharacterSheetBuilderScores(wV: WKWebView) -> Bool {
        if let url = wV.url {
            let range = NSRange(location: 0, length: (url.absoluteString as NSString).length)
            let regex = try! NSRegularExpression(pattern: "http[s]?:\\/\\/(www\\.)?dndbeyond.com\\/profile\\/([^\\/]*)\\/characters\\/[0-9]*\\/builder#\\/ability-scores\\/.*")
            let matches = regex.numberOfMatches(in: url.absoluteString, options: [], range: range)
            if matches > 0 {
                return true
            } else {
                return false
            }
        } else {
            return false
        }
    }
    
    func checkIfCharacterSheetBuilderClasses(wV: WKWebView) -> Bool {
        if let url = wV.url {
            let range = NSRange(location: 0, length: (url.absoluteString as NSString).length)
            let regex = try! NSRegularExpression(pattern: "http[s]?:\\/\\/(www\\.)?dndbeyond.com\\/profile\\/([^\\/]*)\\/characters\\/[0-9]*\\/builder#\\/class\\/manage.*")
            let matches = regex.numberOfMatches(in: url.absoluteString, options: [], range: range)
            if matches > 0 {
                return true
            } else {
                return false
            }
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
        if mod > 0 {
            dieRoll += "\n" + "(Rolled: " + String(rolled) + " + " + String(mod) + ")"
        } else if mod < 0 {
            dieRoll += "\n" + "(Rolled: " + String(rolled) + String(mod) + ")"
        }
        let rollDialog = UIAlertController(title: roll, message: dieRoll,preferredStyle: .alert)
        rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.view.addSubview(UIView())
        rollDialog.popoverPresentationController?.sourceView = self.view
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func askHowManyToRoll(roll: String, die: Int) {
        let rollDialog = UIAlertController(title: roll, message: "How many D" + String(die) + "s?",preferredStyle: .alert)
        rollDialog.addTextField() {textField in
            textField.text = "1";
            textField.keyboardType = .numberPad
            textField.delegate = self
        }
        rollDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.addAction(UIAlertAction(title: "Roll!", style: UIAlertAction.Style.default, handler: {action in
            let diceStr = rollDialog.textFields?.first?.text ?? "1"
            var dice = Int(diceStr) ?? 1
            if dice > 999 { dice = 999 }
            else if dice < 1 { dice = 1 }
            self.rollSomeDice(roll: "Roll " + String(dice) + "d" + String(die), die: die,dice:dice)
        }))
        rollDialog.popoverPresentationController?.sourceView = self.view
        self.present(rollDialog, animated: true, completion: {rollDialog.textFields?.first?.becomeFirstResponder()
            rollDialog.textFields?.first?.selectAll(nil)})

    }
    
    func customRoll(roll: String) {
        let rollDialog = UIAlertController(title: roll, message: "Enter the dice you want to roll",preferredStyle: .alert)
        rollDialog.addTextField() {textField in
            textField.keyboardType = .numberPad
            textField.placeholder = "Number of Dice"
            textField.delegate = self
        }
        rollDialog.addTextField() {textField in
            textField.keyboardType = .numberPad
            textField.placeholder = "Number of Sides"
            textField.delegate = self
        }
        rollDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.addAction(UIAlertAction(title: "Roll!", style: UIAlertAction.Style.default, handler: {action in
            let diceStr = rollDialog.textFields?.first?.text ?? "1"
            var dice = Int(diceStr) ?? 1
            if dice > 999 { dice = 999 }
            else if dice < 1 { dice = 1 }
            let dieStr = rollDialog.textFields?.last?.text ?? "1"
            var die = Int(dieStr) ?? 1
            if die > 999 { die = 999 }
            else if dice < 1 { dice = 1 }
            self.rollSomeDice(roll: "Roll " + String(dice) + "d" + String(die), die: die,dice:dice)
        }))
        rollDialog.popoverPresentationController?.sourceView = self.view
        self.present(rollDialog, animated: true, completion: {rollDialog.textFields?.first?.becomeFirstResponder()
            rollDialog.textFields?.first?.selectAll(nil)})
        
    }

    func rollSomeDice(roll: String, die: Int, dice: Int) {
        var rolledString = ""
        var rolled = 0
        var rolledDice: [Int] = []
        var theRoll = "You rolled "
        var resultAction = UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: nil)
        if checkIfCharacterSheetBuilderScores(wV: webView) {
            var dropped = -1
            var theRolls: [Int] = []
            var count = 6
            var title = "Roll for Abilities"
            let js = "var element = document.activeElement;\n"
                + "(element.tagName == \"INPUT\" && element.className == \"builder-field-value\");"
            webView.evaluateJavaScript(js) { ability,error in
                let abilitySelected = ability as? Int ?? 0
                if abilitySelected == 1 {
                    count = 1
                }
                theRoll = "You rolled:"
                for _ in 1...count {
                    rolledDice.removeAll()
                    for _ in 1...dice {
                        rolledDice.append(Int.random(in: 1...die))
                    }
                    if dice == 4 {
                        rolledDice.sort(by: >)
                        dropped = rolledDice.popLast() ?? 0
                    }
                    rolled = rolledDice.reduce(0, +)
                    rolledString = rolledDice.map(String.init).joined(separator: " + ")
                    if dropped > 0 {
                        rolledString += ", dropped " + String(dropped)
                    }
                    theRolls.append(rolled)
                    theRoll += "\n" + String(rolled) + " (Rolled: " + rolledString + ")"
                }
                if (count == 1) {
                    title = "Roll for an Ability"
                    resultAction = UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: {action in self.tryToInputStat(stat: String(theRolls[0]))})
                } else {
                    resultAction = UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: {action in self.tryToInputStats(stat: theRolls)})
                }
                let rollDialog = UIAlertController(title: title, message: theRoll,preferredStyle: .alert)
                rollDialog.addAction(resultAction)
                rollDialog.popoverPresentationController?.sourceView = self.view
                self.present(rollDialog, animated: true, completion: nil)
            }
        } else {
            if (dice == 2 && die == 20) {
                let a = Int.random(in: 1...20)
                let d = Int.random(in: 1...20)
                if a > d {
                    theRoll = "Advantage:\t\t" + String(a) + "\nDisadvantage:\t" + String(d) + "\n\t\tTotal:\t" + String(a+d)
                } else {
                    theRoll = "Advantage:\t\t" + String(d) + "\nDisadvantage:\t" + String(a) + "\n\t\tTotal:\t" + String(a+d)
                }
            } else {
                for _ in 1...dice {
                    rolledDice.append(Int.random(in: 1...die))
                    rolled = rolledDice.reduce(0, +)
                }
                theRoll += String(rolled)
                if (rolledDice.count > 1) {
                    rolledString = rolledDice.map(String.init).joined(separator: " + ")
                    theRoll += "\n(Rolled: " + rolledString + ")"
                }
            }
            let rollDialog = UIAlertController(title: roll, message: theRoll,preferredStyle: .alert)
            rollDialog.addAction(resultAction)
            rollDialog.popoverPresentationController?.sourceView = self.view
            self.present(rollDialog, animated: true, completion: nil)
        }
    }
    
    func tryToInputStat(stat: String) {
        let js = "var element = document.activeElement;\n"
            + "if (element.tagName == \"INPUT\" && element.className == \"builder-field-value\");\n"
            + "element.value=\"" + stat + "\";\n"
        webView.evaluateJavaScript(js)
    }
    
    func tryToInputStats(stat: [Int]) {
        let js = "var stats = document.getElementsByClassName('builder-field-value');\n"
            + "if (stats.length == 6) {\n"
            + " stats[0].focus()\n"
            + " stats[0].value = \"" + String(stat[0]) + "\"\n"
            + " stats[1].focus()\n"
            + " stats[1].value = \"" + String(stat[1]) + "\"\n"
            + " stats[2].focus()\n"
            + " stats[2].value = \"" + String(stat[2]) + "\"\n"
            + " stats[3].focus()\n"
            + " stats[3].value = \"" + String(stat[3]) + "\"\n"
            + " stats[4].focus()\n"
            + " stats[4].value = \"" + String(stat[4]) + "\"\n"
            + " stats[5].focus()\n"
            + " stats[5].value = \"" + String(stat[5]) + "\"\n"
            + " stats[5].blur()\n"
            + "}"
        webView.evaluateJavaScript(js)
    }
    
    func tryToInputHP(hp: String,_ replace: Bool=false) {
        let js = (replace) ? """
        var inputFields = document.getElementsByClassName("builder-field");
        for(i=0;i<inputFields.length;i++) {
            if (inputFields[i].childElementCount == 2) {
                if (inputFields[i].children[0].textContent == "Rolled HP") {
                    var inputBox = inputFields[i].getElementsByTagName("input")[0];
                    if (inputBox) {
                        var currentHP = Number(inputBox.value);
                        inputBox.focus();
                        inputBox.value = String(\(hp));
                        inputBox.blur();
                    }
                }
            }
        }
        """ : """
        var inputFields = document.getElementsByClassName("builder-field");
        for(i=0;i<inputFields.length;i++) {
            if (inputFields[i].childElementCount == 2) {
                if (inputFields[i].children[0].textContent == "Rolled HP") {
                    var inputBox = inputFields[i].getElementsByTagName("input")[0];
                    if (inputBox) {
                        var currentHP = Number(inputBox.value);
                        inputBox.focus();
                        inputBox.value = String(currentHP + \(hp));
                        inputBox.blur();
                    }
                }
            }
        }
        """
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
        if mod > 0 {
            dieRoll += "\n" + "(Rolled: " + String(rolled) + " + " + String(mod) + ")"
        } else if mod < 0 {
            dieRoll += "\n" + "(Rolled: " + String(rolled) + " + " + String(mod) + ")"
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
        rollDialog.popoverPresentationController?.sourceView = self.view
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func rollDamage(roll: String, dice: Int, die: Int, mod: Int, damagetype: String) {
        var rolled = 0
        var rolledString = ""
        for _ in 1...dice {
            let dieRolled = Int.random(in: 1...die)
            rolled += dieRolled
            if rolledString != "" {
                rolledString += " + "
            }
            rolledString += String(dieRolled)
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
            dieRoll += "\n" + "(Rolled: " + rolledString + " + " + String(mod) + ")"
        } else if dice > 1 {
            dieRoll += "\n" + "(Rolled: " + rolledString + ")"
        }
        if (roll.contains("Vicious Mockery")) {
            let insult = VMInsults().insult
            dieRoll = "\n" + insult + "\n\n" + dieRoll
        }
        let rollDialog = UIAlertController(title: roll, message: dieRoll,preferredStyle: .alert)
        rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.view.addSubview(UIView())
        rollDialog.popoverPresentationController?.sourceView = self.view
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func rollDice() {
        let rollDialog = UIAlertController(title: "Virtual Dice Roll", message: "What would you like to roll for?",preferredStyle: .actionSheet)
        for mod in modifiers {
            var item = "Roll!"
            if mod.attack != nil {
                item = mod.attack ?? ""
                if mod.tohit == nil {
                    let damage = mod.damage ?? ""
                    let range = NSRange(location: 0, length: (damage as NSString).length)
                    let regex = try! NSRegularExpression(pattern: "([0-9]+)d([0-9]+)([+-][0-9]*)?")
                    let match = regex.firstMatch(in: damage, options: [], range: range)
                    var die = 1
                    var modifier = 0
                    var dice = 1
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
                                modifier = Int(damage[diceRange]) ?? 0
                            }
                        }
                    }
                    
                    rollDialog.addAction(UIAlertAction(title: item + " Attack", style: UIAlertAction.Style.default, handler: {action in
                        self.rollDamage(roll: item + " Attack", dice: dice, die: die, mod: modifier, damagetype: mod.damagetype ?? "")}))
                } else {
                    rollDialog.addAction(UIAlertAction(title: item + " Attack", style: UIAlertAction.Style.default, handler: {action in self.rollAttack(roll: item + " Attack", mod: mod.tohit ?? 0, damage: mod.damage ?? "", damagetype: mod.damagetype ?? "")}))
                }
            } else {
                if mod.stat != nil {
                    let stat = mod.stat ?? ""
                    switch stat.lowercased() {
                    case "str": item = "Strength"; break;
                    case "dex": item = "Dexterity"; break;
                    case "con": item = "Constitution"; break;
                    case "int": item = "Inteligence"; break;
                    case "wis": item = "Wisdom"; break;
                    case "cha": item = "Charisma"; break;
                    default:
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
            rollDialog.addAction(UIAlertAction(title: "Roll 3d6", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "Roll for Abilities", die: 6, dice: 3)}))
            rollDialog.addAction(UIAlertAction(title: "Roll 4d6 and Drop Lowest", style: UIAlertAction.Style.default, handler: {action in self.rollSomeDice(roll: "Roll for Abilities", die: 6, dice: 4)}))
        }
        if checkIfCharacterSheetBuilderClasses(wV: webView) {
            
        }
        if rollDialog.actions.count < 1 {
            rollStandardDice()
            return
        }
        rollDialog.addAction(UIAlertAction(title: "Roll Standard Dice", style: UIAlertAction.Style.default, handler: {action in self.rollStandardDice()}))
        rollDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.view.addSubview(UIView())
        rollDialog.popoverPresentationController?.sourceView = self.view
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func rollStandardDice() {
        let rollDialog = UIAlertController(title: "Virtual Dice Roll", message: "What would you like to roll for?",preferredStyle: .actionSheet)
        rollDialog.addAction(UIAlertAction(title: "Roll some D4s", style: UIAlertAction.Style.default, handler: {action in self.askHowManyToRoll(roll: action.title!, die:4)}))
        rollDialog.addAction(UIAlertAction(title: "Roll some D6s", style: UIAlertAction.Style.default, handler: {action in self.askHowManyToRoll(roll: action.title!, die:6)}))
        rollDialog.addAction(UIAlertAction(title: "Roll some D8s", style: UIAlertAction.Style.default, handler: {action in self.askHowManyToRoll(roll: action.title!, die:8)}))
        rollDialog.addAction(UIAlertAction(title: "Roll some D10s", style: UIAlertAction.Style.default, handler: {action in self.askHowManyToRoll(roll: action.title!, die:10)}))
        rollDialog.addAction(UIAlertAction(title: "Roll some D12s", style: UIAlertAction.Style.default, handler: {action in self.askHowManyToRoll(roll: action.title!, die:12)}))
        rollDialog.addAction(UIAlertAction(title: "Roll some D20s", style: UIAlertAction.Style.default, handler: {action in self.askHowManyToRoll(roll: action.title!, die:20)}))
        rollDialog.addAction(UIAlertAction(title: "Roll some D100s", style: UIAlertAction.Style.default, handler: {action in self.askHowManyToRoll(roll: action.title!, die:100)}))
        rollDialog.addAction(UIAlertAction(title: "Roll some Custom Dice", style: UIAlertAction.Style.default, handler: {action in self.customRoll(roll: action.title!)}))
        rollDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
        rollDialog.view.addSubview(UIView())
        rollDialog.popoverPresentationController?.sourceView = self.view
        self.present(rollDialog, animated: true, completion: nil)
    }
    
    func rollHP(hitdice: [String], _ replaceHP: Bool = false) {
        let rollDialog = UIAlertController(title: "Virtual Dice Roll", message: "Roll for HP",preferredStyle: .alert)
        var newHP = 0
        var rolledString = ""
        for hitDie in hitdice {
            let range = NSRange(location: 0, length: (hitDie as NSString).length)
            let regex = try! NSRegularExpression(pattern: "([0-9]*)d([0-9]*)")
            let match = regex.firstMatch(in: hitDie, options: [], range: range)
            var die = 1
            var dice = 1
            if match?.numberOfRanges ?? 0 > 0 {
                if let matchrange = match?.range(at:1) {
                    if let diceRange = Range(matchrange, in:hitDie) {
                        dice = Int(hitDie[diceRange]) ?? 1
                    }
                }
                if let matchrange = match?.range(at:2) {
                    if let diceRange = Range(matchrange, in:hitDie) {
                        die = Int(hitDie[diceRange]) ?? 6
                    }
                }
            }
            if replaceHP {
                for i in 1...dice {
                    let dieRoll = (newHP == 0) ? die : Int.random(in: 1...die)
                    newHP += dieRoll
                    if i == 1 {
                        rolledString += String(dice) + "d" + String(die) + ": [" + String(dieRoll)
                    } else {
                        rolledString += " + " + String(dieRoll)
                    }
                }
                rolledString += "] "
            } else {
                rollDialog.addAction(UIAlertAction(title: "Add 1d" + String(die), style: UIAlertAction.Style.default, handler: {
                    action in
                    let hdRoll = Int.random(in: 1...die)
                    let rollDialog = UIAlertController(title: "Virtual Dice Roll", message: String(hdRoll),preferredStyle: .alert)
                    rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: {action in self.tryToInputHP(hp: String(hdRoll))}))
                    rollDialog.view.addSubview(UIView())
                    rollDialog.popoverPresentationController?.sourceView = self.view
                    self.present(rollDialog, animated: true, completion: nil)
                }))
            }
        }
        if replaceHP {
            rollDialog.message = String(newHP) + "\n(Rolled: " + rolledString + ")"
            rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: {action in self.tryToInputHP(hp: String(newHP),true)}))
        } else {
            rollDialog.addAction(UIAlertAction(title: "Thanks!", style: UIAlertAction.Style.default, handler: nil))
        }
        rollDialog.view.addSubview(UIView())
        rollDialog.popoverPresentationController?.sourceView = self.view
        self.present(rollDialog, animated: true, completion: nil)
        
    }

    
    func saveCurrentURL(theURL: String? = "") {
        if let myURL = URL(string:theURL ?? "https://www.dndbeyond.com/my-characters") {
            if myURL.host == "www.dndbeyond.com" || myURL.host == "dndbeyond.com" {
                let defaults = UserDefaults.standard
                defaults.set(myURL, forKey: "activeURL")
            }
        }
    }
    
    func loadStaticPage() {
        loadStaticPage("")
    }
    
    func loadStaticPage(_ message: String) {
        let defaults = UserDefaults.standard
        let myURL = defaults.url(forKey: "activeURL") ?? URL(string:"https://www.dndbeyond.com/my-characters")
        let href = myURL!.absoluteString
        let linkText: String
        if (message.isEmpty) {
            linkText = "Loading"
        } else {
            linkText = "Try Again"
        }
        let html = """
        <html><head><title>D&amp;D Beyond: Offline</title><style>body {font-family: "Roboto Condensed",Roboto,Helvetica,sans-serif;font-size: 18px;} a { text-transform: uppercase;font-weight: bold;color: white; }</style><meta name="viewport" content="width=device-width,initial-scale = 1.0, maximum-scale=1.0,user-scalable=no"></head><body><div style="outline: 0; box-sizing: inherit; position: fixed;height: 100%;width: 100%;top: 0;right: 0;color: #fff;background-color: rgba(35,35,35,.96);display: flex;opacity: 1;visibility: visible;z-index: 60003;"><div style="display: flex;align-items: center;flex-direction: column;justify-content: center;width: 100%;"><div style="background: transparent 50% url('data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4KPCEtLSBHZW5lcmF0b3I6IEFkb2JlIElsbHVzdHJhdG9yIDIwLjAuMCwgU1ZHIEV4cG9ydCBQbHVnLUluIC4gU1ZHIFZlcnNpb246IDYuMDAgQnVpbGQgMCkgIC0tPgo8c3ZnIHZlcnNpb249IjEuMSIgaWQ9IkxheWVyXzEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHg9IjBweCIgeT0iMHB4IgoJIHZpZXdCb3g9IjAgMCAzOTkuNSAxMjYuNyIgc3R5bGU9ImVuYWJsZS1iYWNrZ3JvdW5kOm5ldyAwIDAgMzk5LjUgMTI2Ljc7IiB4bWw6c3BhY2U9InByZXNlcnZlIj4KPHN0eWxlIHR5cGU9InRleHQvY3NzIj4KCS5zdDB7ZmlsbDojRTQwNzEyO30KCS5zdDF7ZmlsbDojRkZGRkZGO30KPC9zdHlsZT4KPGc+Cgk8cGF0aCBjbGFzcz0ic3QwIiBkPSJNMTc4LjUsMzhjMC0wLjYsMC4xLTEuNiwwLjMtMy4zYzAuMi0xLjcsMS4zLTYuNyw1LjctOS41Yy0wLjIsMC0wLjUtMC4xLTAuNy0wLjFjLTAuNiwwLTIuNC0wLjEtNC45LDAuOAoJCWMxLTEuNSw0LjctNCw2LjEtNC43YzAuMS0wLjEsMC4zLTAuMiwwLjQtMC4yYy0xLjYtNS4xLTUtOS4zLTkuOC0xMS44Yy0zLTEuNi02LjEtMi40LTEwLjMtMi41djBoLTguNGMtNi43LDAtOS44LTAuMS0xMi4yLTAuNgoJCWMtMi0wLjUtMy44LTEuNi0zLjgtMS42bC0wLjUtMC4zbDAuMSwwLjZjMCwwLjIsMC41LDQuNyw1LjksOC43YzEsMC44LDEuOCwxLjUsMS44LDQuMXYyNC4yYzAsMi42LTAuNSwzLjMtMS43LDQKCQljLTEuMywwLjgtNCwyLjMtNCwyLjRsLTAuOSwwLjVoMjEuOWM2LjEsMCwxMC0xLDE0LjEtMy44YzAuOC0wLjUsMS41LTEuMSwyLjEtMS42Yy0wLjQtMy4xLDAuMS01LjksMC41LTcuNQoJCUMxODAuMiwzNS43LDE3OS4xLDM2LjcsMTc4LjUsMzh6IE0xNjQuNSwzOC41aC00LjdWMTYuOWg0LjdjNi4yLDAsOS43LDMuOSw5LjcsMTAuOEMxNzQuMiwzNC42LDE3MC43LDM4LjUsMTY0LjUsMzguNXoKCQkgTTIyNS4yLDQzLjljMC40LTAuOCwwLjYtMS44LDAuNi0yLjhjMC0xLTAuMy0yLTAuNy0yLjhsMS4yLDAuMmMwLjgsMC4xLDIuMywxLjEsMi4zLDIuNkMyMjguNiw0Mi45LDIyNi44LDQzLjcsMjI1LjIsNDMuOXoKCQkgTTI0OC40LDQ0LjljLTQuMiwyLjgtOCwzLjgtMTQuMSwzLjhoLTAuMmMxLTEuMiwxLjUtMi44LDEuNS00LjRjMC0yLjMtMS4xLTQuNC0yLjktNS44aDIuNmM2LjIsMCw5LjctMy45LDkuNy0xMC44CgkJYzAtNi45LTMuNS0xMC44LTkuNy0xMC44aC00Ljd2Mi43Yy0wLjctMC4xLTEuMy0wLjItMi0wLjJjLTEuMSwwLTIuNCwwLjItMi43LDAuNGMxLjMtMS4xLDIuOC0xLjYsMy44LTEuOGMtNC40LTEtOC41LDEuNS05LjEsMi4yCgkJYzAuNS0xLjEsMS41LTIuMSwyLjItMi44Yy0xLjQsMC41LTIuNywxLjItMy44LDEuOXYtMS44YzAtMi43LTAuNy0zLjQtMS44LTQuMWMtNS40LTMuOS01LjktOC41LTUuOS04LjdsLTAuMS0wLjZsMC41LDAuMwoJCWMwLDAsMS44LDEuMiwzLjgsMS42YzIuMywwLjUsNS41LDAuNiwxMi4yLDAuNmg4LjR2MGM0LjIsMC4yLDcuMywwLjksMTAuMywyLjVjNi44LDMuNSwxMC44LDEwLjQsMTAuOCwxOC40CgkJYzAsNC45LTEuNiw5LjctNC40LDEzLjFDMjUxLjcsNDIuMywyNTAuMiw0My43LDI0OC40LDQ0Ljl6IE0yMjcuMiwzNi42Yy0xLjUsMC0zLjEsMC4zLTMuMSwwLjNjLTAuMy0wLjMtMi4zLTEuOC0zLjItMgoJCWMxLjYsMS43LDEuMSwzLjUsMC43LDQuMWMtMC4zLDAuNS0wLjksMC44LTEuNCwwLjhjLTAuNCwwLTAuOC0wLjEtMS4yLTAuNHYtOS44YzAuNC0wLjUsMC44LTEuMSwxLjMtMS42YzEuMS0xLjMsMi45LTIuMSw0LjctMi4xCgkJYzEuMSwwLDIuMiwwLjMsMi45LDAuOWwwLjYsMC40bDAuNS0wLjVjMC4zLTAuMywxLTAuNiwxLjctMC45djExLjVDMjI5LjYsMzYuOCwyMjguNSwzNi42LDIyNy4yLDM2LjZ6IE0yMjUuMiwyMwoJCWMtMy43LTAuNS05LjQsMi0xMi4zLDUuNmMwLjYtMi40LDMuMi02LjMsNi40LTguMWMwLDAtMS42LDItMC45LDIuM2MxLDAuNSwzLjYtMy42LDctMy43YzAsMC0yLjUsMS4yLTIsMi4xYzAuNCwwLjYsMi4xLTAuOCw1LTAuOAoJCWMzLjYsMCw2LjgsMi4yLDguMywzLjljLTIuNS0wLjctNy4yLDAuNS04LjYsMS43Yy0yLjEtMS42LTYuMi0xLjQtOC41LDEuM2MtMi45LDMuMy00LjcsNy4yLTUuMiw4LjRjLTEtMC44LTEuOS0xLjUtMi41LTIKCQljLTAuNS0wLjQtMS0wLjYtMS41LTAuOEMyMTMuMSwyOS4xLDIxOC43LDIzLjMsMjI1LjIsMjN6IE0xODYuMiwxMS44Yy0wLjQtNC43LDEuOC03LjMsMi44LTguNGMyLjItMi4zLDUuMi0zLjYsOS43LTMuNAoJCWM3LDAuNCwxMC40LDUuMiwxMC40LDEwLjNjMCwyLjctMS40LDYuMy0zLjQsOC42Yy0wLjEtMC4xLTAuMy0wLjMtMC40LTAuNGMtMS4zLTEuMi0zLjItMi43LTQuNC00LjVjMi40LTMuNSwxLjQtOS0yLjktOQoJCWMtMi43LDAtNC45LDIuOC00LDYuMmMtMC40LDEuNS0wLjYsMy41LTAuMyw1Yy0zLjEtMS42LTQuMS0zLjctNC43LTUuNmMtMC44LDEuNi0xLjMsMy44LTAuNyw1LjkKCQlDMTg4LjMsMTYuNywxODYuNSwxNS4xLDE4Ni4yLDExLjh6IE0xODgsMjAuM2MtMC4zLDEuMS00LjQsMi4zLTYuNCw0LjNjMy0wLjYsNC40LTAuMSw0LjksMS4xYzAuMywwLjktMC4xLDIuMS0wLjMsMy41CgkJYzEtMS4xLDQuNC0zLjQsNi45LTMuOWMtMC42LTAuMi0yLjEtMC41LTIuNy0wLjVjMS44LTIuMSw1LjgtMi44LDgtMi4zYy0xLjQtMC4xLTQuMiwwLjctNS4zLDEuNmMxLDAuMiwxLjksMC40LDIuNywwLjcKCQljLTEuMywwLjUtMywyLjEtMy42LDMuOGMxLjctMS4yLDUuMi0wLjksNS44LDEuNmMwLjQsMS43LTAuOCwzLjItMS40LDMuNWMwLjUsMC4xLDEuNywwLDIuMi0wLjNjLTAuMiwwLjctMS4yLDEuOS0xLjksMi4xCgkJYzEuOCwwLDQuNC0xLjIsNS4xLTIuOWMwLDAtMS4xLDAuNC0xLjYtMC4xYy0wLjUtMC41LDAuMi0yLjcsMC4yLTIuN3MtMC43LDAuOS0xLjMsMC40Yy0wLjYtMC42LDAuMi0yLjYsMC41LTMKCQljLTAuNi0wLjItMi4yLTAuNC0yLjktMC4zYzItMC43LDYuNS0xLjEsNy0wLjJjMC40LDAuNy0wLjYsMi4xLTAuNiwyLjFjMC44LTAuMSwzLjEsMCwzLjksMC45YzAuOCwxLDAuMywyLjMsMC4zLDIuMwoJCWMxLjgtMC45LDMuNC0zLjcsMy02LjVjLTAuMiwwLjYtMSwxLjUtMS44LDEuN2MwLjEtMC45LTAuNi0xLjQtMS4yLTEuNmMwLjMtMS43LTAuNC0zLjktMi45LTYuM2MtMi4xLTIuMS02LjEtNC45LTUuOS04LjYKCQljLTAuNiwwLjgtMS4xLDMuMS0wLjUsNC40YzEuNywyLDUuNCw0LjIsNi4zLDcuNmMtMS42LTQtOS40LTcuMS05LjEtMTIuNmMtMSwxLTEuNiw0LjktMC44LDYuOWMxLjUsMC45LDIuOCwyLjQsMywzLjgKCQljLTEuNC0zLjItNy4xLTMuOC04LjctNy42Yy0wLjQsMS40LTAuMiwzLjEsMC42LDQuMmMwLDAtMS40LTAuNS00LjQtMC40QzE4Ni4xLDE3LjQsMTg4LjIsMTkuMiwxODgsMjAuM3ogTTIwNC4yLDI0LjkKCQljLTEuNywwLTIuMi0xLjMtMi42LTIuN0MyMDMuNiwyMywyMDQuMiwyNC45LDIwNC4yLDI0Ljl6IE0yMjYsNTFjMS4yLDEuMSw0LjEsMS45LDUuNiwxLjJjLTAuOSwxLjYtNS4xLDMuOC05LDIuOAoJCWMtMy43LTEtNS40LTQuNS01LjQtNi44Yy0xLjgsMS44LTEuMyw0LjYsMCw1LjhjLTEuNC0wLjQtMy42LTEuOS00LTQuNmMtMC4zLTIuMywxLTUtMS40LTcuMWMtMS40LTEuMy0zLjctMy4xLTUuMS00LjIKCQljLTMtMi4zLTEuOS00LjEtMi41LTUuM2MtMC41LTEtMS44LTEuNS0yLjUtMi40Yy0wLjgtMC45LTAuNy0yLjItMC4zLTIuOWMtMC4xLDEsMC42LDEuOCwxLjYsMi4yYzEuMSwwLjQsMiwwLjEsMywwLjYKCQljMS4xLDAuNywwLjYsMi40LDEuNCwzLjFjMC43LDAuNSwyLjYtMC4yLDQuMSwxLjFjMS42LDEuMyw1LjEsNC4yLDYuNiw1LjRjMi43LDIuMiw1LjUtMC4zLDQuNi0yLjljMi44LDEuNiwzLjEsNi4yLDAuOCw3LjgKCQljMi4yLDAuNSw2LjEtMC41LDYuMS0zLjZjMC0xLjktMS44LTMuMy0zLTMuNWM0LjUtMC40LDguNCwyLjcsOC40LDYuN0MyMzQuOCw0OC40LDIzMC43LDUxLjYsMjI2LDUxeiBNMjExLjEsNDIuOAoJCWMwLjEsMC4xLDAuMiwwLjIsMC4zLDAuM2MtMi40LDQuOS02LjksMTEuMi0xNS41LDExLjJjLTMuMSwwLTUuOS0xLjEtNy45LTIuNmMtMC43LTAuNS0xLjMtMS4xLTEuOC0xLjhoMGMwLDAsMCwwLDAsMAoJCWMtMC4zLTAuNC0wLjYtMC43LTAuOS0xLjFjLTAuNC0wLjUtMC43LTAuNS0wLjktMC4yYy0wLjQsMC42LDAuMywyLjUsMC4zLDIuNWMtNi44LTYuNC0zLjMtMTUuOC0zLjItMTYuMmMwLjQtMS4yLDAtMS40LTAuNC0xLjIKCQljLTAuNiwwLjItMS4zLDEuMi0xLjMsMS4yYzAuNS01LjcsNS44LTkuMiw1LjgtOS4yYzAsMCwwLjEsMC4xLDAuMSwwLjFjMC42LDAuOS0wLjMsMi0wLjQsNS42YzEtMS40LDQuOS00LjEsNy4xLTQuOQoJCWMtMC43LDAuOS0xLjMsMi4yLTEuMyw0LjFjMCwwLDEuNi0xLjgsMy42LTEuOGMwLjUsMCwxLDAuMSwxLjQsMC4zYy03LjYsNy40LTQuNCwxNi42LDIsMTYuNmMzLjYsMCw3LjItNCw4LjctNi43CgkJQzIwNy45LDQwLjEsMjA5LjgsNDEuNywyMTEuMSw0Mi44eiIvPgoJPHBhdGggY2xhc3M9InN0MSIgZD0iTTIyMS4zLDY0LjdjLTE3LjcsMC0zNS41LDEyLjEtMzUuNSwzMS40YzAsMjAsMTcuNywzMC42LDM1LjMsMzAuNmMxNy44LDAsMzUuNi0xMC41LDM1LjYtMzAuNgoJCUMyNTYuNyw3Ni4zLDIzOSw2NC43LDIyMS4zLDY0Ljd6IE0yMjEuMSwxMTMuMWMtNy44LDAtMTcuNC01LjktMTcuNC0xN2MwLTExLjQsOS0xNy41LDE3LjUtMTcuNWM3LjgsMCwxNy43LDUuNCwxNy43LDE3LjcKCQlDMjM4LjksMTA4LDIyOSwxMTMuMSwyMjEuMSwxMTMuMXoiLz4KCTxwYXRoIGNsYXNzPSJzdDEiIGQ9Ik0zMDIuNyw2Ni42aDI0LjVsLTQuNiw1LjJ2NTMuMmgtMTMuM2MtMi41LTcuOS0yOC0yOC4xLTMwLjMtMzQuN2gtMC4ydjI5LjZsNC42LDUuMWgtMjQuM2w0LjUtNS4yVjcxLjgKCQlsLTQuNi01LjNoMTkuN2MxLjgsNS45LDI0LjgsMjIuOCwyOC4yLDMxLjhoMC4yVjcxLjhMMzAyLjcsNjYuNnoiLz4KCTxwYXRoIGNsYXNzPSJzdDEiIGQ9Ik0zNjEuOCw2NS4zYy0xMi45LDAtMjUsMC44LTMxLjQsMS4zbDQuNiw1LjF2NDguMmwtNC42LDUuMWM2LjUsMC41LDE5LjMsMS4zLDMyLjIsMS4zCgkJYzI2LjMsMCwzNi45LTEyLjksMzYuOS0zMC41QzM5OS41LDc3LjUsMzg1LDY1LjMsMzYxLjgsNjUuM3ogTTM2Mi40LDExM2MtNCwwLTcuNi0wLjItMTAtMC41Vjc5LjJjMi43LTAuMyw0LjgtMC42LDkuMi0wLjYKCQljMTEuMywwLDIwLDQuOCwyMCwxN0MzODEuNiwxMDcuMywzNzMuNywxMTMsMzYyLjQsMTEzeiIvPgoJPHBvbHlnb24gY2xhc3M9InN0MSIgcG9pbnRzPSIxNjQuMiwxMTkuOCAxNjguNywxMjQuOSAxNDIuMSwxMjQuOSAxNDYuOSwxMTkuOCAxNDYuOCwxMDcuNyAxMTkuMyw2Ni42IDE0Ny4zLDY2LjYgMTQzLjMsNzEuMSAKCQkxNTYuNCw5NC4zIDE1Ni42LDk0LjMgMTY5LjQsNzEuMSAxNjUuNiw2Ni42IDE5MS42LDY2LjYgMTY0LjEsMTA3LjkgCSIvPgoJPHBvbHlnb24gY2xhc3M9InN0MSIgcG9pbnRzPSIxMjQuOCwxMTEuNyAxMTYsMTI0LjkgMTE2LjEsMTI0LjkgNjUuMywxMjQuOSA2OS45LDExOS44IDY5LjksNzEuNyA2NS4zLDY2LjYgMTExLjIsNjYuNSAxMTEuMiw2Ni42IAoJCTEyMCw3OS43IDg3LjMsNzkuNyA4Ny4zLDg5IDExMC41LDg5IDEwMS43LDEwMi4yIDEwMS43LDEwMi4zIDg3LjMsMTAyLjIgODcuMywxMTEuOCAJIi8+Cgk8cGF0aCBjbGFzcz0ic3QxIiBkPSJNNTguOCw5OS4zYy0yLjItMi4xLTUuMS0zLjctOC45LTQuOGMxLjUtMC40LDIuOS0xLDQuMi0xLjhjMS4zLTAuOCwyLjMtMS42LDMuMi0yLjZjMC45LTEsMS42LTIsMi0zLjEKCQlDNTkuOCw4Niw2MCw4NSw2MCw4NHYtMS45YzAtMi4zLTAuNS00LjUtMS42LTYuNGMtMS4xLTEuOS0yLjYtMy42LTQuNi00LjljLTItMS40LTQuOC0yLjQtNy42LTMuMmMtMi44LTAuNy01LjktMS4xLTkuMy0xLjFoLTI3CgkJSDcuMUgxLjlsNS4yLDUuNHYxOC40SDBsNy4xLDkuMXYyMC4xbC01LjIsNS40aDUuMmgyLjhoMjguOGM2LjksMCwxMi45LTEuMiwxNy4xLTMuN2M0LjItMi41LDYuMi02LjEsNi4yLTExdi0zLjMKCQlDNjIsMTAzLjksNjAuOSwxMDEuNCw1OC44LDk5LjN6IE0yNC4xLDc3LjNoOS40YzIuNywwLDQuOSwwLjQsNi42LDEuMmMxLjcsMC44LDIuNSwyLjMsMi41LDQuNXYxLjljMCwxLjctMC42LDMtMS45LDQKCQljLTEuMywxLTMsMS41LTUuMiwxLjVIMjQuMVY3Ny4zeiBNNDQuNiwxMDguNWMwLDEuMi0wLjIsMi4yLTAuNywyLjljLTAuNSwwLjctMS4xLDEuMy0xLjksMS44Yy0wLjgsMC40LTEuNywwLjctMi44LDAuOQoJCWMtMS4xLDAuMS0yLjIsMC4yLTMuMywwLjJIMjQuMXYtMTQuMWgxMS45YzIuMiwwLDQuMSwwLjUsNS45LDEuNWMxLjcsMSwyLjYsMi4zLDIuNiw0VjEwOC41eiIvPgo8L2c+Cjwvc3ZnPgo=') no-repeat;background-size: auto 70px;height: 90px;width: 100%;margin-bottom: 10px;"></div><div class="sync-blocker-anim"></div><p>\(message)</p><p><a href="\(href)">\(linkText)</a></p></div></div></body></html>
        
        """
        webView.loadHTMLString(html, baseURL:nil)

    }
    
    func makeWebArchive(_ urls: Array<String>, _ activeUrl: URL) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.sync {
                self._archivebar = UIProgressView(progressViewStyle: .bar)
                let frame = self.view.frame
                self._archivebar!.frame = CGRect(x: 0,y: frame.maxY-5,width: frame.width,height: 5)
                self._archivebar!.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
                self._archivebar!.isHidden = false
                self._archivebar!.progress = 0
                self.view.addSubview(self._archivebar!)
            }
            let itemcount = Float(urls.count + 6)
            var itemNo = Float(0.0);
            DispatchQueue.main.sync { self._archivebar!.progress = itemNo/itemcount }
            let archiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((activeUrl.pathComponents.last)!).appendingPathExtension("webarchive")
            var urls = urls
            var homebrew  = false
            var classIds = Array<NSNumber>.init()
            var sources = ""
            do {
                //let boundry = "--mhtml-part-boundry--"
                //var mhtml = "From: <my characters>\nSnapshot-Content-Location: \(activeUrl.absoluteString)\nSubject: Character\nMIME-Version: 1.0\nContent-Type: multipart/related; type=\"text/html\";boundary=\"\(boundry)\"\n\n"
                let maincontents = try NSMutableString(contentsOf: activeUrl, encoding: String.Encoding.utf8.rawValue)
                var headcontents = String("\n<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge,chrome=1\">\n")
                headcontents.append("<script type=\"text/javascript\">\n")
                
                if activeUrl.pathComponents.last != "my-characters" {
                    let jsonURL = activeUrl.appendingPathComponent("/json")
                    let contents = try String(contentsOf:jsonURL)
                    itemNo = 1.0
                    DispatchQueue.main.sync {
                        if self._archivebar != nil {
                            self._archivebar!.progress = itemNo/itemcount
                        }
                    }
                    let jsoncharsvc = try String(contentsOf:URL(string:"https://www.dndbeyond.com/api/character/services")!)
                    itemNo = 2.0
                    DispatchQueue.main.sync {
                        if self._archivebar != nil {
                            self._archivebar!.progress = itemNo/itemcount
                        }
                    }
                    let jsonconfig = try String(contentsOf:URL(string:"https://www.dndbeyond.com/api/config/json?v=2.4.2")!)
                    itemNo = 3.0
                    DispatchQueue.main.sync {
                        if self._archivebar != nil {
                            self._archivebar!.progress = itemNo/itemcount
                        }
                    }
                    if let charJSON = try JSONSerialization.jsonObject(with: contents.data(using: .utf8)!, options:[] ) as? [String: Any] {
                        if let charObj = charJSON["character"] as? [String: Any] {
                            let prefs = charObj["preferences"] as! [String: Any]
                            homebrew = prefs["useHomebrewContent"] as! Bool
                            let actSrc = charObj["activeSourceCategories"] as! [Int]
                            sources = actSrc.map(String.init).joined(separator: ",")
                            let classes = charObj["classes"] as! [Any]
                            for oneClass in classes {
                                let classId = (oneClass as! [String: Any])["id"] as! NSNumber
                                let classDef = (oneClass as! [String: Any])["definition"] as! [String: Any]
                                if classDef["canCastSpells"] as! Bool {
                                    classIds.append(classId)
                                }
                            }
                        }
                    }
                    let apiQueryString = urls[0] + "&useHomebrew=" + String(homebrew) + "&activeSourceCategories=" + sources
                    urls.remove(at: 0)
                    headcontents.append("\njsonfile = ")
                    headcontents.append(contents)
                    headcontents.append(";\njsonconfig = ")
                    headcontents.append(jsonconfig)
                    headcontents.append(";\njsoncharsvc = ")
                    headcontents.append(jsoncharsvc)
                    headcontents.append(";\njsonequip = ")
                    let jsonequip = try String(contentsOf:(URL(string: "https://www.dndbeyond.com/api/equipment/list/json?" + apiQueryString)!))
                    headcontents.append(jsonequip)
                    itemNo = 4.0
                    DispatchQueue.main.sync {
                        if self._archivebar != nil {
                            self._archivebar!.progress = itemNo/itemcount
                        }
                    }
                    if classIds.count > 0 {
                        headcontents.append(";\njsonspells = []")
                        for classId in classIds {
                            headcontents.append(";\njsonspells[\"" + classId.stringValue + "\"] = ")
                            let jsonspell = try String(contentsOf:(URL(string: "https://www.dndbeyond.com/api/spells/list/json?" + apiQueryString + "&characterClassId=" + classId.stringValue)!))
                            headcontents.append(jsonspell)
                        }
                    }
                    headcontents.append(";\n\n")
                    itemNo = 5.0
                    DispatchQueue.main.sync {
                        if self._archivebar != nil {
                            self._archivebar!.progress = itemNo/itemcount
                        }
                    }
                }
                let jsprep = try String(contentsOf:Bundle.main.url(forResource: "prep", withExtension: "js")!)
                headcontents.append(jsprep)
                headcontents.append("""
                window.removeEventListener('offline', updateOnlineStatus, false);
                window.removeEventListener('online', updateOnlineStatus, false);
                """)
                headcontents.append("\n</script>\n</head>")
                let crossoriginrange = maincontents.range(of: " crossorigin ")
                if crossoriginrange.location != NSNotFound {
                    maincontents.replaceCharacters(in: crossoriginrange, with: " ")
                }
                let headclosingtag = maincontents.range(of: "</head>", options: .caseInsensitive)
                if headclosingtag.location != NSNotFound {
                    maincontents.replaceCharacters(in: headclosingtag, with: headcontents)
                }
                let fullcontents = maincontents.data(using: String.Encoding.utf8.rawValue)!
                //mhtml.append("--\(boundry)\nContent-Type: text/html\nContent-ID: <mainframe@mhtml>\nContent-Transfer-Encoding: base64\nContent-Location: \(activeUrl.absoluteString)\n\n")
                //mhtml.append(fullcontents.base64EncodedString())
                let mainres = WebArchiveResource(url: activeUrl,data: fullcontents,mimeType: "text/html")
                var webarchive = WebArchive(resource: mainres)
                itemNo = 6.0
                DispatchQueue.main.sync {
                    if self._archivebar != nil {
                        self._archivebar!.progress = itemNo/itemcount
                    }
                }
                for url in urls {
                    let range = NSRange(location: 0, length: (url as NSString).length)
                    let regex = try! NSRegularExpression(pattern: "^http[s]?:\\/\\/((www\\.|media\\.)?dndbeyond.com|fonts.googleapis.com|media-waterdeep.cursecdn.com|fonts.gstatic.com|apis.google.com|secure.gravatar.com)\\/")
                    let matches = regex.numberOfMatches(in: url, options: [], range: range)
                    if matches > 0 {
                        var mimetype: String
                        if url.hasSuffix(".svg") || url.contains("/svg/") {
                            mimetype = "image/svg+xml"
                        } else if url.hasSuffix(".jpg") || url.hasSuffix(".jpeg") {
                            mimetype = "image/jpeg"
                        } else if url.hasSuffix(".png") {
                            mimetype = "image/png"
                        } else if url.hasSuffix(".js") || url.contains("jquery") || url.contains("cobalt") || url.contains("waterdeep") {
                            mimetype = "text/javascript"
                        } else if url.hasSuffix(".css") || url.contains("css") {
                            mimetype = "text/css"
                        } else if url.hasSuffix(".json") || url.contains("json") {
                            mimetype = "application/json"
                        } else if url.hasSuffix(".html") || url.hasSuffix(".htm") {
                            mimetype = "text/html"
                        } else {
                            mimetype = "application/octet-stream"
                        }
                        if let thisURL = URL(string: String(url).addingPercentEncoding(withAllowedCharacters:.urlQueryAllowed)!) {
                            do {
                                let cacheDir = try! FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("com.dndbeyond.resourcecache", isDirectory: true)
                                let cachedURL = cacheDir.appendingPathComponent(String(url).addingPercentEncoding(withAllowedCharacters: .alphanumerics)!)
                                var isDir : ObjCBool = false
                                if !FileManager.default.fileExists(atPath: cacheDir.path) {
                                    try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: false, attributes:nil)
                                }
                                if FileManager.default.fileExists(atPath: cachedURL.path) {
                                    let resContents: Data
                                    let attrib = try FileManager.default.attributesOfItem(atPath: cachedURL.path)
                                    let created = attrib[FileAttributeKey.creationDate] as! Date
                                    if (created.timeIntervalSinceNow > 14400) {
                                        try FileManager.default.removeItem(atPath: cachedURL.path)
                                        resContents = try Data(contentsOf:thisURL)
                                        if FileManager.default.fileExists(atPath: cacheDir.path, isDirectory:&isDir) && isDir.boolValue {
                                            try resContents.write(to: cachedURL)
                                        }
                                    } else {
                                        resContents = try Data(contentsOf:cachedURL)
                                    }
                                    let resource = WebArchiveResource(url:thisURL,data: resContents,mimeType: mimetype)
                                    //mhtml.append("--\(boundry)\nContent-Type: \(mimetype)\nContent-Transfer-Encoding: base64\nContent-Location: \(thisURL.absoluteString)\n\n")
                                    //mhtml.append(resContents.base64EncodedString())
                                    webarchive.addSubresource(resource)
                                } else {
                                    let resContents = try Data(contentsOf:thisURL)
                                    if FileManager.default.fileExists(atPath: cacheDir.path, isDirectory:&isDir) && isDir.boolValue {
                                        try resContents.write(to: cachedURL)
                                    }
                                    //mhtml.append("--\(boundry)\nContent-Type: \(mimetype)\nContent-Transfer-Encoding: base64\nContent-Location: \(thisURL.absoluteString)\n\n")
                                    //mhtml.append(resContents.base64EncodedString())
                                    let resource = WebArchiveResource(url:thisURL,data: resContents,mimeType: mimetype)
                                    webarchive.addSubresource(resource)
                                }
                                DispatchQueue.main.sync {
                                    if self._archivebar != nil {
                                        self._archivebar!.progress = itemNo/itemcount
                                    }
                                }
                                itemNo += 1
                            } catch let error {
                                print ("Could not cache " + url + ":" + error.localizedDescription)
                            }
                        } else {
                            print("Invalid URL: " + url)
                        }
                    }
                }
                let encoder: PropertyListEncoder = {
                    let plistEncoder = PropertyListEncoder()
                    plistEncoder.outputFormat = .binary
                    return plistEncoder
                }()
                let webArch = try encoder.encode(webarchive)
                try webArch.write(to: archiveURL)
                DispatchQueue.main.sync {
                    if self._archivebar != nil {
                        self._archivebar!.progress = itemNo/itemcount
                        self._archivebar!.progress = 1
                        self._archivebar!.isHidden = true
                        self._archivebar!.removeFromSuperview()
                        self._archivebar = nil
                    }
                }
                //mhtml.append("--\(boundry)--")
                //try mhtml.write(to: archiveURL.appendingPathExtension(".mhtml"), atomically: true, encoding: String.Encoding.utf8)
            } catch let error { print(error) }
        }
    }
    func sendAPICall(url: String,data: String) -> Bool {
        if self._cobaltAuth == nil || self._cobaltExpires == nil || self._cobaltExpires!.timeIntervalSinceNow < TimeInterval(10.00) {
            /*
             Get Token:
             curl 'https://auth-service.dndbeyond.com/v1/cobalt-token'
             -H 'Cookie: CobaltSession=eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0..1VKctb1d5ljv7SjHnCVR9w.oNxg88HyNKxy9z4zFiF0x6paelNwwqN0XKCfRB0knOVTmGpCeVfiXiZ2BgVorvLW.bqmbE8Gq02tRmx5pn45rnA;' --data ''
             */
            let emptyData = ("").data(using: String.Encoding.utf8)
            let authURL = URL(string:"https://auth-service.dndbeyond.com/v1/cobalt-token")!
            var cobaltRequest = URLRequest(url: authURL)
            
            cobaltRequest.httpMethod = "POST"
            cobaltRequest.httpShouldHandleCookies = true
            cobaltRequest.httpBody = emptyData
            
            struct Cobalt: Codable {
                let token: String
                let ttl: Int
            }
            
            let (rdata, response, error) = URLSession.shared.syncDataTask(urlrequest: cobaltRequest)
            
            if let error = error {
                print("Synchronous task ended with error: \(error)")
            } else {
                if let rdata = rdata {
                    do {
                        let res = try JSONDecoder().decode(Cobalt.self, from: rdata)
                        self._cobaltAuth = "Bearer " + res.token
                        self._cobaltExpires = Date(timeIntervalSinceNow: TimeInterval(res.ttl))
                        let response = response as? HTTPURLResponse
                        print("\(String(describing: response?.statusCode)) New Token retreived until \(String(describing: self._cobaltExpires)) -> \(String(describing: self._cobaltAuth))")
                        return sendAPICall(url: url,data: data)
                    } catch {
                        print("Error")
                        return false
                    }
                }
            }
        } else {
            let apiURL = URL(string:"https://www.dndbeyond.com" + url)!
            print(apiURL.absoluteString)
            do {
                let dataJSON = try JSONSerialization.jsonObject(with: data.data(using: .utf8)!, options: []) as! [String: Any]
                if let csrfToken = dataJSON["csrfToken"] as? String {
                    let cookie = HTTPCookie(properties: [
                        .domain: "www.dndbeyond.com",
                        .path: "/",
                        .name: "RequestVerificationToken",
                        .value: csrfToken,
                        ])
                    HTTPCookieStorage.shared.setCookie(cookie!)
                }
                var apiRequest = URLRequest(url: apiURL)
                apiRequest.httpMethod = "POST"
                apiRequest.httpShouldHandleCookies = true
                apiRequest.addValue(_cobaltAuth!, forHTTPHeaderField: "Authorization")
                apiRequest.addValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
                apiRequest.httpBody = data.data(using: String.Encoding.utf8)
                let (retdata, response, error) = URLSession.shared.syncDataTask(urlrequest: apiRequest)
                if let error = error {
                    print("Synchronous task ended with error: \(error)")
                    return false
                } else {
                    let response = response as? HTTPURLResponse
                    print ("Received (\(response?.statusCode ?? 0)): \(String(data: retdata!, encoding: .utf8) ?? "??")")
                    return true
                }
            } catch let e {
                print ("Could not send API call: \(e)")
                return false
            }
            /*
             Send API Call:
             curl -v 'https://www.dndbeyond.com/api/character/inspiration'
             -H 'Content-Type: application/json;charset=utf-8'
             -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJodHRwOi8vc2NoZW1hcy54bWxzb2FwLm9yZy93cy8yMDA1LzA1L2lkZW50aXR5L2NsYWltcy9uYW1laWRlbnRpZmllciI6IjEwMTA3ODMyMSIsImh0dHA6Ly9zY2hlbWFzLnhtbHNvYXAub3JnL3dzLzIwMDUvMDUvaWRlbnRpdHkvY2xhaW1zL25hbWUiOiJycl9nZW9yZ2UiLCJodHRwOi8vc2NoZW1hcy5taWNyb3NvZnQuY29tL3dzLzIwMDgvMDYvaWRlbnRpdHkvY2xhaW1zL3JvbGUiOlsiUmVnaXN0ZXJlZCBVc2VycyIsIlBIQiBCdXllciIsIkRNRyBCdXllciIsIk1NIEJ1eWVyIiwiTE1vUCBCdXllciIsIlNDQUcgQnV5ZXIiLCJWb2xvIEJ1eWVyIiwiWEd0RSBCdXllciIsIk1Ub0YgQnV5ZXIiLCJMZWdlbmRhcnkgQnVuZGxlIDAyMTgiLCJXRG90TU0gQnV5ZXIiLCJMTG9LIEJ1eWVyIiwiSGZ0VCBCdXllciIsIkRvSVAgQnV5ZXIiXSwibmJmIjoxNTY3NTQwODAyLCJleHAiOjE1Njc1NDExMDIsImlzcyI6ImRuZGJleW9uZC5jb20iLCJhdWQiOiJkbmRiZXlvbmQuY29tIn0.OfOgu0eOD_VrWNMbld_5nc7rxPuBQPw6BUYlXsu6Z1A' -H 'Connection: keep-alive' -H 'Referer: https://www.dndbeyond.com/profile/rr_george/characters/13974199'
             -H 'Cookie: CobaltSession=eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0..1VKctb1d5ljv7SjHnCVR9w.oNxg88HyNKxy9z4zFiF0x6paelNwwqN0XKCfRB0knOVTmGpCeVfiXiZ2BgVorvLW.bqmbE8Gq02tRmx5pn45rnA; RequestVerificationToken=40852781-70bf-4bc5-a7ac-95c8e4e9189a;'
             --data '{"username":"rr_george","characterId":13974199,"csrfToken":"40852781-70bf-4bc5-a7ac-95c8e4e9189a","inspiration":false}'
             */
        }
        return false
    }
}

extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print(error)
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation: WKNavigation!, withError: Error) {
        let errNo = (withError as NSError).code
        let errorDesc = withError.localizedDescription
        if didFailProvisionalNavigation == _wknavigation {
            let urlString = _wkurl?.absoluteString ?? "unknown url"
            if (_wkurl != nil) && urlString.hasSuffix(".webarchive") && errNo == EPERM {
                print("Loading webarchive: " + _wkurl!.absoluteString)
                webView.loadFileURL(_wkurl!, allowingReadAccessTo: _wkurl!)
            } else {
                print("Failed to load: " + urlString + "(\(errNo):\(errorDesc))")
            }
            //print("Failed:" + errorDesc + " (" + String(errNo) + ") " + "->" + urlString)
        }
        _wknavigation = nil
        if errNo == NSURLErrorNotConnectedToInternet {
            let defaults = UserDefaults.standard
            let myURL: URL?
            if _wkurl == nil {
                myURL = defaults.url(forKey: "activeURL") ?? URL(string:"https://www.dndbeyond.com/my-characters")
            } else {
                myURL = _wkurl
            }
            let archiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((myURL?.pathComponents.last)!).appendingPathExtension("webarchive")
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                guard let webArchive = try? Data(contentsOf: archiveURL) else { loadStaticPage(errorDesc); return }
                webView.stopLoading()
                webView.load(webArchive, mimeType: "application/x-webarchive", characterEncodingName: String.Encoding.utf8.description, baseURL: archiveURL)
                //webView.loadFileURL(archiveURL, allowingReadAccessTo: archiveURL)
            } else if (myURL?.pathComponents.last)! != "my-characters" {
                let alertDialog = UIAlertController(title: "Character Not Available", message: "Sorry, but that character is not available for offline use.",preferredStyle: .alert)
                alertDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
                alertDialog.view.addSubview(UIView())
                alertDialog.popoverPresentationController?.sourceView = self.view
                self.present(alertDialog, animated: true, completion: nil)

                let myCharacters = URL(string:"https://www.dndbeyond.com/my-characters")
                let archiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((myCharacters?.pathComponents.last)!).appendingPathExtension("webarchive")
                if FileManager.default.fileExists(atPath: archiveURL.path) {
                    guard let webArchive = try? Data(contentsOf: archiveURL) else { loadStaticPage(errorDesc); return }
                    webView.load(webArchive, mimeType: "application/x-webarchive", characterEncodingName: String.Encoding.utf8.description, baseURL: archiveURL)
                } else {
                    loadStaticPage(errorDesc)
                }
            } else {
                loadStaticPage(errorDesc)
            }
        } else {
            print("Error: \(errorDesc)")
        }
    }
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        _wknavigation = navigation
        _wkurl = webView.url
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies( { cookies in
            for cookie in cookies {
                if cookie.domain.hasSuffix("dndbeyond.com") && cookie.name == "CobaltSession" {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
            }
        })
//        print(navigationResponse.response.url?.absoluteString)
        decisionHandler(.allow)
    }
}
extension ViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        //this one works
        if message.name == "captureCall" {
            print(message.body)
        } else if message.name == "navFunction" {
            if message.body as? String == "GoHome" {
                returnHome()
            } else if message.body as? String == "LoadImages" {
                do {
                    let imgjs = try String(contentsOfFile: Bundle.main.path(forResource: "imgpreload", ofType: "js")!)
                    self.webView.evaluateJavaScript(imgjs) { result, error in
                        if error != nil {
                            print("Could not preload images: \(error!.localizedDescription)")
                        } else if self.webView.url != nil && !(self.webView.url?.absoluteString.hasSuffix(".webarchive"))! {
                            /*
                            let archiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((self.webView.url!.pathComponents.last)!).appendingPathExtension("webarchive")
                            if FileManager.default.fileExists(atPath: archiveURL.path) && self.checkIfCharacterSheet(wV: self.webView) {
                                let activeURL = self.webView.url!
                                DispatchQueue.global(qos: .background).async {
                                    print ("Downloading updated JSON.")
                                    do {
                                        let jsonArchiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((activeURL.pathComponents.last)!).appendingPathExtension("json")
                                        let jsonURL = activeURL.appendingPathComponent("/json")
                                        let jsonData = try Data(contentsOf: jsonURL)
                                        try jsonData.write(to: jsonArchiveURL)
                                    } catch let error { print ("Could not update character JSON: \(error)") }
                                }
                            } else { */
                                self.makeWebArchive(result as! Array<String>,self.webView.url!)
                            //}
                        }
                    }
                } catch let error { print (error.localizedDescription) }
            }
        } else if message.name == "apiCall" {
            do {
                let msg = message.body as? String ?? "[{\"url\": null, \"data\": null}]"
                let calls = try JSONDecoder().decode([apiCall].self,from: msg.data(using: .utf8)!)
                if self.reachability?.connection != .unavailable {
                    DispatchQueue.global(qos: .background).async {
                        for call in calls {
                            let url = call.url ?? ""
                            let data = call.data ?? ""
                            if url.hasPrefix("/api") && url != "/api/character/services" && !url.hasPrefix("/api/config/json") && !url.hasPrefix("/api/subscriptionlevel") {
                                if !self.sendAPICall(url: url, data: data) {
                                    self.queuedAPICalls.append(call)
                                }
                            }
                        }
                        let defaults = UserDefaults.standard
                        defaults.setStructArray(self.queuedAPICalls, forKey: "queuedAPICalls")
                    }
                } else {
                    for call in calls {
                        let url = call.url ?? ""
                        let data = call.data ?? ""
                        if url.hasPrefix("/api") && url != "/api/character/services" && !url.hasPrefix("/api/config/json") && !url.hasPrefix("/api/subscriptionlevel") {
                            print("Queueing \(url) -> \(data)")
                            self.queuedAPICalls.append(call)
                        }
                    }
                    let defaults = UserDefaults.standard
                    defaults.setStructArray(self.queuedAPICalls, forKey: "queuedAPICalls")
                }
            } catch let error { print ( "Could not serialize JSON: \(error.localizedDescription)\n\(message.body)") }
        } else {
            print(message)
        }
    }
}

extension ViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        guard let textFieldText = textField.text,
            let rangeOfTextToReplace = Range(range, in: textFieldText) else {
                return false
        }
        let substringToReplace = textFieldText[rangeOfTextToReplace]
        let count = textFieldText.count - substringToReplace.count + string.count
        return count <= 3
    }
}
