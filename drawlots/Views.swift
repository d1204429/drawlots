import SwiftUI

struct StarButton: View {
    let count: Int
    @Binding var selectedStars: Int?
    
    var body: some View {
        Button {
            selectedStars = count
            print("Selected stars: \(count)")
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

struct RestaurantListView: View {
    let restaurants: [Restaurant]
    
    var body: some View {
        List(restaurants) { restaurant in
            HStack {
                Text(restaurant.mapsUrl)
                Spacer()
                StarRating(count: restaurant.rating)
            }
        }
        .navigationTitle("所有店家")
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

struct HistoryView: View {
    var body: some View {
        List {
            Text("歷史記錄待實現")
        }
        .navigationTitle("抽籤紀錄")
    }
}
