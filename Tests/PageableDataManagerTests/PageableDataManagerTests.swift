import XCTest
@testable import PageableDataManager

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
        var request = URLRequest(url: .init(string: "https://pokeapi.co/api/v2/pokemon?limit=\(pageSize)&offset=\(pageSize * nextPage)")!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: 10.0)
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

final class PageableDataManagerTests: XCTestCase {
    let manager = PageablePokemonListManager()
    
    func testPageLoad() async throws {
        try await manager.reloadItems()
        assert(manager.items.count == manager.pageSize * manager.nextPage)
        assert(manager.nextPage == 1)
        try await manager.getNextPage()
        assert(manager.items.count == manager.pageSize * manager.nextPage)
        assert(manager.nextPage == 2)
        try await manager.reloadItems()
        assert(manager.items.count == manager.pageSize * manager.nextPage)
        assert(manager.nextPage == 1)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        assert(manager.loading == false)
    }
}
