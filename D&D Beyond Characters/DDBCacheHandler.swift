//
//  DDBCacheHandler.swift
//  D&D Beyond Characters
//
//  Created by Robert George on 9/13/19.
//  Copyright © 2019 Robert George. All rights reserved.
//

import Foundation
import WebKit

enum HandlerError: Error {
    case noIdeaWhatToDoWithThis
    case fileNotFound(fileName: String)
}

class DDBCacheHandler: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        //urlSchemeTask.didFailWithError(NSURLErrorCancelled)
    }
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url {
            let urlPath: String
            let charJSON: String?
            if (url.pathComponents[1] == "profile" && url.pathComponents[3] == "characters") || url.lastPathComponent == "my-characters" {
                urlPath = url.lastPathComponent + ".html"
                charJSON = url.lastPathComponent + ".json"
            } else if url.path == "/content/syndication/tt.css" {
                charJSON = nil
                urlPath = "/Content/syndication/tt.css"
            } else if url.path == "/api/character/svg/download" && url.query != nil {
                charJSON = nil
                urlPath = (url.query! as NSString).replacingOccurrences(of: "themeId=([0-9]+)&name=([^)\"]*)", with: "/api/character/$2_$1.svg", options: .regularExpression, range:NSMakeRange(0, (url.query! as NSString).length))
            } else {
                charJSON = nil
                urlPath = url.path
            }
            var mimetype: String
            if url.pathExtension == "svg" || urlPath.hasSuffix(".svg") {
                mimetype = "image/svg+xml"
            } else if url.pathExtension == "jpg" || url.pathExtension == "jpeg" {
                mimetype = "image/jpeg"
            } else if url.pathExtension == "png" {
                mimetype = "image/png"
            } else if url.pathExtension == "js" || url.lastPathComponent == "jquery" || url.lastPathComponent == "cobalt" || url.lastPathComponent == "waterdeep" {
                mimetype = "text/javascript"
            } else if url.pathExtension == "css" {
                mimetype = "text/css"
            } else if url.pathExtension == "json" {
                mimetype = "application/json"
            } else if url.pathExtension == "html" || url.pathExtension == "htm" || urlPath.hasSuffix(".html") {
                mimetype = "text/html"
            } else {
                mimetype = "application/octet-stream"
            }
            do {
                var fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(urlPath)
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    fileURL = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("com.dndbeyond.resourcecache" + urlPath)
                }
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    let urlResponse: URLResponse
                    let file: Data
                    if mimetype.hasPrefix("text/") || mimetype == "image/svg+xml" {
                        if url.lastPathComponent.contains("characterSheet.bundle") {
                            file = try String(contentsOf: fileURL).data(using: .unicode)!
                            urlResponse = URLResponse(url: url, mimeType: mimetype, expectedContentLength: file.count, textEncodingName: String.Encoding.unicode.description)
                        } else {
                            let fileString = try NSMutableString(contentsOf: fileURL,encoding: String.Encoding.utf8.rawValue)
                            if charJSON != nil {
                                let charJSONFile = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(charJSON!)
                                if FileManager.default.fileExists(atPath: charJSONFile.path){
                                    let newJsonFile = try String(contentsOf: charJSONFile)
                                    let replacementUUID = UUID().uuidString
                                    let replacement = NSRegularExpression.escapedTemplate(for: "jsonfile = \(replacementUUID);")
                                    let changed = fileString.replaceOccurrences(of: "(?m)^jsonfile = .*;$", with: replacement, options: .regularExpression, range: NSMakeRange(0, fileString.length))
                                    fileString.replaceOccurrences(of: replacementUUID, with: newJsonFile, options: [], range: NSMakeRange(0, fileString.length))
                                    print ("Updating JSON \(changed)")
                                }
                            }
                            file = fileString.data(using: String.Encoding.utf8.rawValue)!
                            urlResponse = URLResponse(url: url, mimeType: mimetype, expectedContentLength: file.count, textEncodingName: String.Encoding.utf8.description)
                        }
                    } else {
                        file = try Data(contentsOf: fileURL)
                        urlResponse = URLResponse(url: url, mimeType: mimetype, expectedContentLength: -1, textEncodingName: nil)
                    }
                    urlSchemeTask.didReceive(urlResponse)
                    urlSchemeTask.didReceive(file)
                    urlSchemeTask.didFinish()
                } else {
                    print ("Cannot find: \(fileURL.path)")
                    urlSchemeTask.didFailWithError(HandlerError.fileNotFound(fileName: url.path))
                }
            } catch let error {
                print ("Could not load from cache: \(error)")
            }
        }
        
    }
}
