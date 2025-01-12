import SwiftUI

@Observable class RestaurantService {
    var restaurants: [Restaurant] = []
    var error: Error?
    var isLoading = false
    
    private let baseURL = "http://192.168.8.150:1988/api/restaurants"
    
    func fetchRestaurants() async {
        isLoading = true
        do {
            guard let url = URL(string: baseURL) else { return }
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Invalid HTTP response")
                return
            }
            
            self.restaurants = try JSONDecoder().decode([Restaurant].self, from: data)
        } catch {
            self.error = error
            print("Fetch error: \(error)")
        }
        isLoading = false
    }
    
    func addRestaurant(mapsUrl: String, rating: Int) async throws {
        isLoading = true
        defer { isLoading = false }
        
        guard let url = URL(string: baseURL) else {
            print("Invalid URL")
            throw URLError(.badURL)
        }
        
        let body: [String: Any] = [
            "mapsUrl": mapsUrl,
            "rating": rating
        ]
        
        print("發送請求到: \(url)")
        print("請求內容: \(body)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("回應數據: \(responseString)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("無效的回應類型")
                throw URLError(.badServerResponse)
            }
            
            print("回應狀態碼: \(httpResponse.statusCode)")
            
            guard (200...299).contains(httpResponse.statusCode) else {
                print("錯誤的回應碼: \(httpResponse.statusCode)")
                throw URLError(.badServerResponse)
            }
            
            await fetchRestaurants()
        } catch {
            print("網路錯誤: \(error)")
            throw error
        }
    }
}
