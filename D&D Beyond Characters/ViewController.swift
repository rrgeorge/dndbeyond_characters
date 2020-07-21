//
//  ViewController.swift
//  D&D Beyond Characters
//
//  Created by Robert George on 7/10/19.
//  Copyright © 2019 Robert George. All rights reserved.
//

import UIKit
import WebKit

let ddbCharSvc = "https://character-service.dndbeyond.com/character"
let ddbApiV = "v3"

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
    let method:String?
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
    var _csrfToken: String?
    var _ddbUser: String?
    var modifiers = [modifier]()
    var queuedAPICalls = [apiCall]()
    var reachability: Reachability?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        reachability = try! Reachability()

        let webConfiguration = WKWebViewConfiguration()
        let webDataStore = WKWebsiteDataStore.default()
        
        
        webConfiguration.websiteDataStore = webDataStore
        webConfiguration.dataDetectorTypes = []
        webConfiguration.setURLSchemeHandler(DDBCacheHandler(), forURLScheme: "ddbcache")
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
                        let method = call.method ?? "PUT"
                        if url.hasPrefix("https://character-service.dndbeyond.com/character/v3/character") && call.data != nil {
                            print("Sending call \(call.method) to \(call.url) with \(call.data)")
                            if !self.sendAPICall(url: url, data: data, method: method) {
                                newAPIQueue.append(call)
                            }
                        } else {
                            print("Ignoring call \(call.method) to \(call.url) with \(call.data)")
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
    
    func loadDemo() {
        let cookie = HTTPCookie(properties: [
            .domain: ".dndbeyond.com",
            .path: "/",
            .name: "CobaltSession",
            .secure: true,
            .expires: "Thu, 02 Aug 2029 05:37:39 GMT",
            .value: "eyJhbGciOiJkaXIiLCJlbmMiOiJBMTI4Q0JDLUhTMjU2In0..kxV3lAWS-3q8Kd4pVVYZgg.BVQc4Nr8u9l19tS2wqI8QEhZK7NUMc2LzGUOYkYTD3-y0rbsWhal6oXcgTIxat4i.-ooxqlApn20IgZQZnToZww",
            ])
            HTTPCookieStorage.shared.setCookie(cookie!)
        let webDataStore = self.webView.configuration.websiteDataStore
        webDataStore.httpCookieStore.getAllCookies( { cookies in
            for cookie in cookies {
                webDataStore.httpCookieStore.delete(cookie, completionHandler: nil)
                }
            })
        webDataStore.httpCookieStore.setCookie(cookie!, completionHandler: {
            self.webView.load(URLRequest(url: URL(string:"about:blank")!))
            let myURL = URL(string:"https://www.dndbeyond.com/profile/rge_ddb/characters/26459429")
            let myRequest = URLRequest(url: myURL!)
            self.webView.stopLoading()
            self.webView.load(myRequest)
            } )
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
                        rollDialog.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
                        rollDialog.popoverPresentationController?.permittedArrowDirections = []
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
                    if error != nil {
                        print ("Could not parse dice rolls: \(String(describing: error?.localizedDescription))")
                    } else {
                        let decoder = JSONDecoder()
                        let json = (mods as! String).data(using: .utf8)!
                        self.modifiers = try decoder.decode([modifier].self, from: json)
                    }
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
                if !(self.webView.url?.absoluteString.hasSuffix(".html"))! && self.webView.url?.scheme != "ddbcache" {
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
                if (self.webView.url?.absoluteString.hasSuffix("my-characters"))! || (self.webView.url?.absoluteString.hasSuffix("my-characters.html"))! {
                    do {
                        let docs = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
                        let files = try FileManager.default.contentsOfDirectory(atPath: docs.path)
                        let resjs = """
                        $( document ).ready(function(){
                        console.log("Checking...");
                        var offline=["\(files.joined(separator: "\",\""))"];
                        var cards = document.getElementsByClassName("ddb-campaigns-character-card");
                        for (let i=0;i<cards.length;i++){
                            let url = cards[i].getElementsByClassName('ddb-campaigns-character-card-footer-links-item-view')[0].href.split('/');
                            let item = url.pop();
                            if(offline.find(x=>x==(item+".html"))) {
                                let info = cards[i].getElementsByClassName('ddb-campaigns-character-card-header-upper-character-info-primary')[0];
                                while(info.getElementsByTagName('IMG').length > 0) { info.getElementsByTagName('IMG')[0].remove(); };
                                let img = new Image();
                                img.src = "https://image.flaticon.com/icons/svg/109/109554.svg";
                                img.height = 20;
                                img.style.filter="invert(100%)";
                                img.style.marginLeft="10px";
                                info.appendChild(img);
                            } else {
                                console.log("No match: " + item);
                            }
                        }});
                        """
                        self.webView.evaluateJavaScript(resjs)
                    } catch let e {
                        print ("Could not determine offline characters: \(e)")
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
            return checkIfCharacterSheet(url: url.absoluteString)
        } else {
            return false
        }
    }
    func checkIfCharacterSheet(url: String) -> Bool {
//        if url.hasSuffix(".html") && url.hasPrefix("ddbcache://") && !url.hasSuffix("my-characters.html") {
//            return true
//        }
        let range = NSRange(location: 0, length: (url as NSString).length)
        let regex = try! NSRegularExpression(pattern: "(http[s]?://(www\\.)?dndbeyond.com|ddbcache://)/profile/([^/]*)/characters/[0-9]*$")
        let matches = regex.numberOfMatches(in: url, options: [], range: range)
        if matches > 0 {
            return true
        } else {
            return false
        }
    }
    func checkIfCharacterSheetBuilderScores(wV: WKWebView) -> Bool {
        if let url = wV.url {
            return checkIfCharacterSheetBuilderScores(url: url.absoluteString)
        } else {
            return false
        }
    }
    func checkIfCharacterSheetBuilderScores(url: String) -> Bool {
        let range = NSRange(location: 0, length: (url as NSString).length)
        let regex = try! NSRegularExpression(pattern: "http[s]?:\\/\\/(www\\.)?dndbeyond.com\\/profile\\/([^\\/]*)\\/characters\\/[0-9]*\\/builder#\\/ability-scores\\/.*")
        let matches = regex.numberOfMatches(in: url, options: [], range: range)
        if matches > 0 {
            return true
        } else {
            return false
        }
    }
    func checkIfCharacterSheetBuilder(url: String) -> Bool {
        let range = NSRange(location: 0, length: (url as NSString).length)
        let regex = try! NSRegularExpression(pattern: "(http[s]?://(www\\.)?dndbeyond.com|ddbcache://)/profile\\/([^\\/]*)\\/characters\\/[0-9]*\\/builder#.*")
        let matches = regex.numberOfMatches(in: url, options: [], range: range)
        if matches > 0 {
            return true
        } else {
            return false
        }
    }
    func checkIfCharacterSheetBuilderClasses(wV: WKWebView) -> Bool {
        if let url = wV.url {
            return checkIfCharacterSheetBuilderClasses(url: url.absoluteString)
        } else {
            return false
        }
    }
    func checkIfCharacterSheetBuilderClasses(url: String) -> Bool {
        let range = NSRange(location: 0, length: (url as NSString).length)
        let regex = try! NSRegularExpression(pattern: "http[s]?:\\/\\/(www\\.)?dndbeyond.com\\/profile\\/([^\\/]*)\\/characters\\/[0-9]*\\/builder#\\/class\\/manage.*")
        let matches = regex.numberOfMatches(in: url, options: [], range: range)
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
            let dieStr = rollDialog.textFields?.last?.text ?? "1"

            if (diceStr == "rge" && dieStr == "ddb") || (diceStr == "000" && dieStr == "000") {
                let demoDialog = UIAlertController(title: "Demo Account", message: "Enter Demo Code",preferredStyle: .alert)
                demoDialog.addTextField() {textField in
                    textField.placeholder = "Demo Code"
                }
                demoDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
                demoDialog.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: {action in
                    print("Demo?")
                    let demoCode = demoDialog.textFields?.first?.text ?? ""
                    if demoCode == "Konvih-dupdu9-sachih" {
                        print("Yes")
                        self.loadDemo()
                    }
                    demoDialog.dismiss(animated: true, completion: nil)
                }))
                demoDialog.popoverPresentationController?.sourceView = self.view
                self.present(demoDialog, animated: true, completion: {demoDialog.textFields?.first?.becomeFirstResponder()})
                return
            }
            var dice = Int(diceStr) ?? 1
            if dice < 1 { dice = 1 }
            if dice > 999 { dice = 999 }
            else if dice < 1 { dice = 1 }
            var die = Int(dieStr) ?? 1
            if die < 1 { die = 1 }
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
        let defaults = UserDefaults.standard
        let remoteHost = defaults.string(forKey: "remoteHost") ?? ""
        if remoteHost.hasPrefix("http") {
            sendToE(rolled,rolledString)
        }
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
        rollDialog.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        rollDialog.popoverPresentationController?.permittedArrowDirections = []
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
        rollDialog.popoverPresentationController?.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0)
        rollDialog.popoverPresentationController?.permittedArrowDirections = []
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

    func sendToE(_ rolled: Int,_ rolledString: String? = "") {
						
        let data = [
            "source": "Test",
            "type": "roll",
            "content": [
                "result": rolled,
                "detail": rolledString,
                "name": "test",
                "type": "roll"
                ]
            ]
        let defaults = UserDefaults.standard
        let remoteHost = defaults.string(forKey: "remoteHost") ?? ""
        if remoteHost.hasPrefix("http") {
            let url = URL(string: remoteHost)!
            let session = URLSession.shared
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted) // pass dictionary to data object and set it as request body
            } catch let error {
                print(error.localizedDescription)
            }
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            let task = session.dataTask(with: request, completionHandler: { data, response, error in
                guard error == nil else {
                    return
                }

                guard let data = data else {
                    return
                }

                do {
                    //create json object from data
                    guard let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] else {
                        return
                    }
                    print(json)
                } catch let error {
                    print(error.localizedDescription)
                }
            })
            task.resume()
        }
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
    
    func saveJSON() {
        if (self.webView != nil && self.webView.url != nil && checkIfCharacterSheet(wV: self.webView)) {
            webView.evaluateJavaScript("JSON.stringify(jsonfiles[\"characterjson\"]);", completionHandler: { (jsonfile, error) in
                if error != nil {
                    print ("Error extracting jsonfile: \(error!.localizedDescription)")
                } else {
                    do {
                        let archiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((self.webView.url!.deletingPathExtension().lastPathComponent)).appendingPathExtension("json")
                    let jsonfile = jsonfile as! String
                        try jsonfile.write(to: archiveURL, atomically: false, encoding: .utf8)
                    } catch let err {
                        print("Could not save JSON: \(err)")
                    }
                }
                })
        }
    }
    
    func makeWebArchive(_ urls: Array<String>, _ activeUrl: URL) {
        DispatchQueue.global(qos: .background).async {
            DispatchQueue.main.sync {
                self._archivebar = UIProgressView(progressViewStyle: .bar)
                let frame = self.view.frame
                self._archivebar!.frame = CGRect(x: 0,y: frame.maxY-2.5,width: frame.width,height: 5)
                self._archivebar!.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
                self._archivebar!.isHidden = false
                self._archivebar!.progress = 0
                self.view.addSubview(self._archivebar!)
            }
            let itemcount = Float(urls.count + 15)
            var itemNo = Float(0.0);
            DispatchQueue.main.sync { self._archivebar!.progress = itemNo/itemcount }
            let archiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((activeUrl.pathComponents.last)!).appendingPathExtension("html")
            let cacheDir = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("com.dndbeyond.resourcecache", isDirectory: true)
            var sharingType = 2
            var campaignId: Int?
            do {
                enum ArchiveError : Error {
                    case NoCobaltToken
                    case NoCharacterJSON
                    case NoCharacterSVC
                    case NoJSONCfg
                }

                if self._cobaltAuth == nil {
                    if self.getCobaltToken() == nil {
                        throw ArchiveError.NoCobaltToken
                    }
                }
                let maincontents = try NSMutableString(contentsOf: activeUrl, encoding: String.Encoding.utf8.rawValue)
                var headcontents = String("\n<meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge,chrome=1\">\n")
                headcontents.append("<script type=\"text/javascript\">\n")
                
                if activeUrl.pathComponents.last != "my-characters" {
                    let charID = activeUrl.pathComponents.last!
                    let contents: String
                    do  {
                        // Get Character JSON
                        let jsonURL = URL(string:String(format:"%@/%@/character/%@",ddbCharSvc,ddbApiV,charID))!
                        var jsonRequest = URLRequest(url: jsonURL)
                        jsonRequest.httpMethod = "GET"
                        jsonRequest.httpShouldHandleCookies = true
                        jsonRequest.addValue(self._cobaltAuth!, forHTTPHeaderField: "Authorization")
                        let (results, response, error) = URLSession.shared.syncDataTask(urlrequest: jsonRequest)
                        if let error = error {
                            print("Synchronous task ended with error: \(error)")
                            throw ArchiveError.NoCharacterJSON
                        } else if results == nil {
                            print("Could not download Character JSON")
                            throw ArchiveError.NoCharacterJSON
                        }
                        let encoding = CFStringConvertIANACharSetNameToEncoding(response?.textEncodingName as CFString?)
                        let charSet: String.Encoding
                        if encoding != kCFStringEncodingInvalidId {
                            let senc = CFStringConvertEncodingToNSStringEncoding(encoding)
                            charSet = String.Encoding(rawValue: senc)
                        } else {
                            charSet = String.Encoding.utf8
                        }
                        let jsoncontents = String(data: results!, encoding: charSet) ?? ""
                        
                        //let contents = try String(contentsOf:jsonURL)
                        let jsonArchiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((activeUrl.pathComponents.last)!).appendingPathExtension("json")
                        try jsoncontents.write(to: jsonArchiveURL, atomically: true, encoding: .utf8)
                        contents = jsoncontents
                    } catch {
                        throw ArchiveError.NoCharacterJSON
                    }
                    itemNo = 1.0
                    DispatchQueue.main.sync {
                        if self._archivebar != nil {
                            self._archivebar!.progress = itemNo/itemcount
                        }
                    }
                    var jsonvalues = ""
                    jsonvalues.append("\n")
                    jsonvalues.append("jsonfiles = [];\n")
                    jsonvalues.append("jsonfiles[\"characterjson\"] = \(contents);\n")
                    if (urls.count > 0) {
                        struct DDBJSON {
                            var name: String
                            var path: String
                        }
                        var cachedJSONs: [DDBJSON] = [
                            DDBJSON(name: "rule-data", path: String(format:"rule-data?v=%@", "3.2.1")),
                            DDBJSON(name: "known-infusions", path: String(format:"known-infusions?characterId=%@", charID)),
                            DDBJSON(name: "infusion/items", path: String(format:"infusion/items?characterId=%@", charID)),
                            DDBJSON(name: "vehicles", path: String(format:"vehicles?characterId=%@", charID)),
                            DDBJSON(name: "vehicle/components", path: String(format:"vehicle/components?characterId=%@", charID)),
                        ]
                        if let charJSON = try JSONSerialization.jsonObject(with: contents.data(using: .utf8)!, options:[] ) as? [String: Any] {
                            if let charObj = charJSON["data"] as? [String: Any] {
                                let prefs = charObj["preferences"] as! [String: Any]
                                sharingType = prefs["sharingType"] as! Int
                                if let campaign = charObj["campaign"] as? [String: Any] {
                                    campaignId = campaign["id"] as? Int
                                }
                                let backgroundId: Int?
                                let background = charObj["background"] as! [String: Any]
                                if let backDef = background["definition"] as? [String: Any] {
                                    backgroundId = backDef["id"] as? Int
                                } else {
                                    backgroundId = nil
                                }
                                let classes = charObj["classes"] as! [Any]
                                for oneClass in classes {
                                    let classDef = (oneClass as! [String: Any])["definition"] as! [String: Any]
                                    let classId = classDef["id"] as! Int
                                    let classLevel = (oneClass as! [String: Any])["level"] as! Int
                                    if classDef["canCastSpells"] as! Bool {
                                        if backgroundId != nil {
                                            cachedJSONs.append(
                                                DDBJSON(
                                                    name:String(format:"spelllist_%d",classId),
                                                    path:String(format:
                                                        "game-data/spells?sharingSetting=%d&classId=%d&classLevel=%d&backgroundId=%d",
                                                                sharingType, classId, classLevel, backgroundId!
                                                ))
                                            )
                                        } else {
                                            cachedJSONs.append(
                                                DDBJSON(
                                                    name:String(format:"spelllist_%d",classId),
                                                    path:String(format:
                                                        "game-data/spells?sharingSetting=%d&classId=%d&classLevel=%d",
                                                                sharingType, classId, classLevel
                                                ))
                                            )
                                        }
                                    }
                                }
                            }
                        }
                        
                        if campaignId != nil {
                            cachedJSONs.append(
                                DDBJSON(name: "game-data/items", path: String(format:"game-data/items?campaignId=%d&sharingSetting=%d",campaignId!,sharingType))
                                )
                            cachedJSONs.append(
                                DDBJSON(name: "game-data/monsters", path: String(format:"game-data/monsters?campaignId=%d&sharingSetting=%d",campaignId!,sharingType))
                            )
                        } else {
                            cachedJSONs.append(
                                DDBJSON(name: "game-data/items", path: String(format:"game-data/items?sharingSetting=%d",sharingType))
                            )
                            cachedJSONs.append(
                                DDBJSON(name: "game-data/monsters", path: String(format:"game-data/monsters?sharingSetting=%d",sharingType))
                            )
                        }

                        struct vehiclequery : Codable {
                            var campaignId: Int?
                            var ids: [String]?
                            var sharingSetting: Int?
                        }
                        var vehQuery = vehiclequery.init()
                        for thisJSON in cachedJSONs {
                            if let jsonReqURL = URL(string:String(format:"%@/%@/%@",ddbCharSvc,ddbApiV,thisJSON.path)) {
                               do {
                                   var jsonRequest = URLRequest(url: jsonReqURL)
                                   jsonRequest.httpMethod = "GET"
                                   jsonRequest.httpShouldHandleCookies = true
                                   jsonRequest.addValue(self._cobaltAuth!, forHTTPHeaderField: "Authorization")
                                   let (results, response, error) = URLSession.shared.syncDataTask(urlrequest: jsonRequest)
                                   if let error = error {
                                       print("Synchronous task ended with error: \(error)")
                                       throw ArchiveError.NoCharacterSVC
                                   } else if results == nil {
                                       print("Could not download Character JSON")
                                       throw ArchiveError.NoCharacterSVC
                                   }
                                   let encoding = CFStringConvertIANACharSetNameToEncoding(response?.textEncodingName as CFString?)
                                   let charSet: String.Encoding
                                   if encoding != kCFStringEncodingInvalidId {
                                       let senc = CFStringConvertEncodingToNSStringEncoding(encoding)
                                       charSet = String.Encoding(rawValue: senc)
                                   } else {
                                       charSet = String.Encoding.utf8
                                   }
                                   let jsoncontents = String(data: results!, encoding: charSet) ?? ""
                                    jsonvalues.append("jsonfiles[\"\(thisJSON.name)\"] = \(jsoncontents);\n")
                                if thisJSON.name == "vehicles" {
                                    print("Getting vehicle IDs")
                                    vehQuery.campaignId = campaignId
                                    vehQuery.sharingSetting = sharingType
                                    vehQuery.ids = []
                                    if let vehJSON = try JSONSerialization.jsonObject(with: results!, options:[] ) as? [String: Any] {
                                        if let vehData = vehJSON["data"] as? [Any] {
                                            for oneVeh in vehData {
                                                if let defKey = (oneVeh as! [String: Any])["definitionKey"] as? String {
                                                    if defKey.hasPrefix("vehicle:") {
                                                        let index = defKey.index(defKey.startIndex, offsetBy: 8)
                                                        let vehId = String(defKey.suffix(from: index))
                                                        if !vehQuery.ids!.contains(vehId) {
                                                            vehQuery.ids?.append(vehId)
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                               } catch let e {
                                   print ("Could not cache \(thisJSON.name): \(e)")
                               }
                            }
                            itemNo += 1
                            DispatchQueue.main.sync {
                                if self._archivebar != nil {
                                    self._archivebar!.progress = itemNo/itemcount
                                }
                            }
                        }
                    
                    let otherUrls = [
                        "https://dice-service.dndbeyond.com/diceuserconfig/v1/get",
                        "https://gamedata-service.dndbeyond.com/vehicles/v3/rule-data?v=3.2.1",
                    ]
                    
                    for thisJSON in otherUrls {
                            if let jsonReqURL = URL(string:thisJSON) {
                               do {
                                   var jsonRequest = URLRequest(url: jsonReqURL)
                                   jsonRequest.httpMethod = "GET"
                                   jsonRequest.httpShouldHandleCookies = true
                                   jsonRequest.addValue(self._cobaltAuth!, forHTTPHeaderField: "Authorization")
                                   let (results, response, error) = URLSession.shared.syncDataTask(urlrequest: jsonRequest)
                                   if let error = error {
                                       print("Synchronous task ended with error: \(error)")
                                       throw ArchiveError.NoCharacterSVC
                                   } else if results == nil {
                                       print("Could not download Character JSON")
                                       throw ArchiveError.NoCharacterSVC
                                   }
                                   let encoding = CFStringConvertIANACharSetNameToEncoding(response?.textEncodingName as CFString?)
                                   let charSet: String.Encoding
                                   if encoding != kCFStringEncodingInvalidId {
                                       let senc = CFStringConvertEncodingToNSStringEncoding(encoding)
                                       charSet = String.Encoding(rawValue: senc)
                                   } else {
                                       charSet = String.Encoding.utf8
                                   }
                                   let jsoncontents = String(data: results!, encoding: charSet) ?? ""
                                    jsonvalues.append("jsonfiles[\"\(thisJSON)\"] = \(jsoncontents);\n")
                               } catch let e {
                                   print ("Could not cache \(thisJSON): \(e)")
                               }
                            }
                            itemNo += 1
                            DispatchQueue.main.sync {
                                if self._archivebar != nil {
                                    self._archivebar!.progress = itemNo/itemcount
                                }
                            }
                        }
                        if vehQuery.ids != nil, let jsonReqURL = URL(string:"https://gamedata-service.dndbeyond.com/vehicle/v4/collection") {
                           do {
                               var jsonRequest = URLRequest(url: jsonReqURL)
                               jsonRequest.httpMethod = "POST"
                               jsonRequest.httpShouldHandleCookies = true
                               jsonRequest.addValue(self._cobaltAuth!, forHTTPHeaderField: "Authorization")
                               jsonRequest.addValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
                               jsonRequest.httpBody = try JSONEncoder().encode(vehQuery)
                               let (results, response, error) = URLSession.shared.syncDataTask(urlrequest: jsonRequest)
                               if let error = error {
                                   print("Synchronous task ended with error: \(error)")
                                   throw ArchiveError.NoCharacterSVC
                               } else if results == nil {
                                   print("Could not download Character JSON")
                                   throw ArchiveError.NoCharacterSVC
                               }
                               let encoding = CFStringConvertIANACharSetNameToEncoding(response?.textEncodingName as CFString?)
                               let charSet: String.Encoding
                               if encoding != kCFStringEncodingInvalidId {
                                   let senc = CFStringConvertEncodingToNSStringEncoding(encoding)
                                   charSet = String.Encoding(rawValue: senc)
                               } else {
                                   charSet = String.Encoding.utf8
                               }
                               let jsoncontents = String(data: results!, encoding: charSet) ?? ""
                               jsonvalues.append("jsonfiles[\"\(jsonReqURL.absoluteString)\"] = \(jsoncontents);\n")
                           } catch let e {
                               print ("Could not cache /vehicle/v4/collection: \(e)")
                           }
                        }
                        itemNo += 1
                        DispatchQueue.main.sync {
                            if self._archivebar != nil {
                                self._archivebar!.progress = itemNo/itemcount
                            }
                        }
                    if let jsonReqURL = URL(string:"https://www.dndbeyond.com/api/subscriptionlevel") {
                       do {
                           var jsonRequest = URLRequest(url: jsonReqURL)
                           jsonRequest.httpMethod = "POST"
                           jsonRequest.httpShouldHandleCookies = true
                           jsonRequest.addValue(self._cobaltAuth!, forHTTPHeaderField: "Authorization")
                           let (results, response, error) = URLSession.shared.syncDataTask(urlrequest: jsonRequest)
                           if let error = error {
                               print("Synchronous task ended with error: \(error)")
                               throw ArchiveError.NoCharacterSVC
                           } else if results == nil {
                               print("Could not download Character JSON")
                               throw ArchiveError.NoCharacterSVC
                           }
                           let encoding = CFStringConvertIANACharSetNameToEncoding(response?.textEncodingName as CFString?)
                           let charSet: String.Encoding
                           if encoding != kCFStringEncodingInvalidId {
                               let senc = CFStringConvertEncodingToNSStringEncoding(encoding)
                               charSet = String.Encoding(rawValue: senc)
                           } else {
                               charSet = String.Encoding.utf8
                           }
                           let jsoncontents = String(data: results!, encoding: charSet) ?? ""
                            jsonvalues.append("jsonfiles[\"/api/subscriptionlevel\"] = \(jsoncontents);\n")
                       } catch let e {
                           print ("Could not cache /api/subscriptionlevel: \(e)")
                       }
                    }
                    itemNo += 1
                    DispatchQueue.main.sync {
                        if self._archivebar != nil {
                            self._archivebar!.progress = itemNo/itemcount
                        }
                    }
                    headcontents.append(jsonvalues)
                    DispatchQueue.main.sync {
                            if self._archivebar != nil {
                                self._archivebar!.progress = itemNo/itemcount
                            }
                            print("Loading json cache")
                            self.webView.evaluateJavaScript(jsonvalues + "\nconsole.log(\"Loading json cache\")\n")
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
                
                //let crossoriginrange = maincontents.range(of: " crossorigin ")
                //if crossoriginrange.location != NSNotFound {
                //    maincontents.replaceCharacters(in: crossoriginrange, with: " ")
                //}
                maincontents.replaceOccurrences(of: " crossorigin ", with: " ", options: .caseInsensitive, range:NSMakeRange(0, maincontents.length))
                
                //let headclosingtag = maincontents.range(of: "</head>", options: .caseInsensitive)
                //if headclosingtag.location != NSNotFound {
                //    maincontents.replaceCharacters(in: headclosingtag, with: headcontents)
                //}
                maincontents.replaceOccurrences(of: "</head>", with: headcontents, options: .caseInsensitive, range:NSMakeRange(0, maincontents.length))
                
                maincontents.replaceOccurrences(
                    of:     "https://media-waterdeep.cursecdn.com",
                    with:   "ddbcache://",
                    options:    .caseInsensitive,
                    range:  NSMakeRange(0, maincontents.length)
                )
                maincontents.replaceOccurrences(
                    of:     "https://media.dndbeyond.com",
                    with:   "ddbcache://",
                    options:    .caseInsensitive,
                    range:  NSMakeRange(0, maincontents.length)
                )
                maincontents.replaceOccurrences(
                    of:     "/Content/[0-9-]+",
                    with:   "ddbcache:///content",
                    options:    .regularExpression,
                    range:  NSMakeRange(0, maincontents.length)
                )
                maincontents.replaceOccurrences(
                    of:     "/js/",
                    with:   "ddbcache:///js/",
                    options:    .caseInsensitive,
                    range:  NSMakeRange(0, maincontents.length)
                )
                maincontents.replaceOccurrences(
                    of:     "/api/custom-css",
                    with:   "ddbcache:///custom.css",
                    options:    .caseInsensitive,
                    range:  NSMakeRange(0, maincontents.length)
                )
                maincontents.replaceOccurrences(
                    of:     "ddbcache://ddbcache://",
                    with:   "ddbcache://",
                    options:    .caseInsensitive,
                    range:  NSMakeRange(0, maincontents.length)
                )
                maincontents.replaceOccurrences(
                    of:     "ddbcache:///ddbcache://",
                    with:   "ddbcache://",
                    options:    .caseInsensitive,
                    range:  NSMakeRange(0, maincontents.length)
                )

                let fullcontents = maincontents.data(using: String.Encoding.utf8.rawValue)!
                
                //let mainres = WebArchiveResource(url: activeUrl,data: fullcontents,mimeType: "text/html")
                //var webarchive = WebArchive(resource: mainres)
                try fullcontents.write(to: archiveURL)
                itemNo = 15.0
                DispatchQueue.main.sync {
                    if self._archivebar != nil {
                        self._archivebar!.progress = itemNo/itemcount
                    }
                }
                for singleUrl in urls {
                    let url: String
                    if singleUrl.contains("|") {
                        url = singleUrl.replacingOccurrences(of: "|", with: "%7C")
                    } else {
                        url = singleUrl
                    }
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
                        } else if url.hasSuffix(".css") || url.contains("css") {
                            mimetype = "text/css"
                        } else if url.hasSuffix(".js") || url.contains("jquery") || url.contains("cobalt") || url.contains("waterdeep") {
                            mimetype = "text/javascript"
                        } else if url.hasSuffix(".json") || url.contains("json") {
                            mimetype = "application/json"
                        } else if url.hasSuffix(".html") || url.hasSuffix(".htm") {
                            mimetype = "text/html"
                        } else {
                            mimetype = "application/octet-stream"
                        }

                        if let thisURL = URL(string:url) {
                            do {
                                if !FileManager.default.fileExists(atPath: cacheDir.path) {
                                    try FileManager.default.createDirectory(atPath: cacheDir.path, withIntermediateDirectories: false, attributes:nil)
                                }
                                let cachedPath = NSMutableString(string: thisURL.path.lowercased())
                                cachedPath.replaceOccurrences(of: "/[Cc]ontent(/[0-9-]+)?", with: "/content", options: .regularExpression, range: NSMakeRange(0, cachedPath.length))
                                cachedPath.replaceOccurrences(of: "/api/custom-css", with: "custom.css", options: [],range:  NSMakeRange(0, cachedPath.length))
                                let cachedURL: URL
                                if url.contains("fonts.googleapis.com") {
                                    let nsurl = url as NSString
                                    let googleFont = nsurl.replacingOccurrences(of: ".*//fonts\\.googleapis\\.com/css\\?family=([A-z]*).*", with: "googlefont.$1.css", options: .regularExpression, range: NSMakeRange(0, nsurl.length))
                                    cachedURL = cacheDir.appendingPathComponent(googleFont)
                                } else if url.contains("/api/character/svg/download") {
                                    let nsurl = url as NSString
                                    let themedSVG = nsurl.replacingOccurrences(of: ".*/api/character/svg/download\\?themeId=([0-9]+)&name=([^)\"]*)", with: "/api/character/$2_$1.svg", options: .regularExpression, range:NSMakeRange(0, nsurl.length)).lowercased()
                                    cachedURL = cacheDir.appendingPathComponent(themedSVG)
                                } else {
                                    cachedURL = cacheDir.appendingPathComponent(String(cachedPath).lowercased())
                                }
                                if !FileManager.default.fileExists(atPath: cachedURL.deletingLastPathComponent().path) {
                                    try FileManager.default.createDirectory(atPath: cachedURL.deletingLastPathComponent().path, withIntermediateDirectories: true, attributes:nil)
                                }
                                if FileManager.default.fileExists(atPath: cachedURL.path) {
                                    let attrib = try FileManager.default.attributesOfItem(atPath: cachedURL.path)
                                    let created = attrib[FileAttributeKey.creationDate] as! Date
                                    if created.timeIntervalSinceNow < -2592000 {
                                        try FileManager.default.removeItem(atPath: cachedURL.path)
                                    }
                                }
                                if !FileManager.default.fileExists(atPath: cachedURL.path) {
                                    print("Caching \(thisURL.absoluteString) type: \(mimetype)")
                                    if mimetype == "text/css" {
                                        print("Processing css file: \(thisURL.absoluteString)")
                                        var resContents = try String(contentsOf:thisURL)
                                        //if thisURL.absoluteString.contains("fonts.googleapis.com") {
                                            let fontRegex = try! NSRegularExpression(pattern: "url\\(((http[s]?:)?/?/([^)]+))\\)")
                                            for match in fontRegex.matches(in: resContents, options: [], range: NSMakeRange(0,(resContents as NSString).length)) {
                                                print("Need to cache font:")
                                                let range = match.range(at: 1)
                                                if range.location != NSNotFound {
                                                    if let urlRange = Range(range, in: resContents) {
                                                        let thisFont = String(resContents[urlRange])
                                                        print("\(thisFont)")
                                                        if let thisFontURL = URL(string:thisFont) {
                                                            let fontCacheURL = cacheDir.appendingPathComponent(thisFontURL.path.lowercased())
                                                            try FileManager.default.createDirectory(atPath: fontCacheURL.deletingLastPathComponent().path, withIntermediateDirectories: true, attributes:nil)
                                                            if !FileManager.default.fileExists(atPath: fontCacheURL.path) {
                                                                print("Caching: \(thisFontURL) to \(fontCacheURL)")
                                                                let fontRes = try Data(contentsOf:thisFontURL)
                                                                try fontRes.write(to: fontCacheURL)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        //}
                                        resContents = resContents.replacingOccurrences(
                                            of:"https://media-waterdeep.cursecdn.com",
                                            with: "ddbcache://")
                                        
                                        resContents = resContents.replacingOccurrences(
                                            of:"https://media.dndbeyond.com",
                                            with: "ddbcache://")
                                        
                                        resContents = resContents.replacingOccurrences(
                                            of:"https://www.dndbeyond.com",
                                            with: "ddbcache://")
                                        
                                        resContents = resContents.replacingOccurrences(
                                            of:"https://fonts.gstatic.com",
                                            with: "ddbcache://")
                                        
                                        resContents = resContents.replacingOccurrences(
                                            of: "//fonts\\.googleapis\\.com/css\\?family=([A-z]*)[^\")]*",
                                            with: "ddbcache:///googlefont.$1.css",
                                            options: .regularExpression,
                                            range: nil)
                                        
                                        resContents = resContents.replacingOccurrences(
                                            of:"/api/character/svg/download\\?themeId=([0-9]+)&name=([^)\"]*)",
                                            with: "ddbcache:///api/character/$2_$1.svg",
                                            options: .regularExpression,
                                            range: nil)
                                        resContents = resContents.replacingOccurrences(
                                            of:"/[Cc]ontent(/[0-9-]+)?",
                                            with: "ddbcache:///content",
                                            options: .regularExpression,
                                            range: nil)
                                        resContents = resContents.replacingOccurrences(
                                            of:"/js/",
                                            with: "ddbcache:///js/")
                                        resContents = resContents.replacingOccurrences(
                                            of:"/api/custom-css",
                                            with: "ddbcache:///custom.css")
                                        resContents = resContents.replacingOccurrences(
                                            of:     "ddbcache:///ddbcache://",
                                            with:   "ddbcache://")
                                        resContents = resContents.replacingOccurrences(
                                            of:     "ddbcache://ddbcache://",
                                            with:   "ddbcache://")
                                        try resContents.write(to: cachedURL, atomically: false, encoding: .utf8)
                                    /*
                                    } else if mimetype == "text/javascript" && thisURL.absoluteString.contains("characterSheet.bundle") {
                                        var resContents = try String(contentsOf:thisURL)
                                        resContents = resContents.replacingOccurrences(
                                        of:"\"+baseUrl+\"/api/character/svg/download?themeId=\"+theme.themeColorId+\"&name=\"+name+\"",
                                            with: "ddbcache:///api/character/\"+name+\"_\"+theme.themeColorId+\".svg")
                                        resContents = resContents.replacingOccurrences(
                                        of:"/api/character/svg/download?themeId=\"+theme.themeColorId+\"&name=ability-score",
                                            with: "ddbcache:///api/character/ability-score_\"+theme.themeColorId+\".svg")
                                        try resContents.write(to: cachedURL, atomically: false, encoding: .utf8)
                                        } else if mimetype == "text/javascript" && thisURL.absoluteString.contains("waterdeep") {
                                        var resContents = try String(contentsOf:thisURL,encoding: .utf8)
                                        resContents = resContents.replacingOccurrences(
                                            of:"/content/syndication/tt.css",
                                            with: "/Content/syndication/tt.css")
                                        try resContents.write(to: cachedURL, atomically: false, encoding: .utf8)
 */
                                    } else {
                                        let resContents = try Data(contentsOf:thisURL)
                                        try resContents.write(to: cachedURL)
                                    }
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
                /*
                let encoder: PropertyListEncoder = {
                    let plistEncoder = PropertyListEncoder()
                    plistEncoder.outputFormat = .binary
                    return plistEncoder
                }()
                let webArch = try encoder.encode(webarchive)
                try webArch.write(to: archiveURL)
                */
                print ("Archived \(archiveURL.path)")
                DispatchQueue.main.sync {
                    if self._archivebar != nil {
                        self._archivebar!.progress = itemNo/itemcount
                        self._archivebar!.progress = 1
                        self._archivebar!.isHidden = true
                        self._archivebar!.removeFromSuperview()
                        self._archivebar = nil
                    }
                }
            } catch let error {
                DispatchQueue.main.sync {
                    if self._archivebar != nil {
                        self._archivebar!.progress = 1
                        self._archivebar!.isHidden = true
                        self._archivebar!.removeFromSuperview()
                        self._archivebar = nil
                    }
                }
                print(error)
            }
        }
    }
    
    func getCobaltToken() -> String? {
        if self._cobaltAuth == nil || self._cobaltExpires == nil || self._cobaltExpires!.timeIntervalSinceNow < TimeInterval(10.00) {
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
            
            let (rdata, _, error) = URLSession.shared.syncDataTask(urlrequest: cobaltRequest)
            
            if let error = error {
                print("Synchronous task ended with error: \(error)")
                return nil
            } else {
                if let rdata = rdata {
                    do {
                        let res = try JSONDecoder().decode(Cobalt.self, from: rdata)
                        self._cobaltAuth = "Bearer " + res.token
                        self._cobaltExpires = Date(timeIntervalSinceNow: TimeInterval(res.ttl))
                        //let response = response as? HTTPURLResponse
                        return self._cobaltAuth
                    } catch {
                        print("Error getting cobalt auth")
                        return nil
                    }
                } else {
                    return nil
                }
            }
        } else {
            return self._cobaltAuth
        }
    }
    
    
    func sendAPICall(url: String,data: String,method: String = "POST") -> Bool {
        if self._cobaltAuth == nil || self._cobaltExpires == nil || self._cobaltExpires!.timeIntervalSinceNow < TimeInterval(10.00) {
            let emptyData = ("").data(using: String.Encoding.utf8)
            let authURL = URL(string:"https://auth-service.dndbeyond.com/v1/cobalt-token")!
            var cobaltRequest = URLRequest(url: authURL)
            
            cobaltRequest.httpMethod = "POST"
            cobaltRequest.httpShouldHandleCookies = true
            cobaltRequest.addValue("https://www.dndbeyond.com", forHTTPHeaderField: "Origin")
            cobaltRequest.httpBody = emptyData
            
            struct Cobalt: Codable {
                let token: String
                let ttl: Int
            }
            
            let (rdata, _, error) = URLSession.shared.syncDataTask(urlrequest: cobaltRequest)
            
            if let error = error {
                print("Synchronous task ended with error: \(error)")
            } else {
                if let rdata = rdata {
                    do {
                        let res = try JSONDecoder().decode(Cobalt.self, from: rdata)
                        self._cobaltAuth = "Bearer " + res.token
                        self._cobaltExpires = Date(timeIntervalSinceNow: TimeInterval(res.ttl))
                        //let response = response as? HTTPURLResponse
                        return sendAPICall(url: url,data: data,method: method)
                    } catch let e {
                        print("Error getting cobalt auth - \(e)")
                        return false
                    }
                }
            }
        } else {
            let apiURL = (url.hasPrefix("http")) ? URL(string:url)! : URL(string:"https://www.dndbeyond.com" + url)!
            do {
                var apiRequest = URLRequest(url: apiURL)

                if apiURL.host != "www.dndbeyond.com" {
                    apiRequest.addValue("https://www.dndbeyond.com", forHTTPHeaderField: "Origin")
                }
                
                apiRequest.httpMethod = method
                apiRequest.httpShouldHandleCookies = true
                apiRequest.addValue(_cobaltAuth!, forHTTPHeaderField: "Authorization")
                apiRequest.addValue("application/json;charset=utf-8", forHTTPHeaderField: "Content-Type")
                apiRequest.httpBody = data.data(using: String.Encoding.utf8)
                let (a, b, error) = URLSession.shared.syncDataTask(urlrequest: apiRequest)
                if let error = error {
                    print("Synchronous task ended with error: \(error)")
                    return false
                } else {
                    return true
                }
            } catch let e {
                print ("Could not send API call: \(e)")
                return false
            }
        }
        return false
    }
}

extension ViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("Could not load \(error)")
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation: WKNavigation!, withError: Error) {
        let errNo = (withError as NSError).code
        let errorDesc = withError.localizedDescription
        if didFailProvisionalNavigation == _wknavigation {
            let urlString = _wkurl?.absoluteString ?? "unknown url"
            if (_wkurl != nil) && urlString.hasSuffix(".html") && errNo == EPERM {
                print("Loading webarchive: " + _wkurl!.absoluteString)
                webView.loadFileURL(_wkurl!, allowingReadAccessTo: _wkurl!)
            } else {
                if urlString.hasPrefix("ddbcache") {
                    if checkIfCharacterSheet(url:urlString) {
                        let alertDialog = UIAlertController(title: "Character Not Available", message: "Sorry, but that character is not available for offline use.",preferredStyle: .alert)
                        alertDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
                        alertDialog.view.addSubview(UIView())
                        alertDialog.popoverPresentationController?.sourceView = self.view
                        self.present(alertDialog, animated: true, completion: nil)
                    } else if checkIfCharacterSheetBuilder(url:urlString) {
                        let alertDialog = UIAlertController(title: "Character Builder Available", message: "Sorry, but the character builder is not available when offline.",preferredStyle: .alert)
                        alertDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
                        alertDialog.view.addSubview(UIView())
                        alertDialog.popoverPresentationController?.sourceView = self.view
                        self.present(alertDialog, animated: true, completion: nil)
                    }
                }
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
            let archiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((myURL?.pathComponents.last)!).appendingPathExtension("html")
            if FileManager.default.fileExists(atPath: archiveURL.path) {
                guard let webArchive = try? Data(contentsOf: archiveURL) else { loadStaticPage(errorDesc); return }
                webView.stopLoading()
                webView.loadHTMLString(String(data: webArchive, encoding: .utf8)!, baseURL: URL(string:"ddbcache:///"))
                //webView.loadHTMLString(String(data: webArchive, encoding: .utf8)!, baseURL: archiveURL.deletingLastPathComponent())
//                webView.load(webArchive, mimeType: "text/html", characterEncodingName: String.Encoding.utf8.description, baseURL: archiveURL.deletingLastPathComponent())
                //webView.loadFileURL(archiveURL, allowingReadAccessTo: archiveURL)
            } else if (myURL?.pathComponents.last)! != "my-characters" {
                let alertDialog = UIAlertController(title: "Character Not Available", message: "Sorry, but that character is not available for offline use.",preferredStyle: .alert)
                alertDialog.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.default, handler: nil))
                alertDialog.view.addSubview(UIView())
                alertDialog.popoverPresentationController?.sourceView = self.view
                self.present(alertDialog, animated: true, completion: nil)

                let myCharacters = URL(string:"https://www.dndbeyond.com/my-characters")
                let archiveURL = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent((myCharacters?.pathComponents.last)!).appendingPathExtension("html")
                if FileManager.default.fileExists(atPath: archiveURL.path) {
                    guard let webArchive = try? Data(contentsOf: archiveURL) else { loadStaticPage(errorDesc); return }
                    webView.loadHTMLString(String(data: webArchive, encoding: .utf8)!, baseURL: URL(string:"ddbcache:///"))
                    //webView.loadHTMLString(String(data: webArchive, encoding: .utf8)!, baseURL: archiveURL.deletingLastPathComponent())
                    //webView.load(webArchive, mimeType: "text/html", characterEncodingName: String.Encoding.utf8.description, baseURL:archiveURL.deletingLastPathComponent())
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
        let url = webView.url
        if url != nil && url!.scheme == "https" && reachability?.connection == .unavailable {
            webView.stopLoading()
            let request = URLRequest(url: URL(string:"ddbcache://" + url!.path)!)
            webView.load(request)
        } else if url != nil && url!.scheme == "ddbcache" && reachability?.connection != .unavailable {
            webView.stopLoading()
            let request = URLRequest(url: URL(string:"https://www.dndbeyond.com" + url!.path)!)
            webView.load(request)
        }

    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies( { cookies in
            for cookie in cookies {
                if cookie.domain.hasSuffix("dndbeyond.com") && cookie.name == "CobaltSession" {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                if cookie.name == "RequestVerificationToken" {
                    self._csrfToken = cookie.value
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                if cookie.name == "User" {
                    let components = URLComponents(string: "?\(cookie.value)")
                    if let username = components?.queryItems?.first(where: {$0.name == "UserName" }) {
                        self._ddbUser = username.value
                    }
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
                        } else if self.webView.url != nil && !(self.webView.url?.absoluteString.hasSuffix(".html"))! {
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
                            let method = call.method ?? "POST"
                            if (url.hasPrefix("/api")||url.hasPrefix("https://character-service.dndbeyond.com/characters/v3/vehicles")) && url != "/api/character/services" && !url.hasPrefix("/api/config/json") && !url.hasPrefix("/api/subscriptionlevel") && call.data != nil {
                                if !self.sendAPICall(url: url, data: data, method: method) {
                                    self.queuedAPICalls.append(call)
                                }
                            } else if (url == "json") {
                                DispatchQueue.main.sync {
                                    self.makeWebArchive([], self.webView.url!)
                                }
                            }
                        }
                        let defaults = UserDefaults.standard
                        defaults.setStructArray(self.queuedAPICalls, forKey: "queuedAPICalls")
                    }
                } else {
                    for call in calls {
                        let url = call.url ?? ""
                        if url.hasPrefix("https://character-service.dndbeyond.com/character/v3/character") && call.data != nil {
                            if url.hasSuffix("/character/equipment/add") {
                                let alertDialog = UIAlertController(title: "Caution", message: "When adding equipment offline, changes to the new item may be lost the next time this character is synced online.",preferredStyle: .alert)
                                alertDialog.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: nil))
                                alertDialog.view.addSubview(UIView())
                                alertDialog.popoverPresentationController?.sourceView = self.view
                                self.present(alertDialog, animated: true, completion: nil)
                            } else if url.hasSuffix("/api/character/creatures/add") {
                                let alertDialog = UIAlertController(title: "Caution", message: "When adding creatures offline, some information cannot be populated until this character is synced online. Also, changes to the new creature may be lost the next time this character is synced online.",preferredStyle: .alert)
                                alertDialog.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: nil))
                                alertDialog.view.addSubview(UIView())
                                alertDialog.popoverPresentationController?.sourceView = self.view
                                self.present(alertDialog, animated: true, completion: nil)
                            }/* else if url == "https://character-service.dndbeyond.com/characters/v3/vehicles" {
                                let alertDialog = UIAlertController(title: "Not Supported", message: "Sorry, vehicle features are not currently supported offline.",preferredStyle: .alert)
                                alertDialog.addAction(UIAlertAction(title: "Okay", style: UIAlertAction.Style.default, handler: nil))
                                alertDialog.view.addSubview(UIView())
                                alertDialog.popoverPresentationController?.sourceView = self.view
                                self.present(alertDialog, animated: true, completion: nil)
                            }*/
                            self.queuedAPICalls.append(call)
                            saveJSON()
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
