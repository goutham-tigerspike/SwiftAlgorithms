/*:
 # Swift Async Algorithms

 Most of us have embraced `async/await` as the safest way of handling concurrency in our code, the next step for Swift concurrency is asynchronous loops.

 The [Swift Async Algorithms](https://github.com/apple/swift-async-algorithms) package is a set of algorithms specifically focused on processing values over time using the `AsyncSequence` protocol. This package sits along side [Swift Collections](https://github.com/apple/swift-collections) and the [Swift Algorithms package](https://github.com/apple/swift-algorithms).

 ----

 First, lets do a quick recap.

 ## What is a `Sequence`?

 A sequence is a list of values that you can step through one at a time.

 The most common way to iterate over the elements of a sequence is to use a for-in loop:
 */
import Foundation

let range = 1...3

//for number in range {
//    print(number)
//}
/*:
 ----
 ## How to make a custom `Sequence`?

 Of course, we can also write our own custom `Sequence` types. For example, here we have a `Countdown` struct that accepts a `count` variable of type `Int`.

 You may have noticed the `IteratorProtocol` protocol which is tightly linked with the `Sequence` protocol.

 Sequences provide access to their elements by creating an iterator, which keeps track of its iteration process and returns one element at a time as it advances through the sequence which you can see in the `next()` function.
 */
struct Countdown: Sequence, IteratorProtocol {
    var count: Int

    mutating func next() -> Int? {
        if count == 0 { // If the count is zero, return `nil` as there is nothing to count down to
            return nil // The iteration process is terminated if we return `nil`.
        } else {
            defer { count -= 1 } // `defer` statements get executed prior to exiting the scope
            // Do any work here... We will add some code here later on
            return count
        }
    }
}
/*:
 And now, if we were to use our custom `Sequence`:
 */
//let threeToGo = Countdown(count: 3)
//for i in threeToGo {
//    print(i)
//}
/*:
 ----
 ## What is an `AsyncSequence`?
 `AsyncSequence` is a protocol that lets you describe values produced asynchronously. Basically, it's just like Sequence, but has two key differences:
 - The next function from its iterator is asynchronous, being that it can deliver values using Swift concurrency.
 - It also lets you handle any potential failures using Swift's throw effect.

 Just like sequence, you can iterate it, using the `for-await-in` syntax. Let's take a look at our previous custom `Sequence` `Countdown` class and convert it so that it iterates over each element every second:
 */
import _Concurrency

struct AsyncCountdown: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = Int
    var count: Int

    mutating func next() async -> Int? {
        if count == 0 {
            return nil
        } else {
            defer { count -= 1 }

            do {
                // Suspend the current Task for a second before returning the next element
                try await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            } catch let error {
                // Handle errors as needed
                print(error)
                return nil
            }

            return count
        }
    }

    // Won't go too deep into this function but it's been used for more complex iterators that define a separate `AsyncIteratorProtocol` struct
    func makeAsyncIterator() -> AsyncCountdown {
        self
    }
}
/*:
 - Note:
 Task is a unit of asynchronous work and was introduced at WWDC 2021 as a part of async/await. A task allows us to create a concurrent environment from a non-concurrent method. Also, [`Thread.sleep` is different to `Task.sleep`](https://trycombine.com/posts/thread-task-sleep/)

 ![Sleep comparison](sleep-comparison.png)

 ----

 Now lets look at how we would iterate over our custom `AsyncSequence`:
 */
let asyncThreeToGo = AsyncCountdown(count: 3)

// No concurrency at the top level Swift Playgrounds so this is a work around by wrapping the `await` in a `Task`
//Task {
//    for await i in asyncThreeToGo {
//        print("AsyncCountdown: \(i)")
//    }
//}
/*:
 ----

 Now that we have the basics, lets look at a more real world example.

 Here we have a `struct` `Earthquakes` with a `fetch` function that gets a list of recent earthquakes in the US from a CSV file.

 Since we don't want to wait for all the things to download, we can show them as we recieve them by using the `lines` property on URL. `lines` is an `AsyncLineSequence` which conforms to `AsyncSequence` with `String` as its element. Essentially, an asychronous sequence of lines of text.

 The first three lines of the CSV is as follows:
 ````
 time,latitude,longitude,depth,mag,magType,nst,gap,dmin,rms,net,id,updated,place,type,horizontalError,depthError,magError,magNst,status,locationSource,magSource
 2022-06-22T04:29:40.610Z,38.8241653,-122.7991638,1.61,1.65,md,34,31,0.008557,0.02,nc,nc73749381,2022-06-22T04:32:34.673Z,"6km NW of The Geysers, CA",earthquake,0.16,0.27,0.05,7,automatic,nc,nc
 2022-06-22T04:09:47.000Z,33.6681667,-117.0653333,-0.28,0.61,ml,14,108,0.2621,0.31,ci,ci40288832,2022-06-22T04:13:32.321Z,"5km SSE of Winchester, CA",earthquake,0.99,31.61,0.085,5,automatic,ci,ci
 ````
 */
struct Earthquakes {
    static func fetch() async throws {
        let url = URL(string: "http://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/all_month.csv")!

        // Skip the first header line and iterate over each one to get the individual values
        // Calling an async function / property will suspend and will resume when a value is produced
        for try await event in url.lines.dropFirst() {
            // Each value is seperated by a comma
            let values = event.split(separator: ",")
            let time = values[0]
            let latitude = values[1]
            let longitude = values[2]
            let magnitude = values[3]
            print("Magnitude \(magnitude) on \(time) at \(latitude) \(longitude)")
        }
    }
}

//Task {
//    try await Earthquakes.fetch()
//}
/*:
 This is the difference reading a file asynchronously vs synchronously line by line

 ![Async](readAsync-memory.png)

 ![Sync](readSync-memory-spike.png)
 ----
 When `AsyncSequence` was introduced, it had almost all the tools you would expect to find with `Sequence` right there with the async versions. You have algorithms like `map`, `filter`, `reduce`, and more.

 ----

 ## Relation between Swift Algorithms and Swift Async Algorithms packages

 The **Swift Algorithms** which was introduced last year is a package of sequence and collection algorithms, along with their related types. It includes algorithms such as:
 - `combinations(ofCount:):` Combinations of particular sizes of the elements in a collection.
 - `permutations(ofCount:):` Permutations of a particular size of the elements in a collection, or of the full collection.
 - `uniquePermutations(ofCount:):` Permutations of a collection's elements, skipping any duplicate permutations.
 - `rotate(toStartAt:)`, rotate(subrange:toStartAt:): In-place rotation of elements.
 - `stablePartition(by:)`, stablePartition(subrange:by:): A partition that preserves the relative order of the resulting prefix and suffix.
 - `chain(_:_:):` Concatenates two collections with the same element type.
 - and much more...

 **Swift Async Algorithms** takes these concepts a step further by incorporating async/await, more advanced algorithms, as well as clocks for some powerful stuff.

 ----

 ## Zip
 First off, lets take a look at the `zip` algorithm in the Async Algorithms package. Zip combines values produced into tuples while iterating concurrently. And while there are many algorithms focused on combining AsyncSequences together in different ways similar to `zip`, they share one characteristic: They take multiple input AsyncSequences and produce one output AsyncSequence.
*/
let appleFeed = URL(string: "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=AAPL&apikey=9MYTV48H0CT80A64&datatype=csv")!.lines.dropFirst()
let ibmFeed = URL(string: "https://www.alphavantage.co/query?function=TIME_SERIES_DAILY&symbol=IBM&apikey=9MYTV48H0CT80A64&datatype=csv")!.lines.dropFirst()

extension Double {
    /// Rounds the double to decimal places value
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}

func getPercentageChange(oldNumber: Double, newNumber: Double) -> String {
    let difference = oldNumber - newNumber
    let percentage = (difference / oldNumber) * 100
    let symbol = percentage < 0 ? "+" : "-"
    return symbol + String(abs(percentage.rounded(toPlaces: 2)))
}

Task {
    for try await (apple, ibm) in zip(appleFeed, ibmFeed) {
        let (appleValues, ibmValues) = (apple.split(separator: ","), ibm.split(separator: ","))
        let (appleOpen, ibmOpen) = (appleValues[1], ibmValues[1])
        let (appleClose, ibmClose) = (appleValues[4], ibmValues[4])
        let applePercentage = getPercentageChange(oldNumber: Double(appleOpen)!, newNumber: Double(appleClose)!)
        let ibmPercentage = getPercentageChange(oldNumber: Double(ibmOpen)!, newNumber: Double(ibmClose)!)
        print("APPL: \(applePercentage) IBM: \(ibmPercentage)")
    }
}
/*:
 Lets look at a more complex scenario:
  - Get images from local resource
  - Compress an image into two (large & small) thumbnails
  - Wait until both of these images are compressed & uploaded before the next iteration

 Lets create an AsyncSequence that compresses images as it iterates through them:
 */
import UIKit
import AsyncAlgorithms

struct ImageCompressor: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = UIImage
    var images: [UIImage]
    let size: CGSize

    init(compress images: [UIImage], to size: CGSize) {
        self.images = images
        self.size = size
    }

    mutating func next() async -> UIImage? {
        guard images.first != nil else { return nil }
        let image = images.removeFirst()
        return await image.byPreparingThumbnail(ofSize: size)
    }

    func makeAsyncIterator() -> ImageCompressor {
        self
    }
}
/*:
  - Note:
 You don't have to always make your own `AsyncSequence`. In fact it may be easier to adopt `AsyncStream` to make it easier to migrate certain parts of your app. Especially when you're thinking about writing your own `AsyncSequences` in the projects you are working on. As I've mentioned before, we can use [`AsyncStream` & `AsyncThrowingStream`](https://www.gfrigerio.com/create-your-own-asyncsequence/) for sequences that can throw to make it easier. This method also makes it easier to adapting existing code to turn them into streams.
 */
func compress(images: [UIImage], to size: CGSize) -> AsyncStream<UIImage> {
    AsyncStream { continuation in
        Task {
            for image in images {
                guard let compressedImage = await image.byPreparingThumbnail(ofSize: size) else {
                    continuation.finish()
                    return
                }
                continuation.yield(compressedImage)
            }
            continuation.finish()
        }
    }
}
/*:
 Lets also define some potential sizes
 */
enum Size {
    static let small = CGSize(width: 128, height: 128)
    static let medium = CGSize(width: 256, height: 256)
    static let large = CGSize(width: 512, height: 512)
}
/*:
 Load a bunch of people's faces (1024x1024)
 */
let images = (1...10).map { index in
    return UIImage(named: "\(index).jpeg")!
}
/*:
 Lets create our fake upload function with randomized success intervals
 */
let seconds: [UInt64] = [1_000_000_000, 2_000_000_000, 3_000_000_000, 4_000_000_000] // In nanoseconds

func upload(smallImage: UIImage, largeImage: UIImage) async throws {
    try await Task.sleep(nanoseconds: 1 * seconds.randomElement()!)
    let smallImageSizeInKB = Double(smallImage.pngData()!.count) / 1000.0
    let largeImageSizeInKB = Double(largeImage.pngData()!.count) / 1000.0
    print("Successfully uploaded images with small image's file size \(smallImageSizeInKB)KB & large image's file size \(largeImageSizeInKB)KB")
}
/*:
 Now lets use it!
 */

//Task {
//    for try await (smallImage, largeImage) in
//            zip(ImageCompressor(compress: images, to: Size.small),
//                compress(images: images, to: Size.large)) {
//        smallImage
//        largeImage
//        try await upload(smallImage: smallImage, largeImage: largeImage)
//    }
//}
/*:
## Clocks
 [Clock is a new swift protocol for defining time.](https://developer.apple.com/documentation/swift/clock?changes=l__1&language=o_5)
 - Defines a way to wake up after a given instant
 - Defines a concept of now

 There are pre-built clocks such as the `ContinuousClock` and `SuspendingClock`

 `ContinuousClock` works just like a stop watch measuring the progression of time no matter the state
 `SuspendingClock` suspends when the device is asleep such as when the laptop's lid is closed

 You may remember earlier we waited for a second using:

 `try await Task.sleep(nanoseconds: 1 * 1_000_000_000)`

 Task uses the new Clock protocol allowing us to instead write it as:

 `try await Task.sleep(until: .now + .seconds(1), clock: .continuous)`

 You may notice this is similar to how we handle `DispatchTime` in GCD. While this may seem longer to write, it is much more readable and can be utilized in cases where we want to implement our own custom clocks.

 [This newer API also comes with the benefit of being able to specify tolerance, which allows the system to wait a little beyond the sleep deadline in order to maximize power efficiency. So, if we wanted to sleep for at least 1 seconds but would be happy for it to last up to 1.5 seconds in total, we would write this:](https://www.hackingwithswift.com/swift/5.7/clock)

 `try await Task.sleep(until: .now + .seconds(1), tolerance: .seconds(0.5), clock: .continuous)`

 Although it hasn’t happened yet, it looks like the older nanoseconds-based API will be deprecated in the near future.

 ----

 ## Debounce

 Lets use the debounce async algorithm and clocks:
 */
struct AsyncFakeTypingSequence: AsyncSequence, AsyncIteratorProtocol {
    typealias Element = String

    var currentIndex: Int = 0
    private var joined = [String]()

    init(query: String) {
        let splitQuery = Array(query).map { String($0) }
        joined = splitQuery
        splitQuery.enumerated().forEach { index, character in
            joined[index] = splitQuery[0...index].joined()
        }
    }

    mutating func next() async -> String? {
        do {
            guard joined.first != nil else { return nil }
            let query = joined.removeFirst()
            try await Task.sleep(nanoseconds: 100_000_000)
            return query
        } catch {
            return nil
        }
    }

    func makeAsyncIterator() -> AsyncFakeTypingSequence {
        self
    }
}

guard
    let path = Bundle.main.path(forResource:"query", ofType: "txt"),
    let string = try? String(contentsOf: URL(filePath: path)),
    let data = FileManager.default.contents(atPath: path) else {
    fatalError("Can not get file")
}

//Task {
//    for await sentQuery in AsyncFakeTypingSequence(query: string).throttle(for: .milliseconds(500)) {
//        print("Sending request for: \"\(sentQuery)\"")
//    }
//}
/*:
 ----
Swift Async Algorithms package also extends the normal `Sequence` function with a convenient `AsyncLazySequence` extension

 ```
 extension Sequence {
 /// An asynchronous sequence containing the same elements as this sequence,
 /// but on which operations, such as `map` and `filter`, are
 /// implemented asynchronously.
 @inlinable
 public var async: AsyncLazySequence<Self> {
     AsyncLazySequence(self)
   }
 }
 ```

 `AsyncLazySequence` is an asynchronous sequence composed from a synchronous sequence. We can use this to interface existing or pre-calculated data to interoperate with other asynchronous sequences and algorithms based on asynchronous sequences.

  Now that we know a little bit about clocks and debounce, lets rewrite our `AsyncCountDown` function using `AsyncLazySequence` and the `Clock` protocol
 */
let numbers = [1, 1, 2, 3, 4, 5, 6, 6, 7, 8, 9, 10]
//Task {
//    for await countUp in numbers
//        .async
//        .removeDuplicates()
//        .chunks(ofCount: 2)
//    {
//        print(countUp)
//    }
//}
/*:
 Thats it! some further points:
 * Apple is adding more and more async properties to classes such as `Data` and `URLSession`
 * There are also more methods to explore in the package which will reduce the need to import Combine
 * Swift's concurrency uses continuation which is a lightweight object to track where to resume work on a suspended task. Switching between task continuations is much cheaper and more efficient as opposed to performing GCD's thread context switches
 * [Push & Pull based `AsyncStream`](https://www.raywenderlich.com/34044359-asyncsequence-asyncstream-tutorial-for-ios):
    * Push - Your code wants values faster than the asynchronous sequence can make them.
    * Pull - Generates elements faster than your code can read them, or at irregular or unpredictable intervals — API, notifications, location, etc.
 */
RunLoop.main.run()
