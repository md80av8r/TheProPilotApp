//
//  CurrencyRate.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 10/27/25.
//


// CurrencyTrackerView.swift - Currency Conversion with Live Rates for ProPilot
import SwiftUI

// MARK: - Currency Model
struct CurrencyRate: Codable {
    let rates: [String: Double]
    let base: String
    let date: String
}

// MARK: - Exchange Rate Manager
class ExchangeRateManager: ObservableObject {
    @Published var rates: [String: Double] = [:]
    @Published var baseCurrency: String = "USD"
    @Published var lastUpdated: Date?
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // Popular currencies for pilots
    let popularCurrencies = [
        "USD", "EUR", "GBP", "CAD", "AUD", "JPY", "CNY", "MXN", "BRL", "INR",
        "CHF", "HKD", "SGD", "NZD", "SEK", "NOK", "DKK", "KRW", "THB", "MYR"
    ]
    
    let currencyNames: [String: String] = [
        "USD": "US Dollar",
        "EUR": "Euro",
        "GBP": "British Pound",
        "CAD": "Canadian Dollar",
        "AUD": "Australian Dollar",
        "JPY": "Japanese Yen",
        "CNY": "Chinese Yuan",
        "MXN": "Mexican Peso",
        "BRL": "Brazilian Real",
        "INR": "Indian Rupee",
        "CHF": "Swiss Franc",
        "HKD": "Hong Kong Dollar",
        "SGD": "Singapore Dollar",
        "NZD": "New Zealand Dollar",
        "SEK": "Swedish Krona",
        "NOK": "Norwegian Krone",
        "DKK": "Danish Krone",
        "KRW": "South Korean Won",
        "THB": "Thai Baht",
        "MYR": "Malaysian Ringgit"
    ]
    
    func fetchRates() {
        isLoading = true
        error = nil
        
        // Using exchangerate-api.com (free tier: 1500 requests/month)
        // Alternative: Use frankfurter.app (free, no API key needed)
        let urlString = "https://api.frankfurter.app/latest?from=\(baseCurrency)"
        
        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isLoading = false
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, taskError in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let taskError = taskError {
                    self?.error = "Network error: \(taskError.localizedDescription)"
                    return
                }
                
                guard let data = data else {
                    self?.error = "No data received"
                    return
                }
                
                do {
                    let result = try JSONDecoder().decode(CurrencyRate.self, from: data)
                    self?.rates = result.rates
                    self?.rates[result.base] = 1.0 // Add base currency
                    self?.lastUpdated = Date()
                    print("✓ Updated exchange rates for \(result.base)")
                } catch {
                    self?.error = "Failed to parse rates: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
    
    func convert(amount: Double, from: String, to: String) -> Double? {
        // If same currency, return amount
        if from == to {
            return amount
        }
        
        // Get rates relative to base
        guard let fromRate = rates[from], let toRate = rates[to] else {
            return nil
        }
        
        // Convert: amount * (toRate / fromRate)
        return amount * (toRate / fromRate)
    }
}

// MARK: - Main Currency Tracker View
struct CurrencyTrackerView: View {
    @StateObject private var rateManager = ExchangeRateManager()
    @State private var fromCurrency: String = "USD"
    @State private var toCurrency: String = "EUR"
    @State private var amount: String = "100"
    @State private var showingCurrencyPicker: Bool = false
    @State private var pickingFor: CurrencySelector = .from
    
    enum CurrencySelector {
        case from, to
    }
    
    private var convertedAmount: Double? {
        guard let amt = Double(amount), amt > 0 else { return nil }
        return rateManager.convert(amount: amt, from: fromCurrency, to: toCurrency)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Rate update info
                if let lastUpdated = rateManager.lastUpdated {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Last updated: \(lastUpdated.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Button("Refresh") {
                            rateManager.fetchRates()
                        }
                        .font(.caption)
                        .foregroundColor(LogbookTheme.accentBlue)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(LogbookTheme.navyLight)
                } else if rateManager.isLoading {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Fetching exchange rates...")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(LogbookTheme.navyLight)
                }
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Amount input
                        VStack(spacing: 12) {
                            Text("Amount")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            TextField("Enter amount", text: $amount)
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(LogbookTheme.fieldBackground)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // From currency
                        CurrencyButton(
                            label: "From",
                            code: fromCurrency,
                            name: rateManager.currencyNames[fromCurrency] ?? fromCurrency,
                            action: {
                                pickingFor = .from
                                showingCurrencyPicker = true
                            }
                        )
                        .padding(.horizontal)
                        
                        // Swap button
                        Button(action: {
                            let temp = fromCurrency
                            fromCurrency = toCurrency
                            toCurrency = temp
                        }) {
                            Image(systemName: "arrow.up.arrow.down.circle.fill")
                                .font(.title)
                                .foregroundColor(LogbookTheme.accentBlue)
                        }
                        
                        // To currency
                        CurrencyButton(
                            label: "To",
                            code: toCurrency,
                            name: rateManager.currencyNames[toCurrency] ?? toCurrency,
                            action: {
                                pickingFor = .to
                                showingCurrencyPicker = true
                            }
                        )
                        .padding(.horizontal)
                        
                        // Result
                        if let converted = convertedAmount {
                            VStack(spacing: 12) {
                                Image(systemName: "equal.circle.fill")
                                    .font(.title)
                                    .foregroundColor(LogbookTheme.accentGreen)
                                
                                VStack(spacing: 8) {
                                    Text("Converted Amount")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("\(String(format: "%.2f", converted)) \(toCurrency)")
                                        .font(.system(size: 48, weight: .bold, design: .rounded))
                                        .foregroundColor(LogbookTheme.accentGreen)
                                        .minimumScaleFactor(0.5)
                                        .lineLimit(1)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(LogbookTheme.fieldBackground)
                                .cornerRadius(12)
                                
                                // Exchange rate info
                                if let rate = rateManager.convert(amount: 1, from: fromCurrency, to: toCurrency) {
                                    Text("1 \(fromCurrency) = \(String(format: "%.4f", rate)) \(toCurrency)")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Popular rates table
                        if !rateManager.rates.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Popular Exchange Rates")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                VStack(spacing: 1) {
                                    ForEach(rateManager.popularCurrencies.filter { $0 != fromCurrency }.prefix(10), id: \.self) { currency in
                                        if let rate = rateManager.rates[currency] {
                                            HStack {
                                                HStack(spacing: 8) {
                                                    Text(currency)
                                                        .font(.subheadline)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.white)
                                                    Text(rateManager.currencyNames[currency] ?? "")
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                
                                                Spacer()
                                                
                                                Text(String(format: "%.4f", rate))
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                                    .foregroundColor(LogbookTheme.accentGreen)
                                            }
                                            .padding(.horizontal)
                                            .padding(.vertical, 12)
                                            .background(LogbookTheme.fieldBackground)
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                toCurrency = currency
                                            }
                                        }
                                    }
                                }
                                .cornerRadius(10)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Data source attribution
                        VStack(spacing: 4) {
                            Text("Exchange rates provided by Frankfurter API")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("Data sourced from European Central Bank")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .padding()
                    }
                    .padding(.bottom, 24)
                }
                
                if let error = rateManager.error {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.orange.opacity(0.2))
                }
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Currency Converter")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                if rateManager.rates.isEmpty {
                    rateManager.fetchRates()
                }
            }
            .sheet(isPresented: $showingCurrencyPicker) {
                CurrencyPickerView(
                    selectedCurrency: pickingFor == .from ? $fromCurrency : $toCurrency,
                    rateManager: rateManager
                )
            }
        }
    }
}

// MARK: - Currency Button
struct CurrencyButton: View {
    let label: String
    let code: String
    let name: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(code)
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        Text(name)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(LogbookTheme.navyLight)
            .cornerRadius(12)
        }
    }
}

// MARK: - Currency Picker View
struct CurrencyPickerView: View {
    @Binding var selectedCurrency: String
    @ObservedObject var rateManager: ExchangeRateManager
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    
    private var filteredCurrencies: [String] {
        if searchText.isEmpty {
            return rateManager.popularCurrencies
        }
        return rateManager.popularCurrencies.filter { code in
            code.localizedCaseInsensitiveContains(searchText) ||
            (rateManager.currencyNames[code]?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search currencies...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(LogbookTheme.fieldBackground)
                .cornerRadius(10)
                .padding()
                
                List {
                    ForEach(filteredCurrencies, id: \.self) { code in
                        Button(action: {
                            selectedCurrency = code
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(code)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text(rateManager.currencyNames[code] ?? code)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                if code == selectedCurrency {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(LogbookTheme.accentGreen)
                                }
                                
                                if let rate = rateManager.rates[code] {
                                    Text(String(format: "%.4f", rate))
                                        .font(.caption)
                                        .foregroundColor(LogbookTheme.accentBlue)
                                        .padding(.leading, 8)
                                }
                            }
                        }
                        .listRowBackground(LogbookTheme.navyLight)
                    }
                }
                .listStyle(PlainListStyle())
                .background(LogbookTheme.navy)
                .scrollContentBackground(.hidden)
            }
            .background(LogbookTheme.navy)
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(LogbookTheme.accentBlue)
                }
            }
        }
    }
}