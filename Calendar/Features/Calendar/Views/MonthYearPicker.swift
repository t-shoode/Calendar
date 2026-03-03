import SwiftUI

struct MonthYearPicker: View {
  @Binding var currentMonth: Date
  @Binding var isPresented: Bool

  @State private var displayMode: DisplayMode = .month
  @State private var tempYear: Int
  @State private var tempMonth: Int

  private let months = Calendar.current.monthSymbols
  private let years = Array(2000...2100)  // Configurable range
  private let calendar = Calendar.current

  enum DisplayMode {
    case month
    case year
  }

  init(currentMonth: Binding<Date>, isPresented: Binding<Bool>) {
    _currentMonth = currentMonth
    _isPresented = isPresented

    // Initialize temp state from current date
    let date = currentMonth.wrappedValue
    let year = Calendar.current.component(.year, from: date)
    let month = Calendar.current.component(.month, from: date) - 1  // 0-indexed for array

    _tempYear = State(initialValue: year)
    _tempMonth = State(initialValue: month)
  }

  var body: some View {
    VStack(spacing: 20) {
      // Header: Year Selector
      Button(action: {
        withAnimation {
          displayMode = displayMode == .year ? .month : .year
        }
      }) {
        HStack {
          Text("\(String(tempYear))")
            .font(Typography.largeTitle)
            .foregroundColor(Color.textPrimary)

          Image(systemName: "chevron.right")
            .rotationEffect(displayMode == .year ? .degrees(90) : .degrees(0))
            .foregroundColor(Color.textTertiary)
        }
      }
      .buttonStyle(.plain)

      // Content
      if displayMode == .month {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 20) {
          ForEach(0..<months.count, id: \.self) { index in
            Button(action: {
              tempMonth = index
              selectDate()
            }) {
              Text(months[index])
                .font(Typography.body)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                  RoundedRectangle(cornerRadius: Spacing.smallRadius)
                    .fill(tempMonth == index ? Color.appAccent : Color.clear)
                )
                .foregroundColor(tempMonth == index ? .white : Color.textPrimary)
            }
          }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
      } else {
        ScrollViewReader { proxy in
          ScrollView {
            LazyVStack {
              ForEach(years, id: \.self) { year in
                Button(action: {
                  tempYear = year
                  withAnimation {
                    displayMode = .month
                  }
                }) {
                  Text(String(year))
                    .font(.system(size: 24, weight: year == tempYear ? .bold : .regular))
                    .foregroundColor(year == tempYear ? .appAccent : Color.textPrimary)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                }
                .id(year)
              }
            }
            .padding(.vertical)
          }
          .frame(height: 250)
          .onAppear {
            proxy.scrollTo(tempYear, anchor: .center)
          }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
      }
    }
    .padding(Spacing.lg)
    .background(Color.surfaceElevated)
    .clipShape(RoundedRectangle(cornerRadius: Spacing.sheetRadius))
    .overlay(
      RoundedRectangle(cornerRadius: Spacing.sheetRadius)
        .stroke(Color.border, lineWidth: 0.5)
    )
    .padding(.horizontal, 40)
    .shadow(color: Color.shadowColor, radius: 20, x: 0, y: 10)
  }

  private func selectDate() {
    var components = DateComponents()
    components.year = tempYear
    components.month = tempMonth + 1  // 1-indexed
    components.day = 1

    if let newDate = calendar.date(from: components) {
      currentMonth = newDate
      withAnimation {
        isPresented = false
      }
    }
  }
}
