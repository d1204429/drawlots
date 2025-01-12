import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Models
struct RestaurantOpeningHours: Codable {
    let id: Int
    let restaurantId: Int
    let dayOfWeek: String
    let openInfo: String
}

struct Restaurant: Identifiable, Codable {
    let id: Int
    let mapsUrl: String
    let rating: Int
    let name: String
    let address: String
    let phone: String
    let createdAt: String
    let openingHours: [RestaurantOpeningHours]
}

struct HistoryRecord: Codable, Identifiable {
    let id: UUID
    let restaurant: Restaurant
    let selectedAt: Date
}

// MARK: - Service
@Observable class RestaurantService : ObservableObject{
    private let baseURL = "http://192.168.43.90:1988/api/restaurants"
    private let fileURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("restaurants.json")
    }()
    private let historyFileURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("history.json")
    }()
    
    var restaurants: [Restaurant] = []
    var history: [HistoryRecord] = []
    var error: Error?
    
    init() {
        loadRestaurants()
        loadHistory()
    }
    
    private func saveRestaurants() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(restaurants)
            try data.write(to: fileURL, options: .atomicWrite)
            print("成功儲存至: \(fileURL)")
        } catch {
            print("儲存錯誤: \(error)")
            self.error = error
        }
    }
    
    private func loadRestaurants() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let data = try Data(contentsOf: fileURL)
                restaurants = try JSONDecoder().decode([Restaurant].self, from: data)
            }
        } catch {
            print("載入錯誤: \(error)")
            restaurants = []
        }
    }
    
    func deleteHistory(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }
    
    private func saveHistory() {
       
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(history)
            try data.write(to: historyFileURL, options: .atomicWrite)
            print("歷史紀錄儲存至: \(historyFileURL)")
        } catch {
            print("歷史紀錄儲存錯誤: \(error)")
            self.error = error
        }
    }
    
    private func loadHistory() {
        do {
            if FileManager.default.fileExists(atPath: historyFileURL.path) {
                let data = try Data(contentsOf: historyFileURL)
                history = try JSONDecoder().decode([HistoryRecord].self, from: data)
            }
        } catch {
            print("歷史紀錄載入錯誤: \(error)")
            history = []
        }
    }

    func fetchRestaurants() async {
        loadRestaurants()
        
        do {
            guard let url = URL(string: baseURL) else { return }
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
            
            self.restaurants = try JSONDecoder().decode([Restaurant].self, from: data)
            saveRestaurants()
        } catch {
            self.error = error
            print("Fetch error: \(error)")
        }
    }
    
    func addRestaurant(mapsUrl: String, rating: Int) async throws {
        guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
        
        let body: [String: Any] = [
            "mapsUrl": mapsUrl,
            "rating": rating
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        await fetchRestaurants()
    }
    
    func randomSelect() -> Restaurant? {
        let random = Int.random(in: 1...100)
        let targetRating: Int
        
        if random <= 85 {
            targetRating = 1
        } else if random <= 95 {
            targetRating = 2
        } else {
            targetRating = 3
        }
        
        let filtered = restaurants.filter { $0.rating == targetRating }
        let selected = filtered.randomElement() ?? restaurants.randomElement()
        
        if let selected = selected {
            let record = HistoryRecord(
                id: UUID(),
                restaurant: selected,
                selectedAt: Date()
            )
            history.append(record)
            saveHistory()
        }
        
        return selected
    }
       
}
// MARK: - View Model
@Observable class RestaurantViewModel {
    let service = RestaurantService()
    var mapUrl: String = ""
    var selectedStars: Int?
    var showingHistory = false
    var showingAllRestaurants = false
    var showingRandomResult = false
    var selectedRestaurant: Restaurant?
    
    var restaurants: [Restaurant] {
        service.restaurants
    }
    
    func addRestaurant() {
        guard !mapUrl.isEmpty, let stars = selectedStars else { return }
        Task {
            do {
                try await service.addRestaurant(mapsUrl: mapUrl, rating: stars)
                mapUrl = ""
                selectedStars = nil
            } catch {
                print("Error adding restaurant: \(error)")
            }
        }
    }
    
    func loadData() {
        Task {
            await service.fetchRestaurants()
        }
    }
    
    func randomSelect() {
        selectedRestaurant = service.randomSelect()
        showingRandomResult = true
    }
}



struct StarRating: View {
    let count: Int
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill")
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(.yellow)
            }
        }
    }
}

struct StarButton: View {
    let count: Int
    @Binding var selectedStars: Int?
    
    var body: some View {
        Button {
            selectedStars = count
        } label: {
            HStack(spacing: 2) {
                ForEach(0..<count, id: \.self) { _ in
                    Image(systemName: "star.fill")
                        .symbolRenderingMode(.multicolor)
                        .foregroundStyle(.yellow)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(selectedStars == count ? Color.yellow.opacity(0.3) : .clear)
            .clipShape(Capsule())
        }
    }
}

struct RandomResultView: View {
    let restaurant: Restaurant
    let selectedAt: Date
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            RestaurantDetailView(restaurant: restaurant)
                .navigationTitle("抽選結果")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") {
                            dismiss()
                        }
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .bottomBar) {
                        Text("抽選時間：\(selectedAt.formatted())")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
        }
        .background(Color(hex: "FFFDD0"))
    }
}

struct HistoryView: View {
    @EnvironmentObject private var service: RestaurantService
    @State private var expandedId: UUID?
    
    var body: some View {
        List {
            ForEach(service.history.sorted(by: { $0.selectedAt > $1.selectedAt })) { record in
                Button(action: {
                    withAnimation {
                        expandedId = expandedId == record.id ? nil : record.id
                    }
                }) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(record.selectedAt.formatted())
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(record.restaurant.name)
                                .font(.headline)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(expandedId == record.id ? 90 : 0))
                    }
                }
                .foregroundColor(.primary)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        service.deleteHistory(id: record.id)
                    } label: {
                        Text("刪除")
                    }
                }
                
                if expandedId == record.id {
                    RestaurantDetailView(restaurant: record.restaurant)
                }
            }
        }
        .navigationTitle("抽籤紀錄")
        .listStyle(.inset)
        .scrollContentBackground(.hidden)  // 重要：隱藏 List 預設背景
        .background(Color(hex: "FFFDD0"))
    }
}
struct RestaurantListView: View {
    let restaurants: [Restaurant]
    @State private var expandedId: Int?
    
    var body: some View {
        List(restaurants) { restaurant in
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    withAnimation {
                        expandedId = expandedId == restaurant.id ? nil : restaurant.id
                    }
                }) {
                    HStack {
                        Text(restaurant.name)
                            .font(.headline)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .rotationEffect(.degrees(expandedId == restaurant.id ? 90 : 0))
                    }
                }
                
                if expandedId == restaurant.id {
                    RestaurantDetailView(restaurant: restaurant)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("所有店家")
        .listStyle(.inset)
        .scrollContentBackground(.hidden)  // 重要：隱藏 List 預設背景
        .background(Color(hex: "FFFDD0"))
    }
}



struct RestaurantDetailView: View {
    let restaurant: Restaurant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(restaurant.name)
                           .font(.title3.bold())
            Text(restaurant.address)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            HStack {
                Image(systemName: "phone")
                    .foregroundColor(.blue)
                Text(restaurant.phone)
                    .font(.subheadline)
            }
            
            StarRating(count: restaurant.rating)
            
            Text("營業時間：")
                .font(.subheadline)
            ForEach(restaurant.openingHours, id: \.id) { hour in
                Text("\(hour.dayOfWeek): \(hour.openInfo)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.leading)
    }
}

struct ContentView: View {
    @State private var viewModel = RestaurantViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("呷奔抽籤")
                    .font(.largeTitle.bold())
                
                HStack {
                    TextField("店家googlemaps連結", text: $viewModel.mapUrl)
                        .textFieldStyle(.roundedBorder)
                    
                    Button {
                        viewModel.addRestaurant()
                    } label: {
                        Image(systemName: "plus.app.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.blue)
                            .font(.title2)
                    }
                }
                .padding(.horizontal)
                
                HStack(spacing: 16) {
                    ForEach(1...3, id: \.self) { count in
                        StarButton(count: count, selectedStars: $viewModel.selectedStars)
                    }
                }
                
                VStack(spacing: 4) {
                    Text("新增時需選星數建立店家被抽選之機率")
                        .font(.footnote)
                    Text("1星80% 2星15% 3星5%")
                        .font(.footnote)
                }
                
                Button {
                    viewModel.randomSelect()
                } label: {
                    Image("finger")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                }
                .sheet(isPresented: $viewModel.showingRandomResult) {
                    if let restaurant = viewModel.selectedRestaurant {
                        RandomResultView(
                            restaurant: restaurant,
                            selectedAt: Date()
                        )
                    }
                }
                
                Text("點擊上方圖片抽選")
                    .font(.subheadline)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button {
                        viewModel.showingHistory = true
                    } label: {
                        Text("抽籤紀錄")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.orange)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    
                    Button {
                        viewModel.showingAllRestaurants = true
                    } label: {
                        Text("所有店家")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.green)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "FFFDD0"))
            .navigationDestination(isPresented: $viewModel.showingHistory) {
                HistoryView()
                    .environmentObject(viewModel.service)
            }
            .navigationDestination(isPresented: $viewModel.showingAllRestaurants) {
                RestaurantListView(restaurants: viewModel.restaurants)
            }
            .task {
                viewModel.loadData()
            }
        }
    }
}
#Preview {
    ContentView()
}
