<!-- notion-id: 2f0e582f-073d-80f0-a3b3-defec11d2bde -->
The implementation focuses on rendering a feed of images within a `UITableView` using the Model-View-Controller (MVC) pattern. The system is designed to handle the full lifecycle of asynchronous image loading, implementing the following goals:
<!-- notion-id: 2eee582f-073d-8000-b509-dfac2f5c0c41 -->
```plain text
[✅] Render all loaded feed items (location, image, description)
[✅] Image loading experience
    [✅] Load when image view is visible (on screen)
    [✅] Cancel when image view is out of screen
    [✅] Show a loading indicator while loading image (shimmer)
    [✅] Option to retry on image download error
    [✅] Preload when image view is near visible
```
<!-- notion-id: 2f0e582f-073d-8070-87f5-d1808dd69c7c -->
The architectural goal is to decouple the UI from the data retrieval logic using the Dependency Inversion Principle. However, the aggregation of responsibilities within the `FeedViewController` (managing rendering, refreshing, loading state, and image request tasks) serves as a case study for identifying the "Massive View Controller" anti-pattern.
<!-- notion-id: 2eee582f-073d-8050-9fc3-dd906a5686c3 -->

<!-- notion-id: 2f0e582f-073d-8014-9e22-c71a1a0a1b3f -->
# Architecture
<!-- notion-id: 2f0e582f-073d-80fd-981b-e298eaa6ba77 -->
## **Dependency Structure & Inversion**
<!-- notion-id: 2f0e582f-073d-8072-bff6-c30fdca9d576 -->
The `FeedViewController` does not depend on concrete API implementations. Instead, it relies on two distinct abstractions:
<!-- notion-id: 2f0e582f-073d-80d7-af8e-eec3460ee7bb -->
1. **`FeedLoader`**: Responsible for retrieving the array of `FeedImage` models.
<!-- notion-id: 2f0e582f-073d-8075-b186-eed813ecb249 -->
1. **`FeedImageDataLoader`**: Responsible for retrieving binary image data for a specific URL.
<!-- notion-id: 2f0e582f-073d-801e-9a3a-c819ef2a04ab -->
This structure allows the rendering logic to remain agnostic of the data source (network, cache, or database).
<!-- notion-id: 2f0e582f-073d-800b-9d40-efef711c165b -->

<!-- notion-id: 2f0e582f-073d-80aa-b126-d58afd7692bc -->
## **Interface Segregation & State Management**
<!-- notion-id: 2f0e582f-073d-80de-9006-ea30fc64bde6 -->
Initial designs considered a `FeedImageDataLoader` protocol containing both `loadImageData(from:)` and `cancelImageDataLoad(from:)`. This approach violates the Interface Segregation Principle (ISP) by forcing the *loader* to maintain the state of running tasks to identify which request to cancel.
<!-- notion-id: 2f0e582f-073d-8095-af45-d5384b3175e4 -->
To resolve this, the responsibility of state management is inverted to the consumer (`FeedViewController`) via the return type.
<!-- notion-id: 2f0e582f-073d-8003-af67-e01cea022e96 -->
- **Feed Image Protocol**:
<!-- notion-id: 2f0e582f-073d-80bb-a654-c4dadce5073d -->
- **Task Abstraction**:
<!-- notion-id: 2f0e582f-073d-8090-8b9e-ff40a95d0a97 -->
The `FeedViewController` manages the state of active requests using a dictionary mapping `IndexPath` to `FeedImageDataLoaderTask`. This allows the loader implementation to remain stateless, while the controller manages the lifecycle of the tasks.
<!-- notion-id: 2f0e582f-073d-80d1-909c-c79320860e05 -->
# **The Massive View **Controller** Anti-Pattern**
<!-- notion-id: 2f0e582f-073d-80fd-ac54-c6e26c412c07 -->
By the conclusion of the implementation, the `FeedViewController` manages:
<!-- notion-id: 2f0e582f-073d-8055-8760-fb6a37cf58bb -->
- **3 Views**: `UIRefreshControl`, `UITableView`, `FeedImageCell`.
<!-- notion-id: 2f0e582f-073d-80e5-afb0-f33125ea62e0 -->
- **4 Models/States**: `FeedLoader` state, `FeedImageDataLoader` state, the `tableModel` (data source), and the `tasks`dictionary (request state).
<!-- notion-id: 2f0e582f-073d-8076-b58f-fae12691dcda -->
While the code remains concise, the coupling of view management, asynchronous request orchestration, and state tracking within a single class indicates a violation of the Single Responsibility Principle, characteristic of the Massive View Controller pattern.
<!-- notion-id: 2f0e582f-073d-8086-b073-ec2be5ab4a87 -->
# Component Isolation
<!-- notion-id: 2f0e582f-073d-8053-bdd7-c62493f214c5 -->
### **FeedImageCell**
<!-- notion-id: 2f0e582f-073d-8033-bf8f-dbcea4419f1d -->
The `FeedImageCell` is a custom `UITableViewCell` designed to handle data binding and user interaction. It employs a lazy-loaded `retryButton` configured with the Target-Action pattern to communicate user intent back to the controller via a closure.
<!-- notion-id: 2f0e582f-073d-8061-93c1-fec3897a1137 -->
- **Retry Logic**: The cell exposes an `onRetry` closure. The controller assigns this closure during cell configuration, linking it to the image reload logic.
<!-- notion-id: 2f0e582f-073d-8002-ae0e-dacf57910dd0 -->
- **Configuration**: The cell toggles the visibility of the `locationContainer` based on the presence of data, ensuring the UI adapts to the model state.
<!-- notion-id: 2f0e582f-073d-8022-afab-e4d0f12b918f -->
```swift
public final class FeedImageCell: UITableViewCell {
    public let locationContainer = UIView()
    public let locationLabel = UILabel()
    public let descriptionLabel = UILabel()
    public let feedImageContainer = UIView()
    public let feedImageView = UIImageView()
    
    private(set) public lazy var feedImageRetryButton: UIButton = {
        let button = UIButton()
        button.addTarget(self, action: #selector(retryButtonTapped), for: .touchUpInside)
        return button
    }()
    
    var onRetry: (() -> Void)?
    
    @objc private func retryButtonTapped() {
        onRetry?()
}
```
<!-- notion-id: 2f0e582f-073d-80b7-be13-e2ff863cb779 -->
## **Shimmering Animation**
<!-- notion-id: 2f0e582f-073d-8092-bbe3-cbf4599d3e37 -->
A `UIView` extension handles the visual indication of loading. It applies a `CAGradientLayer` as a mask to the view's layer and animates the `locations` property to create a shimmering effect. This logic is isolated from the cell to promote reusability.
<!-- notion-id: 2f0e582f-073d-80b8-baa4-d121a061eb4f -->
**Resource Efficiency (Prefetching & Cancellation)**
<!-- notion-id: 2f0e582f-073d-800d-a132-ce8ce235b173 -->
To ensure a smooth user experience, the system implements `UITableViewDataSourcePrefetching`:
<!-- notion-id: 2f0e582f-073d-8073-a9d9-d36faa9eeb9b -->
- **Prefetching**: When `tableView(_:prefetchRowsAt:)` is called, the controller triggers image data loads for the specified index paths without binding the result to a UI element immediately.
<!-- notion-id: 2f0e582f-073d-802c-8cc7-f4ce17450ea2 -->
- **Cancellation**: When `tableView(_:didEndDisplaying:forRowAt:)` or `tableView(_:cancelPrefetchingForRowsAt:)` is invoked, the controller retrieves the associated task from its state dictionary and calls `cancel()`. This prevents wasted bandwidth on off-screen content.
<!-- notion-id: 2f0e582f-073d-80bd-a7a9-f8d35dca138b -->
# Test Strategy
<!-- notion-id: 2f0e582f-073d-8089-a9b3-f263f7cd23ee -->
## **Spy Architecture**
<!-- notion-id: 2f0e582f-073d-8064-a8df-f078362a04d7 -->
A single `LoaderSpy` class is utilized to capture both feed and image data requests. It conforms to both `FeedLoader` and `FeedImageDataLoader`.
<!-- notion-id: 2f0e582f-073d-8060-83ea-cae0c7ba918f -->
- **Request Tracking**: The spy maintains arrays of completion blocks (`feedRequests`) and request parameters (`imageRequests`) to enable deterministic control over asynchronous callbacks.
<!-- notion-id: 2f0e582f-073d-8011-b4e1-f6567fa266fa -->
- **Task Spying**: The `loadImageData` method returns a `TaskSpy`, which captures cancellation events. This allows tests to verify that resources are released correctly when views go off-screen.
<!-- notion-id: 2f0e582f-073d-80af-9336-c0b980f7d23e -->
```swift
class LoaderSpy: FeedLoader, FeedImageDataLoader {
       
    private var feedRequests = [(FeedLoader.Result) -> Void]() 
    // ...
    private var imageRequests = [(url: URL, completion: (FeedImageDataLoader.Result) -> Void)]()
    // ...
		private struct TaskSpy: FeedImageDataLoaderTask {
        let cancelCallback: () -> Void
        func cancel() {
            cancelCallback()
        }
    }
}


```
<!-- notion-id: 2f0e582f-073d-8069-9dca-e37d575c36ea -->
## **DSL & Abstraction**
<!-- notion-id: 2f0e582f-073d-8054-9157-f58cdc4cccef -->
Domain-Specific Language (DSL) methods are extensively used to decouple tests from UIKit implementation details:
<!-- notion-id: 2f0e582f-073d-80eb-9883-da432261fdf0 -->
- **`assertThat(_:isRendering:)`**: Verifies that the table view rendering matches the expected state of the `FeedImage`models.
<!-- notion-id: 2f0e582f-073d-808d-bd9b-ffa15e8dd5d6 -->
- **`simulateFeedImageViewVisible(at:)`**: Triggers the `cellForRowAt` datasource method, simulating the view entering the hierarchy.
<!-- notion-id: 2f0e582f-073d-8004-8018-ebc301c9e956 -->
- **`simulateFeedImageViewNearVisible(at:)`**: Triggers the `prefetchRowsAt` delegate method.
<!-- notion-id: 2f0e582f-073d-80f8-b439-e0baa4017d47 -->
- **`simulateRetryAction()`**: Simulates a touch event on the retry button.
<!-- notion-id: 2f0e582f-073d-80a3-bc98-fcf6d3e3227d -->
## **Stubbing Constraints**
<!-- notion-id: 2f0e582f-073d-80cd-a7d8-eb2f0e40e3e8 -->
To avoid the flakiness and slowness of loading assets from disk during tests, an extension on `UIImage` is created (`make(withColor:)`). This generates 1x1 pixel images in memory using `UIGraphicsImageRenderer`, ensuring strictly CPU-bound, synchronous image creation for assertions.
<!-- notion-id: 2f0e582f-073d-80ed-ada6-dc1bb4c1f15c -->
**Triangulation**
<!-- notion-id: 2f0e582f-073d-8089-a24b-f8712752ed17 -->
Testing follows a triangulation strategy to ensure robustness:
<!-- notion-id: 2f0e582f-073d-802d-a5f1-e6c446521824 -->
1. **Zero Case**: Assert rendering of an empty feed.
<!-- notion-id: 2f0e582f-073d-8009-8752-d6d66999d8e0 -->
1. **Single Case**: Assert rendering of a single item.
<!-- notion-id: 2f0e582f-073d-80bf-9a6c-c61b1f87c328 -->
1. **Many Case**: Assert rendering of multiple items with mixed configurations (e.g., some with descriptions, some without).
<!-- notion-id: 2f0e582f-073d-807b-88a1-c1b484b9d881 -->
This progression verifies that the `dataSource` implementation correctly handles count and index mapping.
<!-- notion-id: 2f0e582f-073d-80d2-bbf6-f4013f82fe71 -->
# Feed Feature Implementation Summary
<!-- notion-id: 2f0e582f-073d-8028-8862-ca46a7e99a06 -->
This implementation is driven by the ux Goals 
<!-- notion-id: 2f0e582f-073d-8084-a0e4-f5e1e205b6ed -->

<!-- notion-id: 2f0e582f-073d-80f5-960e-ceaf245cbcc9 -->
### Does not alter current feed rendering state on load error 
<!-- notion-id: 2f0e582f-073d-8010-a07d-fc6ec0c869bb -->

<!-- notion-id: 2f0e582f-073d-8011-bad1-c192f6fb5104 -->
The test `test_loadFeedCompletion_doesNotAlterCurrentRenderingStateOnError` ensures that if the user pulls to refresh and the request fails, the previously successful feed rendering is not wiped out.
<!-- notion-id: 2f0e582f-073d-8071-93a5-d9514cc6fb30 -->
```swift
func test_loadFeedCompletion_doesNotAlterCurrentRenderingStateOnError() {
    let image0 = makeImage()
    let (sut, loader) = makeSUT()

    sut.loadViewIfNeeded()
    loader.completeFeedLoading(with: [image0], at: 0)
    assertThat(sut, isRendering: [image0])

    sut.simulateUserInitiatedFeedReload()
    loader.completeFeedLoadingWithError(at: 1)
    assertThat(sut, isRendering: [image0])
}
```
<!-- notion-id: 2f0e582f-073d-8057-8cc6-f22f32fbbce8 -->
The` load()` is called when the view is appearing, the feed is assigned to the table model on success.
<!-- notion-id: 2f0e582f-073d-8027-9d7d-e5a542cd6915 -->
```swift
// FeedViewController.swift
// onViewIsAppearing calls load()
@objc private func load() {
    refreshControl?.beginRefreshing()
    loader?.load { [weak self] result in
        if let feed = try? result.get() { // Only update on success
            self?.tableModel = feed
            self?.tableView.reloadData()
        }
        self?.refreshControl?.endRefreshing() // Always stop refreshing
    }
}

```
<!-- notion-id: 2f0e582f-073d-808c-8271-ef2851f915dc -->
### Hide loading indicator on both load error and success
<!-- notion-id: 2f0e582f-073d-804a-bf74-c50c91604347 -->

<!-- notion-id: 2f0e582f-073d-8039-9140-eff244c4347e -->
The test `test_loadingFeedIndicator_isVisibleWhileLoadingFeed` validates that the loading indicator stops regardless of whether the load completes successfully or with an error.
<!-- notion-id: 2f0e582f-073d-800d-acda-f8b303429551 -->
```swift
func test_loadingFeedIndicator_isVisibleWhileLoadingFeed() {
    let (sut, loader) = makeSUT()

    sut.loadViewIfNeeded()
    XCTAssertTrue(sut.isShowingLoadingIndicator, "Expected loading indicator once view is loaded")

    loader.completeFeedLoading(at: 0)
    XCTAssertFalse(sut.isShowingLoadingIndicator, "Expected no loading indicator once loading completes successfully")

    sut.simulateUserInitiatedFeedReload()
    XCTAssertTrue(sut.isShowingLoadingIndicator, "Expected loading indicator once user initiates a reload")

    loader.completeFeedLoadingWithError(at: 1)
    XCTAssertFalse(sut.isShowingLoadingIndicator, "Expected no loading indicator once user initiated loading completes with error")
}

```
<!-- notion-id: 2f0e582f-073d-807a-967e-da1048f6f741 -->
```swift
// FeedViewController.swift
@objc private func load() {
    refreshControl?.beginRefreshing()
    loader?.load { [weak self] result in
        if let feed = try? result.get() {
            self?.tableModel = feed
            self?.tableView.reloadData()
        }
        self?.refreshControl?.endRefreshing() // Moved outside the success block
    }
}

```
<!-- notion-id: 2f0e582f-073d-8082-bb8f-c1de6e5e1106 -->
### Load image URL when image view is visible
<!-- notion-id: 2f0e582f-073d-8021-aaa6-df43a8788d2e -->

<!-- notion-id: 2f0e582f-073d-805e-bd74-cae6355c6c28 -->
The test `test_feedImageView_loadsImageURLWhenVisible` verifies that image URLs are loaded only when the corresponding view becomes visible on the screen.
<!-- notion-id: 2f0e582f-073d-8072-a2d2-cad3f691fd76 -->
```swift
func test_feedImageView_loadsImageURLWhenVisible() {
    let image0 = makeImage(url: URL(string: "<http://url-0.com>")!)
    let image1 = makeImage(url: URL(string: "<http://url-1.com>")!)
    let (sut, loader) = makeSUT()

    sut.loadViewIfNeeded()
    loader.completeFeedLoading(with: [image0, image1])

    XCTAssertEqual(loader.loadedImageURLs, [], "Expected no image URL requests until views become visible")

    sut.simulateFeedImageViewVisible(at: 0)
    XCTAssertEqual(loader.loadedImageURLs, [image0.url], "Expected first image URL request once first view becomes visible")

    sut.simulateFeedImageViewVisible(at: 1)
    XCTAssertEqual(loader.loadedImageURLs, [image0.url, image1.url], "Expected second image URL request once second view also becomes visible")
}

```
<!-- notion-id: 2f0e582f-073d-8059-b374-e08fb71a0cba -->
```swift
// FeedViewController.swift
public protocol FeedImageDataLoader {
    func loadImageData(from url: URL)
}

public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    // ...
    imageLoader?.loadImageData(from: cellModel.url)
    return cell
}

```
<!-- notion-id: 2f0e582f-073d-80a1-b444-e4e7ed3d861e -->
### Cancel image loading when image view is not visible anymore
<!-- notion-id: 2f0e582f-073d-8015-a830-f4df54c2089d -->

<!-- notion-id: 2f0e582f-073d-8031-acb8-efdaafe663d2 -->
The test `test_feedImageView_cancelsImageLoadingWhenNotVisibleAnymore` ensures that pending image requests are cancelled when their cells scroll off-screen to optimize performance.
<!-- notion-id: 2f0e582f-073d-805d-ab38-f38b90467be7 -->
```swift
func test_feedImageView_cancelsImageLoadingWhenNotVisibleAnymore() {
    let image0 = makeImage(url: URL(string: "<http://url-0.com>")!)
    let image1 = makeImage(url: URL(string: "<http://url-1.com>")!)
    let (sut, loader) = makeSUT()

    sut.loadViewIfNeeded()
    loader.completeFeedLoading(with: [image0, image1])
    XCTAssertEqual(loader.cancelledImageURLs, [], "Expected no cancelled image URL requests until image is not visible")

    sut.simulateFeedImageViewNotVisible(at: 0)
    XCTAssertEqual(loader.cancelledImageURLs, [image0.url], "Expected one cancelled image URL request once first image is not visible anymore")

    sut.simulateFeedImageViewNotVisible(at: 1)
    XCTAssertEqual(loader.cancelledImageURLs, [image0.url, image1.url], "Expected two cancelled image URL requests once second image is also not visible anymore")
}

```
<!-- notion-id: 2f0e582f-073d-8091-8a49-eb378ccd413b -->
```swift
// FeedViewController.swift
public override func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
    let cellModel = tableModel[indexPath.row]
    imageLoader?.cancelImageDataLoad(from: cellModel.url)
}

```
<!-- notion-id: 2f0e582f-073d-809f-81a0-d3f6bd0979ab -->
### Extract `cancelImageDataLoad(from: URL)` method from `FeedImageDataLoader` protocol
<!-- notion-id: 2f0e582f-073d-80ca-a6c7-f1ec6e5aa8fc -->

<!-- notion-id: 2f0e582f-073d-80b4-a77a-e7c5940e0be9 -->
This refactoring changes the `FeedImageDataLoader` protocol to return a `FeedImageDataLoaderTask` that handles cancellation. This delegates state management to the client (`FeedViewController`) rather than the loader. Existing tests ensure no regression in behavior.
<!-- notion-id: 2f0e582f-073d-8074-8b38-d8805233e356 -->
```swift
// FeedViewController.swift
public protocol FeedImageDataLoaderTask {
    func cancel()
}

public protocol FeedImageDataLoader {
    func loadImageData(from url: URL) -> FeedImageDataLoaderTask
}

// Usage in FeedViewController
private var tasks = [IndexPath: FeedImageDataLoaderTask]()

tasks[indexPath] = imageLoader?.loadImageData(from: cellModel.url) // ...
tasks[indexPath]?.cancel() // On didEndDisplaying

```
<!-- notion-id: 2f0e582f-073d-80a4-811c-cfb4dc7895d9 -->
### Feed image view loading indicator is visible while loading image
<!-- notion-id: 2f0e582f-073d-8058-ab81-d34bc00c46c7 -->

<!-- notion-id: 2f0e582f-073d-802c-95c7-ce33a3b4017e -->
The test `test_feedImageViewLoadingIndicator_isVisibleWhileLoadingImage` validates that a loading shimmer effect is displayed on the cell while the image is being fetched.
<!-- notion-id: 2f0e582f-073d-8053-a4ee-d0d03f8991ba -->
```swift
func test_feedImageViewLoadingIndicator_isVisibleWhileLoadingImage() {
    let (sut, loader) = makeSUT()

    sut.loadViewIfNeeded()
    loader.completeFeedLoading(with: [makeImage(), makeImage()])

    let view0 = sut.simulateFeedImageViewVisible(at: 0)
    let view1 = sut.simulateFeedImageViewVisible(at: 1)
    XCTAssertEqual(view0?.isShowingImageLoadingIndicator, true, "Expected loading indicator for first view while loading first image")
    XCTAssertEqual(view1?.isShowingImageLoadingIndicator, true, "Expected loading indicator for second view while loading second image")

    loader.completeImageLoading(at: 0)
    XCTAssertEqual(view0?.isShowingImageLoadingIndicator, false, "Expected no loading indicator for first view once first image loading completes successfully")
    XCTAssertEqual(view1?.isShowingImageLoadingIndicator, true, "Expected no loading indicator state change for second view once first image loading completes successfully")

    loader.completeImageLoadingWithError(at: 1)
    XCTAssertEqual(view0?.isShowingImageLoadingIndicator, false, "Expected no loading indicator state change for first view once second image loading completes with error")
    XCTAssertEqual(view1?.isShowingImageLoadingIndicator, false, "Expected no loading indicator for second view once second image loading completes with error")
}

```
<!-- notion-id: 2f0e582f-073d-8025-bfc8-e73821916f08 -->
```swift
// FeedViewController.swift
cell.feedImageContainer.startShimmering() // Start on load
tasks[indexPath] = imageLoader?.loadImageData(from: cellModel.url) { [weak cell] result in
    cell?.feedImageContainer.stopShimmering() // Stop on completion
}

```
<!-- notion-id: 2f0e582f-073d-801b-bc14-ece36d76f735 -->
### Render loaded images from URL
<!-- notion-id: 2f0e582f-073d-80fe-a8e1-d8cb16d36cf9 -->

<!-- notion-id: 2f0e582f-073d-80e7-9a65-de5e3b6679f3 -->
The test `test_feedImageView_rendersImageLoadedFromURL` ensures that when image data is successfully loaded and converted to an image, it is rendered in the cell.
<!-- notion-id: 2f0e582f-073d-8045-9456-f4ca3df3d3c0 -->
```swift
func test_feedImageView_rendersImageLoadedFromURL() {
    let (sut, loader) = makeSUT()

    sut.loadViewIfNeeded()
    loader.completeFeedLoading(with: [makeImage(), makeImage()])

    let view0 = sut.simulateFeedImageViewVisible(at: 0)
    let view1 = sut.simulateFeedImageViewVisible(at: 1)
    XCTAssertEqual(view0?.renderedImage, .none, "Expected no image for first view while loading first image")
    XCTAssertEqual(view1?.renderedImage, .none, "Expected no image for second view while loading second image")

    let imageData0 = UIImage.make(withColor: .red).pngData()!
    loader.completeImageLoading(with: imageData0, at: 0)
    XCTAssertEqual(view0?.renderedImage, imageData0, "Expected image for first view once first image loading completes successfully")
    XCTAssertEqual(view1?.renderedImage, .none, "Expected no image state change for second view once first image loading completes successfully")

    let imageData1 = UIImage.make(withColor: .blue).pngData()!
    loader.completeImageLoading(with: imageData1, at: 1)
    XCTAssertEqual(view0?.renderedImage, imageData0, "Expected no image state change for first view once second image loading completes successfully")
    XCTAssertEqual(view1?.renderedImage, imageData1, "Expected image for second view once second image loading completes successfully")
}

```
<!-- notion-id: 2f0e582f-073d-8016-849d-e8b65c41a828 -->
```swift
// FeedViewController.swift
tasks[indexPath] = imageLoader?.loadImageData(from: cellModel.url) { [weak cell] result in
    let data = try? result.get()
    cell?.feedImageView.image = data.map(UIImage.init) ?? nil // Render image
    cell?.feedImageContainer.stopShimmering()
}

```
<!-- notion-id: 2f0e582f-073d-802d-9d80-c5ae802a5481 -->
### Feed image view retry button is visible on image url load error
<!-- notion-id: 2f0e582f-073d-8006-8b8f-ffe7857f9d5c -->

<!-- notion-id: 2f0e582f-073d-80ed-832b-d7f53c9e7449 -->
The test `test_feedImageViewRetryButton_isVisibleOnImageURLLoadError` ensures that a retry button is displayed to the user if the image request fails.
<!-- notion-id: 2f0e582f-073d-80c0-b5b0-e56d08a184c8 -->
```swift
func test_feedImageViewRetryButton_isVisibleOnImageURLLoadError() {
    let (sut, loader) = makeSUT()

    sut.loadViewIfNeeded()
    loader.completeFeedLoading(with: [makeImage(), makeImage()])

    let view0 = sut.simulateFeedImageViewVisible(at: 0)
    let view1 = sut.simulateFeedImageViewVisible(at: 1)
    XCTAssertEqual(view0?.isShowingRetryAction, false, "Expected no retry action for first view while loading first image")
    XCTAssertEqual(view1?.isShowingRetryAction, false, "Expected no retry action for second view while loading second image")

    let imageData = UIImage.make(withColor: .red).pngData()!
    loader.completeImageLoading(with: imageData, at: 0)
    XCTAssertEqual(view0?.isShowingRetryAction, false, "Expected no retry action for first view once first image loading completes successfully")
    XCTAssertEqual(view1?.isShowingRetryAction, false, "Expected no retry action state change for second view once first image loading completes successfully")

    loader.completeImageLoadingWithError(at: 1)
    XCTAssertEqual(view0?.isShowingRetryAction, false, "Expected no retry action state change for first view once second image loading completes with error")
    XCTAssertEqual(view1?.isShowingRetryAction, true, "Expected retry action for second view once second image loading completes with error")
}

```
<!-- notion-id: 2f0e582f-073d-806a-83e3-f84a9dfd5650 -->
```swift
// FeedViewController.swift
cell.feedImageRetryButton.isHidden = true // Reset state
tasks[indexPath] = imageLoader?.loadImageData(from: cellModel.url) { [weak cell] result in
    let data = try? result.get()
    // ... rendering valid image ...
    cell?.feedImageRetryButton.isHidden = (data != nil) // Show if data is nil (failure)
}

```
<!-- notion-id: 2f0e582f-073d-8081-a8ae-f4e76412f800 -->
### Feed image view retry button is visible on invalid loaded image data
<!-- notion-id: 2f0e582f-073d-807c-a827-de098c7ac631 -->

<!-- notion-id: 2f0e582f-073d-802e-9f15-dea2668f7742 -->
The test `test_feedImageViewRetryButton_isVisibleOnInvalidImageData` extends the error handling to cases where data is received but is corrupted or invalid, ensuring the retry option is still available.
