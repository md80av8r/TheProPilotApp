//
//  WeatherService.swift
//  TheProPilotApp
//
//  Created by Jeffrey Kadans on 12/23/25.
//

//
//  AirportWeatherService - Single Airport Weather Fetcher
//  TheProPilotApp
//
//  Aviation weather data service (METAR/TAF from aviationweather.gov)
//
//  NOTE: This is AirportWeatherService for fetching individual airport weather.
//  The main WeatherService (ObservableObject) for the Weather tab is in WeatherData.swift
//

import Foundation

class AirportWeatherService {
    static let shared = AirportWeatherService()
    
    private let baseURL = "https://aviationweather.gov/api/data"
    
    struct WeatherResponse {
        let metar: WeatherData?
        let taf: WeatherData?
    }
    
    func getWeather(for icaoCode: String) async throws -> WeatherResponse {
        async let metarTask = fetchMETAR(for: icaoCode)
        async let tafTask = fetchTAF(for: icaoCode)
        
        let metar = try? await metarTask
        let taf = try? await tafTask
        
        return WeatherResponse(metar: metar, taf: taf)
    }
    
    // MARK: - METAR
    
    func fetchMETAR(for icaoCode: String) async throws -> WeatherData {
        let urlString = "\(baseURL)/metar?ids=\(icaoCode)&format=json&taf=false"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.networkError
        }
        
        // Try to parse as JSON array
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let firstMetar = jsonArray.first {
            return parseMetar(from: firstMetar)
        }
        
        // Fallback: try as plain text
        if let rawText = String(data: data, encoding: .utf8) {
            return WeatherData(
                rawText: rawText,
                observedTime: formatCurrentTime(),
                wind: nil,
                visibility: nil,
                temperature: nil,
                altimeter: nil
            )
        }
        
        throw WeatherError.parsingError
    }
    
    private func parseMetar(from json: [String: Any]) -> WeatherData {
        let rawText = json["rawOb"] as? String ?? ""
        let obsTime = json["obsTime"] as? String ?? ""
        
        // Parse components
        var wind: String?
        var visibility: String?
        var temperature: String?
        var altimeter: String?
        
        if let windDir = json["wdir"] as? Int,
           let windSpeed = json["wspd"] as? Int {
            wind = "\(windDir)° at \(windSpeed) kts"
            
            if let gust = json["wgst"] as? Int {
                wind? += " gusting \(gust) kts"
            }
        }
        
        if let visib = json["visib"] as? String {
            visibility = "\(visib) SM"
        }
        
        if let temp = json["temp"] as? Int,
           let dewp = json["dewp"] as? Int {
            temperature = "\(temp)°C / \(dewp)°C"
        }
        
        if let altim = json["altim"] as? Double {
            altimeter = String(format: "%.2f inHg", altim)
        }
        
        return WeatherData(
            rawText: rawText,
            observedTime: formatObsTime(obsTime),
            wind: wind,
            visibility: visibility,
            temperature: temperature,
            altimeter: altimeter
        )
    }
    
    // MARK: - TAF
    
    func fetchTAF(for icaoCode: String) async throws -> WeatherData {
        let urlString = "\(baseURL)/taf?ids=\(icaoCode)&format=json"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.networkError
        }
        
        // Try to parse as JSON array
        if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let firstTaf = jsonArray.first {
            return parseTaf(from: firstTaf)
        }
        
        // Fallback: try as plain text
        if let rawText = String(data: data, encoding: .utf8) {
            return WeatherData(
                rawText: rawText,
                observedTime: formatCurrentTime(),
                wind: nil,
                visibility: nil,
                temperature: nil,
                altimeter: nil
            )
        }
        
        throw WeatherError.parsingError
    }
    
    private func parseTaf(from json: [String: Any]) -> WeatherData {
        let rawText = json["rawTAF"] as? String ?? ""
        let issueTime = json["issueTime"] as? String ?? ""
        
        return WeatherData(
            rawText: rawText,
            observedTime: formatObsTime(issueTime),
            wind: nil,
            visibility: nil,
            temperature: nil,
            altimeter: nil
        )
    }
    
    // MARK: - Helpers
    
    private func formatObsTime(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: isoString) else {
            return isoString
        }
        
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .none
        displayFormatter.timeStyle = .short
        return displayFormatter.string(from: date) + " Z"
    }
    
    private func formatCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: Date()) + " Z"
    }
}

// MARK: - Errors

enum WeatherError: Error {
    case invalidURL
    case networkError
    case parsingError
    case notFound
}

// MARK: - Alternative: CheckWX API (if you have API key)

class CheckWXService {
    private let apiKey: String
    private let baseURL = "https://api.checkwx.com"
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func fetchMETAR(for icaoCode: String) async throws -> String {
        let urlString = "\(baseURL)/metar/\(icaoCode)/decoded"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.networkError
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataArray = json["data"] as? [String],
           let metar = dataArray.first {
            return metar
        }
        
        throw WeatherError.parsingError
    }
}

// MARK: - Alternative: AWC Text Data Server (Simple, No Auth)

class AWCTextDataService {
    func fetchMETAR(for icaoCode: String) async throws -> String {
        let urlString = "https://aviationweather.gov/cgi-bin/data/metar.php?ids=\(icaoCode)&hours=0&format=raw"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let text = String(data: data, encoding: .utf8) else {
            throw WeatherError.parsingError
        }
        
        // Parse the raw METAR from the response
        let lines = text.components(separatedBy: .newlines)
        let metarLines = lines.filter { $0.starts(with: icaoCode) }
        
        return metarLines.first ?? text
    }
    
    func fetchTAF(for icaoCode: String) async throws -> String {
        let urlString = "https://aviationweather.gov/cgi-bin/data/taf.php?ids=\(icaoCode)&format=raw"
        
        guard let url = URL(string: urlString) else {
            throw WeatherError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let text = String(data: data, encoding: .utf8) else {
            throw WeatherError.parsingError
        }
        
        // Parse the raw TAF from the response
        let lines = text.components(separatedBy: .newlines)
        let tafLines = lines.filter { !$0.isEmpty && !$0.starts(with: "<") }
        
        return tafLines.joined(separator: "\n")
    }
}