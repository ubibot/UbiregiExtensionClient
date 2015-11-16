import Foundation

func ISO8601String(date: NSDate = NSDate()) -> String {
    let formatter = NSDateFormatter()
    formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ssZ"
    return formatter.stringFromDate(date)
}