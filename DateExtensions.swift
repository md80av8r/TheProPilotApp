import Foundation

// MARK: - Date Extensions for ProPilot
extension Date {
    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }
    
    var startOfWorkWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        let startOfWeek = calendar.date(from: components) ?? self
        // Find Monday (weekday 2)
        let weekday = calendar.component(.weekday, from: startOfWeek)
        let daysFromMonday = (weekday - 2 + 7) % 7
        return calendar.date(byAdding: .day, value: -daysFromMonday, to: startOfWeek) ?? startOfWeek
    }
    
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: self)
    }
}
