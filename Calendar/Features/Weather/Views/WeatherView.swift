import SwiftUI

public struct WeatherView: View {
    @StateObject public var viewModel = WeatherViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // We rely on the mesh background from ContentView
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    HStack {
                        Text(viewModel.weatherData?.city ?? Localization.string(.weather))
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.textPrimary)
                        Spacer()
                    }
                    .padding(.horizontal)

                    // City Search / Header
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.textTertiary)
                            TextField(Localization.string(.searchCity), text: $searchText)
                                .textFieldStyle(.plain)
                                .onChange(of: searchText) { old, newValue in
                                    Task { await viewModel.search(query: newValue) }
                                }
                        }
                        .padding(12)
                        .softControl(cornerRadius: 12, padding: 0)
                        
                        if !viewModel.searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(viewModel.searchResults, id: \.latitude) { result in
                                    Button {
                                        Task {
                                            await viewModel.selectCity(result)
                                            searchText = ""
                                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text(result.name)
                                                    .font(Typography.headline)
                                                Text("\(result.admin1 ?? ""), \(result.country)")
                                                    .font(Typography.caption)
                                                    .foregroundColor(.textTertiary)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundColor(.textTertiary)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 12)
                                    }
                                    .buttonStyle(.plain)
                                    Divider()
                                }
                            }
                            .softCard(cornerRadius: 16, padding: 0, shadow: false)
                        }
                    }
                    .padding(.horizontal)
                    
                    if let weather = viewModel.weatherData {
                        // Current Weather Card (More dramatic)
                        currentWeatherHero(weather)
                        
                        // Hourly Forecast
                        VStack {
                            hourlyForecastSection(weather)
                        }
                        .softCard(cornerRadius: 18, padding: 16, shadow: false)
                        .padding(.horizontal)
                        
                        // Weekly Forecast
                        VStack {
                            weeklyForecastSection(weather)
                        }
                        .softCard(cornerRadius: 18, padding: 16, shadow: false)
                        .padding(.horizontal)
                    } else if viewModel.isLoading {
                        ProgressView()
                            .padding(.top, 40)
                    } else {
                        VStack(spacing: 20) {
                            Image(systemName: "cloud.sun.fill")
                                .font(.system(size: 80))
                                .symbolRenderingMode(.multicolor)
                                .shadow(radius: 10)
                            
                            Text(Localization.string(.weatherSearchPrompt))
                                .font(Typography.subheadline)
                                .foregroundColor(.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                        .padding(.top, 60)
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 100) // Space for floating tab bar
            }
            .scrollDismissesKeyboard(.immediately)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Components
    
    @ViewBuilder
    private func currentWeatherHero(_ weather: WeatherData) -> some View {
        if let current = weather.current {
            VStack(spacing: 12) {
                Text(Date().formatted(.dateTime.weekday(.wide).locale(Localization.locale)).capitalized)
                    .font(Typography.headline)
                    .foregroundColor(.textTertiary)
                    .textCase(.uppercase)
                
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.accentColor.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom))
                        .frame(width: 200, height: 200)
                        .blur(radius: 40)
                    
                    Image(systemName: current.code.icon(isDay: current.isDay))
                        .font(.system(size: 100))
                        .symbolRenderingMode(.multicolor)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 10)
                }
                
                Text("\(Int(current.temperature))°")
                    .font(.system(size: 84, weight: .thin, design: .rounded))
                    .foregroundColor(.textPrimary)
                
                Text(current.code.description)
                    .font(Typography.title)
                    .fontWeight(.bold)
                    .foregroundColor(.textPrimary)
                
                if let today = weather.dailyForecast.first {
                    HStack(spacing: 20) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                            Text("\(Int(today.minTemp))°")
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up")
                            Text("\(Int(today.maxTemp))°")
                        }
                    }
                    .font(Typography.headline)
                    .foregroundColor(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
            .softCard(cornerRadius: 22, padding: 22, shadow: false)
            .padding(.horizontal)
        }
    }
    
    @ViewBuilder
    private func hourlyForecastSection(_ weather: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Localization.string(.hourlyForecast).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textTertiary)
            
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        let today = Calendar.current.startOfDay(for: Date())
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
                        
                        let dayForecast = weather.hourlyForecast.filter { 
                            $0.time >= today && $0.time < tomorrow 
                        }
                        
                        ForEach(dayForecast) { point in
                            VStack(spacing: 10) {
                                Text(point.time.formatted(date: .omitted, time: .shortened))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.textSecondary)
                                
                                Image(systemName: smoothedIcon(for: point, in: dayForecast))
                                    .font(.system(size: 24))
                                    .symbolRenderingMode(.multicolor)
                                
                                Text("\(Int(point.temperature))°")
                                    .font(Typography.body)
                                    .fontWeight(.bold)
                            }
                            .frame(width: 60)
                            .id(Calendar.current.component(.hour, from: point.time))
                        }
                    }
                }
                .onAppear {
                    scrollToCurrentHour(proxy: proxy)
                }
                .onChange(of: weather.city) { old, _ in
                    scrollToCurrentHour(proxy: proxy)
                }
            }
        }
    }
    
    private func smoothedIcon(for point: HourlyPoint, in forecast: [HourlyPoint]) -> String {
        guard let index = forecast.firstIndex(where: { $0.id == point.id }) else {
            return point.code.icon(isDay: point.isDay)
        }
        
        let currentCode = point.code.rawValue
        
        if currentCode <= 1 && index > 0 && index < forecast.count - 1 {
            let prevCode = forecast[index - 1].code.rawValue
            let nextCode = forecast[index + 1].code.rawValue
            
            if prevCode >= 2 && nextCode >= 2 {
                return WeatherCode.partlyCloudy.icon(isDay: point.isDay)
            }
        }
        
        return point.code.icon(isDay: point.isDay)
    }
    
    private func scrollToCurrentHour(proxy: ScrollViewProxy) {
        let currentHour = Calendar.current.component(.hour, from: Date())
        withAnimation {
            proxy.scrollTo(currentHour, anchor: .center)
        }
    }
    
    @ViewBuilder
    private func weeklyForecastSection(_ weather: WeatherData) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(Localization.string(.dailyForecast).uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.textTertiary)
            
            VStack(spacing: 0) {
                let futureDays = weather.dailyForecast.dropFirst().prefix(7)
                ForEach(futureDays) { day in
                    HStack {
                        Text(day.time.formatted(Date.FormatStyle(locale: Localization.locale).weekday(.wide)).capitalized)
                            .font(Typography.body)
                            .fontWeight(.medium)
                            .frame(width: 100, alignment: .leading)
                        
                        Spacer()
                        
                        Image(systemName: day.code.icon(isDay: true))
                            .font(.system(size: 24))
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 40)
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Text("\(Int(day.minTemp))°")
                                .font(Typography.body)
                                .foregroundColor(.textTertiary)
                                .frame(width: 35, alignment: .trailing)
                            Text("\(Int(day.maxTemp))°")
                                .font(Typography.body)
                                .fontWeight(.bold)
                                .frame(width: 35, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 14)
                    
                    if day.id != futureDays.last?.id {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
    }
}
