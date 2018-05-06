//
//  ViewController.swift
//  ProjectCampus
//
//  Created by Tiancheng Zhang on 4/5/18.
//  Copyright © 2018 Tiancheng Zhang. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // UIPickerView stuff from https://www.hackingwithswift.com/example-code/uikit/how-to-use-uipickerview

    @IBOutlet weak var fromTextDisplay: UITextView!
    @IBOutlet weak var directionDisplay: UITextView!
    @IBOutlet weak var stepDisplay: UITextView!
    @IBOutlet weak var campusImageView: UIImageView!
    @IBOutlet weak var routePicker: UIPickerView!
    var campusImage: UIImage = UIImage()
    var campusRegionImage: UIImage = UIImage()
    var imageXPadding: CGFloat = 0
    var imageYPadding: CGFloat = 0
    var imageScale: CGFloat = 0
    var imageRatio: CGFloat = 0
    var buildingDict = [String:String]()
    var relativeDict = [String:String]()
    var pixelDescriptions = Array(repeating: Array(repeating:"", count:495), count:275)
    var adjacencyMatrix = Array(repeating: Array(repeating: false, count: 26), count: 26)
    var regionKeys = Array(repeating: "", count: 26)
    var keyIndices = [String:Int]()
    var userSteps = [[Int]]()
    var routeTotalSteps: Int = 0
    var routeCurrentStep: Int = 0
    var isRouteTracing: Bool = false
    var routeSteps = [String]()
    var currentRouteIdx = 0
    
    var routes = [
        [[13, 47], [210, 410]], // NorthwestCorner to front of Hamilton&Hartley&Wallach&JohnJay, crosses campus
        [[210, 253], [76, 222]], // Buell to outside LowLibrary, passes building
        [[58, 394], [238, 413]], // Front of Journalism&Furnald to front of Hamilton&Hartley&Wallach&JohnJay, few anchors
        [[135, 412], [144, 46]], // Front of Butler to back of Uris, passes through many buildings
        [[50, 277], [225, 86]], // Front of Dodge to between Mudd and Shermerhorn, cramped buildings
        [[220, 321], [44, 98]] // CollegeWalk to Chandler&Havemeyer, tests CollegeWalk
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // Load image and make it respond to taps
        let imageTapRecognizer = UITapGestureRecognizer(target: self, action: #selector(imageTapped(tapGestureRecognizer:)))
        
        campusImage = OpenCVWrapper.loadImage(ofName: "campus", andType: "jpg");
        campusImageView.image = campusImage;
        campusImageView.isUserInteractionEnabled = true
        campusImageView.addGestureRecognizer(imageTapRecognizer)
        
        imageRatio = campusImage.size.width / campusImage.size.height
        let frameRatio = campusImageView.frame.size.width / campusImageView.frame.size.height
        if(imageRatio > frameRatio) {
            imageScale = campusImageView.frame.size.width / campusImage.size.width
        } else {
            imageScale = campusImageView.frame.size.height / campusImage.size.height
        }
        imageXPadding = (campusImageView.frame.size.width - campusImage.size.width * imageScale) / 2.0
        imageYPadding = (campusImageView.frame.size.height - campusImage.size.height * imageScale) / 2.0
        
        // Load the "region" image
        campusRegionImage = OpenCVWrapper.loadImage(ofName: "campusRegion", andType: "pgm")
        
        // Load the building name dictionary
        let mainBundleURL = Bundle.main.url(forResource:"mainBundle", withExtension:"bundle")!
        let tableFileURL = Bundle(url: mainBundleURL)!.url(forResource:"campusTable", withExtension:"txt")!
        let tableRows = (try! String(contentsOf: tableFileURL, encoding: String.Encoding.utf8).split(separator:"\n"))
        for row in tableRows {
            let rowContent = row.trimmingCharacters(in: .whitespaces).split(separator: " ")
            buildingDict[String(rowContent[0])] = String(rowContent[1])
            // Logs description of all buildings for documentation
            let bInfo = OpenCVWrapper.getRegionProps(forIdx: Int32(rowContent[0])!, basedOnRegions: campusRegionImage)!
            print(String(rowContent[1]) + " is " + formatBuildingInfo(info: bInfo) + ".");
        }
        buildingDict[String(0)] = String("Wasteland")
        //print(buildingDict)
        print("\n")
        
        //campusImageView.image = OpenCVWrapper.drawRegion(withIdx: 57, using: campusRegionImage)
        for (sidx, buildingName) in buildingDict {
            if sidx != "0" {
                OpenCVWrapper.drawRegion(withIdx: Int32(sidx)!, basedOnRegionImage: campusRegionImage, using: campusImage);
            }
        }
        
        relativeDict = OpenCVWrapper.getRelativeProps(usingRegions: campusRegionImage, andNames: buildingDict) as! [String : String];
        
        /*
        for i in 0..<275 {
            print(i)
            for j in 0..<495 {
                pixelDescriptions[i][j] = OpenCVWrapper.getPixelDescription(from:campusRegionImage, atX:CGFloat(i), andY:CGFloat(j));
            }
        }
        */
        let descriptionArray = OpenCVWrapper.getAllPixelDescriptions(from: campusRegionImage)!;
        for i in 0..<275 {
            for j in 0..<495 {
                pixelDescriptions[i][j] = descriptionArray[i * 495 + j] as! String
            }
        }
        
        // Points with the largest and smallest cloud
        var descriptionCounter = [String:Int]()
        var descriptionLocations = [String:String]()
        var maxDescription: String = ""
        var maxCount: Int = 0
        var minDescription: String = ""
        var minCount: Int = 275 * 495
        for i in 0..<275 {
            for j in 0..<495 {
                if let count = descriptionCounter[pixelDescriptions[i][j]] {
                    descriptionCounter[pixelDescriptions[i][j]] = count + 1
                } else {
                    descriptionCounter[pixelDescriptions[i][j]] = 1
                    descriptionLocations[pixelDescriptions[i][j]] = String(i) + "-" + String(j);
                }
                if descriptionCounter[pixelDescriptions[i][j]]! > maxCount {
                    maxCount = descriptionCounter[pixelDescriptions[i][j]]!
                    maxDescription = pixelDescriptions[i][j]
                }
                if descriptionCounter[pixelDescriptions[i][j]]! < minCount {
                    minCount = descriptionCounter[pixelDescriptions[i][j]]!
                    minDescription = pixelDescriptions[i][j]
                }
            }
        }
        //print(descriptionCounter)
        //print(minCount)
        var minLocationStrs = descriptionLocations[minDescription]!.split(separator: "-")
        updateUIOnTap(X: CGFloat(Int(minLocationStrs[0])!), Y: CGFloat(Int(minLocationStrs[1])!))
        print("minCount is " + String(minCount))
        var maxLocationStrs = descriptionLocations[maxDescription]!.split(separator: "-")
        updateUIOnTap(X: CGFloat(Int(maxLocationStrs[0])!), Y: CGFloat(Int(maxLocationStrs[1])!))
        print("maxCount is " + String(maxCount))
        
        updateUIOnTap(X: CGFloat(routes[2][1][0]), Y: CGFloat(routes[2][1][1]))
        
        // Generating an adjacency matrix from the relative relations
        var kCount: Int = 0
        for (sidx, val) in relativeDict {
            print(val)
            regionKeys[kCount] = sidx
            keyIndices[sidx] = kCount
            kCount += 1
        }
        
        for (sidx, val) in relativeDict {
            let entries = val.split(separator: "|")
            for entry in entries {
                let contents = entry.split(separator: ":")
                let targetStr = contents[1]
                let targets = targetStr.split(separator: ",")
                
                if String(contents[0]) == "near" {
                    continue
                }
                for target in targets {
                    adjacencyMatrix[keyIndices[sidx]!][keyIndices[String(target)]!] = true
                }
            }
            print(formatRelativeInfo(of: sidx, with: val))
        }
        
        self.routePicker.dataSource = self
        self.routePicker.delegate = self
    }
    
    func formatRelativeInfo(of building: String, with info: String) -> String {
        let infoEntries = info.split(separator: "|")
        var retStr = buildingDict[building]! + " is "
        for (i, entry) in infoEntries.enumerated() {
            if i > 0 {
                retStr += "; "
            }
            let contents = String(entry).split(separator: ":")
            let targets = String(contents[1]).split(separator: ",")
            let relation = String(contents[0])
            if relation != "near" {
                retStr += ("to the " + relation + " of ")
            } else {
                retStr += "and near "
            }
            for (idx, t) in targets.enumerated() {
                if idx > 0 {
                    retStr += ", "
                }
                retStr += (buildingDict[String(t)]! + "")
            }
        }
        retStr += "."
        return retStr
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return routes.count + 1;
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        if(row == 0) {
            return "-- Please select --"
        }
        return "Route \(row)"
    }
    
    func reverseDirection(dirString: String) -> [String] {
        var results = [String]()
        let dirStrings = dirString.split(separator: ":")
        for s in dirStrings {
            if s.range(of: "west") != nil {
                results.append(s.replacingOccurrences(of: "west", with: "east"))
            } else if s.range(of: "east") != nil {
                results.append(s.replacingOccurrences(of: "east", with: "west"))
            } else if s.range(of: "south") != nil {
                results.append(s.replacingOccurrences(of: "south", with: "north"))
            } else if s.range(of: "north") != nil {
                results.append(s.replacingOccurrences(of: "north", with: "south"))
            } else {
                results.append(String(s))
            }
        }
        return results
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if(row > 0) {
            currentRouteIdx = row - 1
            isRouteTracing = true
            routeCurrentStep = -1
            userSteps.removeAll()
            let targetRoute = routes[row - 1]
            let targetStart = targetRoute[0]
            let targetEnd = targetRoute[1]
            // Find the first building descriptor of the start pixel
            let startD = pixelDescriptions[targetStart[0]][targetStart[1]]
            let startDFirst = startD.split(separator: "|")[0]
            let startBuildingIdx = String(startDFirst.split(separator: "-")[0])
            var startDirs = [String]()
            let startDs = startDFirst.split(separator: "-")
            // We use a separate step only if we are outside an buiding
            //print(startDs)
            if startDs[2] != "inside" {
                let startTarget = String(startDs[0])
                let startDirection = reverseDirection(dirString: String(startDs[1]))
                var startStep = "Go "
                var dirCount = 0
                for sd in startDirection {
                    if sd != "near" {
                        if dirCount > 0 {
                            startStep += "and "
                        }
                        startStep += (sd + " ")
                        dirCount += 1
                    }
                }
                startStep += ("to " + buildingDict[startTarget]! + ", " + formatBuildingInfo(info: OpenCVWrapper.getRegionProps(forIdx: Int32(startTarget)!, basedOnRegions: campusRegionImage)) + ".")
                startDirs.append(startStep)
            }
            
            var startPosDescription = formatPixelDescription(description: startD)
            directionDisplay.text = startPosDescription
            fromTextDisplay.text = ""
            stepDisplay.text = ""
            campusImageView.image = campusImage
            print(startPosDescription)
            
            // Find the first building descriptor of the end pixel
            let endD = pixelDescriptions[targetEnd[0]][targetEnd[1]]
            let endDFirst = endD.split(separator: "|")[0]
            let endBuildingIdx = String(endDFirst.split(separator: "-")[0])
            var endDirs = [String]()
            let endDs = endDFirst.split(separator: "-")
            if endDs[2] == "outside" {
                let endTarget = String(endDs[0])
                let endDirection = String(endDs[1]).split(separator: ":")
                var endStep = "Go outside "
                var dirCount = 0
                for ed in endDirection {
                    if String(ed) != "near" {
                        if dirCount > 0 {
                            endStep += "and "
                        }
                        endStep += (String(ed) + " ")
                        dirCount += 1
                    }
                }
                endStep += ("to " + buildingDict[endTarget]! + ", " + formatBuildingInfo(info: OpenCVWrapper.getRegionProps(forIdx: Int32(endTarget)!, basedOnRegions: campusRegionImage)) + ".")
                endDirs.append(endStep)
            } else {
                let endTarget = String(endDs[0])
                let endDirection = String(endDs[1]).split(separator: ":")
                var endStep = "Go "
                var dirCount = 0
                for ed in endDirection {
                    if String(ed) != "near" {
                        if dirCount > 0 {
                            endStep += "and "
                        }
                        endStep += (String(ed) + " ")
                        dirCount += 1
                    }
                }
                endStep += ("and stay inside.")
                endDirs.append(endStep)
            }
            
            let buildingPath = findPathUsingBFS(from: startBuildingIdx, to: endBuildingIdx)
            var buildingDirs = [String]()
            for (idx, source) in buildingPath.enumerated() {
                if idx == buildingPath.count - 1 {
                    continue
                }
                let target = buildingPath[idx + 1]
                let relations = relativeDict[target]!.split(separator: "|")
                var directions = [String]()
                for relation in relations {
                    let direction = String(relation.split(separator: ":")[0])
                    let candidates = String(relation.split(separator: ":")[1]).split(separator: ",")
                    for c in candidates {
                        if String(c) == source {
                            directions.append(direction)
                        }
                    }
                }
                var dCount = 0
                var currentStep: String = "Go "
                for d in directions {
                    if d != "near" {
                        if(dCount > 0) {
                            currentStep += "and "
                        }
                        currentStep += d + " "
                    }
                    dCount += 1
                }
                currentStep += "to "
                /*
                if directions.contains("near") {
                    currentStep += "near ";
                }
                */
                currentStep += buildingDict[target]! + ", " + formatBuildingInfo(info: OpenCVWrapper.getRegionProps(forIdx: Int32(target)!, basedOnRegions: campusRegionImage)) + "."
                //print(currentStep)
                buildingDirs.append(currentStep)
            }
            routeSteps = startDirs + buildingDirs + endDirs
            print(routeSteps)
        } else {
            isRouteTracing = false
        }
    }
    
    func findPathUsingBFS(from: String, to: String) -> [String] {
        let fromIdx = keyIndices[from]!
        let toIdx = keyIndices[to]!
        var backTrace = [Int:Int]()
        var q = [Int]()
        q.append(fromIdx)
        var found: Bool = false;
        var notDiscovered = Array(repeating: true, count: 26)
        notDiscovered[fromIdx] = false
        while q.count > 0 {
            let currentIdx = q.removeFirst()
            for (idx, val) in adjacencyMatrix[currentIdx].enumerated() {
                if val && notDiscovered[idx] {
                    backTrace[idx] = currentIdx
                    q.append(idx)
                    notDiscovered[idx] = false
                    if(idx == toIdx) {
                        found = true;
                        break
                    }
                }
            }
            if(found) {
                break
            }
        }
        var route = [String]()
        if(found) {
            var currentNode = toIdx
            while true {
                route.insert(regionKeys[currentNode], at: 0)
                if let nextNode = backTrace[currentNode] {
                    print(regionKeys[currentNode] + " -> " + regionKeys[nextNode]);
                    currentNode = nextNode;
                } else {
                    break;
                }
            }
        }
        return route
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
        
        print("this is a memory warning")
    }
    
    func findConfusionAt(X: Int, Y: Int) -> Int {
        var count: Int = 0;
        for i in 0..<275 {
            for j in 0..<495 {
                if pixelDescriptions[i][j] == pixelDescriptions[X][Y] {
                    count = count + 1;
                }
            }
        }
        return count
    }
    
    func showUserSteps() {
        var displayStr = ""
        for step in userSteps {
            displayStr += String(format: "(%d, %d)\n", step[0], step[1])
        }
        print(userSteps.count)
        print(routeSteps.count)
        if(routeCurrentStep >= routeSteps.count) {
            displayStr += "Finished!\n"
            let dist = sqrt(pow(Float(userSteps.last![0] - routes[currentRouteIdx][1][0]), 2) + pow(Float(userSteps.last![1] - routes[currentRouteIdx][1][1]), 2))
            displayStr += String(format: "Distance to indended point is %f", dist)
        }
        stepDisplay.text = displayStr
    }
    
    func formatPixelDescription(description: String) -> String {
        let dEntries = description.split(separator: "|")
        var dString: String = "You are: \n\n"
        var entryCount: Int = 0
        for entry in dEntries {
            if entryCount > 0 {
                dString += "; \n\n"
            }
            entryCount += 1
            let elements = entry.split(separator: "-")
            let info = OpenCVWrapper.getRegionProps(forIdx: Int32(elements[0])!, basedOnRegions: campusRegionImage);
            dString += ("- " + elements[2] + " ")
            dString += (elements[1].replacingOccurrences(of: ":", with: " and ") + " of ")
            dString += (buildingDict[String(elements[0])]! + ", ")
            dString += (formatBuildingInfo(info: info!))
            entryCount += 1
        }
        dString += ". "
        return dString
    }
    
    func updateUIOnTap(X: CGFloat, Y: CGFloat) {
        let regionIdx = OpenCVWrapper.getTappedRegion(from: campusRegionImage, atX: X, andY: Y)
        print(String(regionIdx))
        print(buildingDict[String(regionIdx)]!)
        
        let description = pixelDescriptions[Int(X)][Int(Y)]
        /*
        let dEntries = description.split(separator: "|")
        var dString: String = "You are: \n\n"
        var entryCount: Int = 0
        for entry in dEntries {
            if entryCount > 0 {
                dString += "; \n\n"
            }
            entryCount += 1
            let elements = entry.split(separator: "-")
            let info = OpenCVWrapper.getRegionProps(forIdx: Int32(elements[0])!, basedOnRegions: campusRegionImage);
            dString += ("- " + elements[2] + " ")
            dString += (elements[1].replacingOccurrences(of: ":", with: " and ") + " of ")
            dString += (buildingDict[String(elements[0])]! + ", ")
            dString += (formatBuildingInfo(info: info!))
            entryCount += 1
        }
        dString += ". "*/
        
        let dString = formatPixelDescription(description: description)
        
        /*
        if regionIdx != 0 {
            //let info = OpenCVWrapper.getRegionProps(forIdx: regionIdx, basedOnRegions: campusRegionImage);
            //campusImageView.image = OpenCVWrapper.drawRegion(withIdx: regionIdx, basedOnRegionImage: campusRegionImage, using: campusImage);
            fromTextDisplay.text = buildingDict[String(regionIdx)]! + formatBuildingInfo(info: info!) + "\n" + relativeDict[String(regionIdx)]! + "\n" + dString
        } else {
            fromTextDisplay.text = dString
        }
        */
        fromTextDisplay.text = dString
        
        var xs: [Int] = []
        var ys: [Int] = []
        for i in 0..<275 {
            for j in 0..<495 {
                if pixelDescriptions[i][j] == pixelDescriptions[Int(X)][Int(Y)] {
                    xs.append(i)
                    ys.append(j)
                }
            }
        }
        campusImageView.image = OpenCVWrapper.drawPixels(onCampusImage: campusImage, atXs: xs, andYs: ys, with: UIColor.orange)
        
        if(isRouteTracing) {
            routeCurrentStep += 1
            if routeCurrentStep < routeSteps.count {
                directionDisplay.text = routeSteps[routeCurrentStep]
                userSteps.append([Int(X), Int(Y)])
                showUserSteps()
            } else if routeCurrentStep == routeSteps.count {
                directionDisplay.text = "You should be there."
                userSteps.append([Int(X), Int(Y)])
                showUserSteps()
            }
        }
        
        //campusImageView.image = campusImage
    }
    
    @objc func imageTapped(tapGestureRecognizer: UITapGestureRecognizer) {
        let location = tapGestureRecognizer.location(in: tapGestureRecognizer.view);
        let imageLocation = getImageCoordinates(touchX: location.x, touchY: location.y)
        print(imageLocation)
        //print(imageLocation)
        //campusImage = OpenCVWrapper.drawCircle(onCampusImage: campusImage, atX: imageLocation.x, andY: imageLocation.y, withRadius: 10.0, andColor: UIColor.orange)
        //campusImageView.image = campusImage;
        
        updateUIOnTap(X: imageLocation.x, Y: imageLocation.y)
    }
    
    func formatBuildingInfo(info: Dictionary<AnyHashable, Any>) -> String {
        let cinfo = info as! [String:String]
        var ret: String = "a "
        ret = ret + cinfo["size"]! + ", "
        ret = ret + cinfo["proportions"]! + ", "
        ret = ret + cinfo["letterShape"]! + " building that "
        ret = ret + cinfo["contour"]! + ", is "
        ret = ret + cinfo["symmetry"]! + ", "
        ret = ret + cinfo["quadrant"]! + " and "
        ret = ret + cinfo["boundary"]!
        /*
        ret = ret + cinfo["boundary"]
        for (k, val) in cinfo {
            ret += (k + ": " + val + "\n")
        }
        */
        return ret
    }
    
    func getImageCoordinates(touchX: CGFloat, touchY: CGFloat) -> (x: CGFloat, y: CGFloat) {
        let frameX = touchX - imageXPadding;
        let frameY = touchY - imageYPadding;
        return (x: frameX / imageScale, y: frameY / imageScale)
    }
}

