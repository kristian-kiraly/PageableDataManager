# PageableDataManager

A simple way to implement paging using SwiftUI and ObservableObjects to take the tedium out of setting up pageable views. Just subclass the PageableDataManager and implement the fetchItemsFromAPI to return a list of pageable items and an optional `totalItems`. Giving a value for `totalItems` tells the manager when it's reached the end of the items before it gets an empty list. You can also use the provided SwiftUI view PageableLazyScrollView to render the items in a LazyVStack with automatic page loading or implement your own rendering and loading methods.

Usage:

```swift
struct Pokemon: Codable, Identifiable {
    var id: String {
        name
    }
    let name: String
    let url: String
}

class PageablePokemonListManager: PageableDataManager<Pokemon> {
    let pageSize: Int = 30
    
    override func fetchItemsFromAPI() async throws -> ([Pokemon], Int?) {
        var request = URLRequest(url: .init(string: "https://pokeapi.co/api/v2/pokemon?limit=\(pageSize)&offset=\(pageSize * currentPage)")!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
        request.httpMethod = "GET"
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let json = jsonObject as? [AnyHashable : Any],
              let pokemonJSON = json["results"] as? [[AnyHashable : Any]]
        else { return ([], nil) }
        
        let pokemonJSONData = try JSONSerialization.data(withJSONObject: pokemonJSON)
        let pokemon = try JSONDecoder().decode([Pokemon].self, from: pokemonJSONData)
        let numPokemon = json["count"] as? Int
        
        return (pokemon, numPokemon)
    }
}

struct ContentView: View {
    @ObservedObject var manager = PageablePokemonListManager()
    
    var body: some View {
        VStack {
            HStack {
                Text("Page: \(manager.currentPage)")
                Text("Loaded: \(manager.items.count)")
                Text("Total: \(manager.totalItems)")
            }
            PageableLazyScrollView(manager: manager) {
                ForEach(manager.items) { pokemon in
                    Text(pokemon.name)
                }
            }
        }
        .refreshable {
            do {
                try await manager.reloadItems()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
}
```

