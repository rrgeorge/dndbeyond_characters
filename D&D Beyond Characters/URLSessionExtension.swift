//
//  URLSessionExtension.swift
//  D&D Beyond Characters
//
//  Created by Robert George on 9/4/19.
//  Copyright © 2019 Robert George. All rights reserved.
//

import Foundation

extension URLSession {
    func syncDataTask (urlrequest: URLRequest) -> (Data?, URLResponse?, Error?) {
        var data:Data?
        var response:URLResponse?
        var error:Error?
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = self.dataTask(with: urlrequest) {
            data = $0
            response = $1
            error = $2
            
            semaphore.signal()
        }
        
        task.resume()
        
        _ = semaphore.wait(timeout: .distantFuture)
        
        return(data,response,error)
    }
}
