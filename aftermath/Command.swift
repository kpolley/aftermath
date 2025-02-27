//
//  Command.swift
//  aftermath
//
//  Copyright 2022 JAMF Software, LLC
//

 import Foundation

 struct Options: OptionSet {
     let rawValue: Int

     static let deep = Options(rawValue: 1 << 0)
     static let output = Options(rawValue: 1 << 1)
     static let analyze = Options(rawValue: 1 << 2)
     static let pretty = Options(rawValue: 1 << 3)
     static let collectDirs = Options(rawValue: 1 << 4)
     
 }

@main
class Command {
    static var options: Options = []
    static var analysisDir: String? = nil
    static var outputDir: String = "/tmp"
    static var collectDirs: [String] = []
    
    static func main() {
        setup(with: CommandLine.arguments)
        start()
    }

    static func setup(with fullArgs: [String]) {

        let args = [String](fullArgs.dropFirst())
      
         args.forEach { arg in
             switch arg {
             case "-h", "--help": Self.printHelp()
             case "--cleanup": Self.cleanup()
             case "-d", "--deep": Self.options.insert(.deep)
             case "--pretty": Self.options.insert(.pretty)
             case "-o", "--output":
                 if let index = args.firstIndex(of: arg) {
                     Self.options.insert(.output)
                     Self.outputDir = args[index + 1]
                 }
             case "--analyze":
                 if let index = args.firstIndex(of: arg) {
                     Self.options.insert(.analyze)
                     Self.analysisDir = args[index + 1]
                 }
             case "--collect-dirs":
                 if let index = args.firstIndex(of: arg) {
                     self.options.insert(.collectDirs)
                     var i = 1
                     while (index + i) < args.count  && !args[index + i].starts(with: "-") {
                         self.collectDirs.append(contentsOf: [args[index + i]])
                         i += 1
                     }
                 }
             default:
                 if !arg.starts(with: "-") {
                 } else {
                     print("Unidentified argument: \(arg)")
                     exit(9)
                 }
             }
         }
     }

     static func start() {
         printBanner()
         
         if Self.options.contains(.analyze) {
             CaseFiles.CreateAnalysisCaseDir()

             let mainModule = AftermathModule()
             mainModule.log("Aftermath Analysis Started")

             guard let dir = Self.analysisDir else {
                 mainModule.log("Analysis directory not provided")
                 return
             }
             guard isFileThatExists(path: dir) else {
                 mainModule.log("Analysis directory is not a valid directory that exists")
                 return
             }
             
             let unzippedDir = mainModule.unzipArchive(location: dir)
             
             mainModule.log("Started analysis on Aftermath directory: \(unzippedDir)")
             let analysisModule = AnalysisModule(collectionDir: unzippedDir)
             analysisModule.run()

             mainModule.log("Finished analysis module")
             
             guard isDirectoryThatExists(path: Self.outputDir) else {
                 mainModule.log("Output directory is not a valid directory that exists")
                 return
             }

             // Move analysis directory to output direcotry
             CaseFiles.MoveTemporaryCaseDir(outputDir: self.outputDir, isAnalysis: true)

             // End Aftermath
             mainModule.log("Aftermath Finished")
         } else {
             CaseFiles.CreateCaseDir()
             let mainModule = AftermathModule()
             mainModule.log("Aftermath Collection Started")
             mainModule.addTextToFile(atUrl: CaseFiles.metadataFile, text: "file,birth,modified,accessed,permissions,uid,gid, downloadedFrom")
             

             // System Recon
             mainModule.log("Started system recon")
             let systemReconModule = SystemReconModule()
             systemReconModule.run()
             mainModule.log("Finished system recon")


             // Network
             mainModule.log("Started gathering network information...")
             let networkModule = NetworkModule()
             networkModule.run()
             mainModule.log("Finished gathering network information")


             // Processes
             mainModule.log("Starting process dump...")
             let procModule = ProcessModule()
             procModule.run()
             mainModule.log("Finished gathering process information")


             // Persistence
             mainModule.log("Starting Persistence Module")
             let persistenceModule = PersistenceModule()
             persistenceModule.run()
             mainModule.log("Finished logging persistence items")

             
             // FileSystem
             mainModule.log("Started gathering file system information...")
             let fileSysModule = FileSystemModule()
             fileSysModule.run()
             mainModule.log("Finished gathering file system information")


             // Artifacts
             mainModule.log("Started gathering artifacts...")
             let artifactModule = ArtifactsModule()
             artifactModule.run()
             mainModule.log("Finished gathering artifacts")


             // Logs
             mainModule.log("Started logging unified logs")
             let unifiedLogModule = UnifiedLogModule()
             unifiedLogModule.run()
             mainModule.log("Finished logging unified logs")
             
             mainModule.log("Finished running Aftermath collection")


             guard isDirectoryThatExists(path: Self.outputDir) else {
                 mainModule.log("Output directory is not a valid directory that exists")
                 return
             }
             
             // Copy from cache to output
             CaseFiles.MoveTemporaryCaseDir(outputDir: self.outputDir, isAnalysis: false)

             // End Aftermath
             mainModule.log("Aftermath Finished")
         }
     }

     static func cleanup() {
         // remove any aftermath directories from tmp and /var/folders/zz
         let potentialPaths = ["/tmp", "/var/folders/zz"]
         for p in potentialPaths {
             let enumerator = FileManager.default.enumerator(atPath: p)
             while let element = enumerator?.nextObject() as? String {
                 if element.contains("Aftermath_") {
                     let dirToRemove = URL(fileURLWithPath: "\(p)/\(element)")
                     do {
                         try FileManager.default.removeItem(at: dirToRemove)
                         print("Removed \(dirToRemove.relativePath)")
                     } catch {
                         print("\(Date().ISO8601Format()) - Error removing \(dirToRemove.relativePath)")
                         print(error)
                     }
                 }
             }
         }
         exit(1)
     }

     static func isDirectoryThatExists(path: String) -> Bool {
         var isDir : ObjCBool = false
         let pathExists = FileManager.default.fileExists(atPath: path, isDirectory:&isDir)
         return pathExists && isDir.boolValue
     }
    
    static func isFileThatExists(path: String) -> Bool {
        let fileExists = FileManager.default.fileExists(atPath: path)
        return fileExists
    }

     static func printHelp() {
         print("-o -> specify an output location for Aftermath results (defaults to /tmp)")
         print("     usage: -o Users/user/Desktop")
         print("--analyze -> Analyze the results of the Aftermath results")
         print("     usage: --analyze <path_to_file>")
         print("--collect-dirs -> specify locations of (space-separated) directories to dump those raw files")
         print("    usage: --collect-dirs /Users/<USER>/Downloads /tmp")
         print("--deep -> performs deep scan and captures metadata from Users entire directory (WARNING: this may be time-consuming)")
         print("--pretty -> colorize Terminal output")
         print("--cleanup -> remove Aftermath Folders in default locations")
         exit(1)
     }
    
    static func printBanner() {
        print(#"""
              ___    ______                            __  __
             /   |  / __/ /____  _________ ___  ____ _/ /_/ /_
            / /| | / /_/ __/ _ \/ ___/ __ `__ \/ __ `/ __/ __ \
           / ___ |/ __/ /_/  __/ /  / / / / / / /_/ / /_/ / / /
          /_/  |_/_/  \__/\___/_/  /_/ /_/ /_/\__,_/\__/_/ /_/
                                                                    
        """#)
    }
 }
