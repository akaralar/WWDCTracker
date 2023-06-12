import PlaygroundSupport
import UIKit

let file = "contents.json"
let url = URL(string: "https://api2021.wwdc.io/contents.json")!

print("Hello")

var useWeb = true

var jsonData: JSONData!
var contents: [Video]
var topicsById: [Int: String]

let semaphore = DispatchSemaphore(value: 0)

if useWeb {
  let session = URLSession(configuration: .default)
  let task = session.dataTask(with: URLRequest(url: url)) { data, _, _ in
    guard let data = data else { return }
    jsonData = data.decode(JSONData.self, dateDecodingStrategy: .iso8601)
    semaphore.signal()
  }
  task.resume()
} else {
  jsonData = Bundle.main.decode(JSONData.self, from: file)
  semaphore.signal()
}

semaphore.wait()
contents = jsonData.contents
topicsById = jsonData.topics.reduce(into: [:], { result, next in
  result[next.id] = next.name
})

let printFormatter = DateFormatter()
printFormatter.dateFormat = "dd/MM E" // We set a custom format to make sorting easier

let secondsFormatter = NumberFormatter()
secondsFormatter.minimumIntegerDigits = 2

func day(from date: Date) -> String {
  printFormatter.string(from: date)
}

func formattedDuration(for durationInSeconds: Int) -> String {
  if let seconds = secondsFormatter.string(from: (durationInSeconds % 60) as NSNumber) {
    return "\(durationInSeconds / 60):\(seconds);"
  } else {
    return ""
  }
}

// The JSON doesn't include visionOS yet, so we add it manually if 'spatial' is mentioned
func fixedPlatforms(title: String, topics: String, platforms: [String]) -> String {
  var platforms = platforms

  if topics.lowercased().contains("spatial") || title.lowercased().contains("spatial") {
    platforms.append("visionOS")
  }

  return "\(platforms.joined(separator: ", ")); "
}

// The events we want to create csv files for
let eventIDs = ["wwdc2020", "wwdc2021", "wwdc2022", "wwdc2023"]

// Some events like recap events etc include the following in their names, we will ignore them
let filterWords = ["@WWDC21", "WWDC22", "WWDC23"]

let header = "Session #; Title; Topics; Platforms; Date; Length; Link; Favourite; Watched; Uninterested;\n"
var output = eventIDs.reduce(into: [:], { result, next in result[next] = header })

for item in contents where output[item.eventId] != nil && item.type == "Video" {
  // If an item doesn't have a platform assigned and includes one of the filter words in title,
  // we ignore and print to the console
  if item.platforms == nil && !filterWords.allSatisfy({ !item.title.contains($0) }) {
    print("Item not included: \(item.title) - \(item.webPermalink)")
    continue
  }

  guard var outputString = output[item.eventId] else { continue }

  outputString += "\(item.id); "
  outputString += "\(item.title); "

  let topics = item.topicIds.compactMap { topicsById[$0] }.joined(separator: ", ")
  outputString += topics
  outputString += "; "

  outputString += fixedPlatforms(title: item.title, topics: topics, platforms: item.platforms ?? [])

  if let publishDate = item.originalPublishingDate {
    let day = day(from: publishDate)
    outputString += "\(day); "
  } else {
    outputString += "; "
  }

  if let media = item.media {
    outputString += formattedDuration(for: media.duration)
  } else {
    outputString += "; "
  }

  outputString += "\(item.webPermalink); "

  outputString += " ; ; ;\n"

  output[item.eventId] = outputString
}

let outputFolder = PlaygroundSupport.playgroundSharedDataDirectory
for (eventID, outputString) in output {
  let outputURL = outputFolder.appendingPathComponent("\(eventID).csv")

  do {
    try FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true, attributes: nil)
    try outputString.write(toFile: outputURL.path, atomically: false, encoding: .utf8)
  } catch {
    print(error.localizedDescription)
  }

  print("Open \(eventID).csv via:")
  print("open", outputURL.path.replacingOccurrences(of: " ", with: "\\ "))
}
