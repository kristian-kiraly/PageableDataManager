// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
@available(iOS 14.0, *)
class PageableDataManager<T: Identifiable>: ObservableObject {
    //Tracks if the pageable data is currently being fetched
    @Published private(set) var loading = false
    //Is true if the most recent page of data either matches the size of the total items given from the response or was empty
    @Published private(set) var hasReachedEndOfItems = false
    
    //The storage of all the pageable items
    @Published var items: [T] = []
    //The total items which should be set by the fetchItemsFromAPI function call in a subclass
    @Published private(set) var totalItems: Int = 0
    //The page that will be loaded next
    @Published private(set) var currentPage = 0
    
    /**
     Resets the data to its initial state and loads the first page again.
     */
    func reloadItems() async throws {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                self.currentPage = 0
                self.items = []
                self.totalItems = 0
                self.hasReachedEndOfItems = false
                continuation.resume()
            }
        }
        try await getNextPage()
    }
    
    /**
     Loads the next page of pageable data and sets the internal values appropriately based on the results. Will advance the page upon successful page load.
     */
    final func getNextPage() async throws {
        //If we have reached the end of the data, don't load anything else
        guard !hasReachedEndOfItems else { return }
        
        //Set the loading state until the end of the async task
        DispatchQueue.main.async {
            self.loading = true
        }
        defer {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.loading = false
            }
        }
        //Get the new items and the optional total count from the API call
        let (newItems, totalItems) = try await fetchItemsFromAPI()
        //If a total count is available and has not already been set, set our stored total count. Checking if it's already been set avoids publishing changes unnecessarily
        if let totalItems, totalItems != self.totalItems {
            DispatchQueue.main.async {
                self.totalItems = totalItems
            }
        }
        //Perform changes to published variables on the main thread
        DispatchQueue.main.async {
            //Advance the current page
            self.currentPage += 1
            //Add the new items to the list
            self.items += newItems
            //If we have reached the set total items or we have successfully retrieved an empty list, stop loading future pages
            if self.items.count == totalItems || newItems.isEmpty {
                self.hasReachedEndOfItems = true
                //Set the total count if it hasn't already been set
                if self.totalItems != self.items.count {
                    self.totalItems = self.items.count
                }
            }
        }
    }
    
    /**
     Returns the data for the current page. This should be implemented by any subclass to provide the data.
     */
    func fetchItemsFromAPI() async throws -> ([T], Int?) {
        fatalError("Must implement getMoreItems in subclass")
    }
}

@available(iOS 14.0, *)
struct PageableLazyScrollView<T: Identifiable, Content: View>: View {
    //Observe changes to some generic pageable manager
    @ObservedObject var manager: PageableDataManager<T>
    //Match the LazyVStack initializer parameters
    var alignment: HorizontalAlignment = .center
    var spacing: CGFloat? = nil
    var pinnedViews: PinnedScrollableViews = []
    @ViewBuilder let content: () -> Content
    
    //Store a property that will make sure our loading view triggers the loading action even if it never left the screen by hiding it briefly when loading completes
    @State private var shouldShowProgressView = true
    
    var body: some View {
        //Avoiding deprecated onChange with only one parameter
        if #available(iOS 17, *) {
            scrollContent
                .onChange(of: manager.loading) { oldValue, newValue in
                    //If we have stopped loading, briefly hide and show the loading indicator to trigger loading if it is still on screen
                    if !newValue {
                        toggleShowProgress()
                    }
                }
        } else {
            scrollContent
                .onChange(of: manager.loading) { isLoading in
                    //If we have stopped loading, briefly hide and show the loading indicator to trigger loading if it is still on screen
                    if !isLoading {
                        toggleShowProgress()
                    }
                }
        }
    }
    
    /**
     Lazy loads the content of the pageable data as well as a loading indicator below that will load more items when it appears. The loading indicator will be hidden if we have reached the end of the pageable data or if we're briefly hiding it manually to trigger another load
     */
    private var scrollContent: some View {
        ScrollView {
            LazyVStack(alignment: alignment, spacing: spacing, pinnedViews: pinnedViews) {
                content()
                if shouldShowProgressView && !manager.hasReachedEndOfItems {
                    loadingIndicator
                }
            }
        }
    }
    
    /**
     Briefly hides and then shows the loading indicator to allow it to load more data even if it was always visible (since the load is triggered when the view appears).
     */
    private func toggleShowProgress() {
        shouldShowProgressView = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            shouldShowProgressView = true
        }
    }
    
    /**
     The loading indicator that loads more data when it appears.
     */
    private var loadingIndicator: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .onAppear() {
                guard !manager.loading && !manager.hasReachedEndOfItems else { return }
                fetchMoreItems()
            }
    }
    
    /**
     An abstracted way to tell the paging manager to fetch the next items with some error handling.
     */
    private func fetchMoreItems() {
        Task {
            do {
                try await manager.getNextPage()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
}
