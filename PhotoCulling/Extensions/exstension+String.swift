//
//  exstension+String.swift
//  PhotoCulling
//
//  Created by Thomas Evensen on 27/01/2026.
//

import Foundation

extension String {
    func en_date_from_string() -> Date {
        let dateformatter = DateFormatter()
        dateformatter.locale = Locale(identifier: "en")
        dateformatter.dateStyle = .medium
        dateformatter.timeStyle = .short
        dateformatter.dateFormat = "dd MMM yyyy HH:mm"
        return dateformatter.date(from: self) ?? Date()
    }

    func validate_en_date_from_string() -> Date? {
        let dateformatter = DateFormatter()
        dateformatter.locale = Locale(identifier: "en")
        dateformatter.dateStyle = .medium
        dateformatter.timeStyle = .short
        dateformatter.dateFormat = "dd MMM yyyy HH:mm"
        return dateformatter.date(from: self)
    }

    func localized_date_from_string() -> Date {
        let dateformatter = DateFormatter()
        dateformatter.formatterBehavior = .behavior10_4
        dateformatter.dateStyle = .medium
        dateformatter.timeStyle = .short
        return dateformatter.date(from: self) ?? Date()
    }
}
