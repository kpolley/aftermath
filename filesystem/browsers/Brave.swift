//
//  Brave.swift
//  aftermath
//
//

import Foundation
import SQLite3

class Brave {
        
    let caseHandler: CaseHandler
    let browserDir: URL
    let braveDir: URL
    let fm: FileManager
    let writeFile: URL
    let appPath: String
    
    init(caseHandler: CaseHandler, browserDir: URL, braveDir: URL, writeFile: URL, appPath: String) {
        self.caseHandler = caseHandler
        self.browserDir = browserDir
        self.braveDir = braveDir
        self.fm = FileManager.default
        self.writeFile = writeFile
        self.appPath = appPath
    }
    
    func getContents() {
        let username = NSUserName()
        let path = "/Users/\(username)/Library/Application Support/BraveSoftware/Brave-Browser/Default"
        let files = fm.filesInDirRecursive(path: path)
        
        for file in files {
            if file.lastPathComponent == "" {
                dumpHistory(file: file)
            }
        }
    }
    
    func dumpHistory(file: URL) {
        self.caseHandler.addTextToFile(atUrl: self.writeFile, text: "\n----- Brave History -----\n")
        
        var db: OpaquePointer?
        if sqlite3_open(file.path, &db) == SQLITE_OK {
            var queryStatement: OpaquePointer? = nil
            let queryString = "select datetime(vi.visit_time/1000000, 'unixepoch') as dt, urls.url FROM visits vi INNER join urls on vi.id = urls.id;"
            
            if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
                var dateTime: String = ""
                var url: String = ""
                
                while sqlite3_step(queryStatement) == SQLITE_ROW {
                    let col1  = sqlite3_column_text(queryStatement, 0)
                    if col1 != nil {
                        dateTime = String(cString: col1!)
                    }
                    
                    let col2 = sqlite3_column_text(queryStatement, 1)
                    if col2 != nil {
                        url = String(cString: col2!)
                    }
                    
                    self.caseHandler.addTextToFile(atUrl: self.writeFile, text: "DateTime: \(dateTime)\nURL: \(url)\n")
                }
            }
        }
        self.caseHandler.addTextToFile(atUrl: self.writeFile, text: "----- End of Brave History -----\n")
    }
    
    func dumpCookies() {
        let username = NSUserName()
        let file = URL(fileURLWithPath: "/Users/\(username)/Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies")
        
        self.caseHandler.addTextToFile(atUrl: self.writeFile, text: "----- Brave Cookies: -----\n")
        
        var db: OpaquePointer?
        if sqlite3_open(file.path, &db) == SQLITE_OK {
            var queryStatement: OpaquePointer? = nil
            let queryString = "select datetime(creation_utc/1000000-11644473600, 'unixepoch'), name,  host_key, path, datetime(expires_utc/1000000-11644473600, 'unixepoch') from cookies;"
        
            if sqlite3_prepare_v2(db, queryString, -1, &queryStatement, nil) == SQLITE_OK {
                var dateTime: String = ""
                var name: String = ""
                var hostKey: String = ""
                var path: String = ""
                var expireTime: String = ""
                
                while sqlite3_step(queryStatement) == SQLITE_ROW {
                    let col1  = sqlite3_column_text(queryStatement, 0)
                    if col1 != nil {
                        dateTime = String(cString: col1!)
                    }
                    
                    let col2 = sqlite3_column_text(queryStatement, 1)
                    if col2 != nil {
                        name = String(cString: col2!)
                    }
                    
                    let col3 = sqlite3_column_text(queryStatement, 2)
                    if col3 != nil {
                        hostKey = String(cString: col1!)
                    }
                    
                    let col4 = sqlite3_column_text(queryStatement, 3)
                    if col4 != nil {
                        path = String(cString: col2!)
                    }
                    
                    let col5 = sqlite3_column_text(queryStatement, 4)
                    if col5 != nil {
                        expireTime = String(cString: col1!)
                    }
                    
                    self.caseHandler.addTextToFile(atUrl: self.writeFile, text: "DateTime: \(dateTime)\nName: \(name)\nHostKey: \(hostKey)\nPath:\(path)\nExpireTime: \(expireTime)\n\n")
                }
            }
        }
        
        self.caseHandler.addTextToFile(atUrl: self.writeFile, text: "\n----- End of Brave Cookies -----\n")
    }
    
    func run() {
        self.caseHandler.log("Collecting brave browser information...")
        getContents()
        dumpCookies()
    }
}
