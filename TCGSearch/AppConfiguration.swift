import Foundation

enum AppConfiguration {
    static var apiBaseURL: URL {
        if
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "TCGSearchAPIBaseURL") as? String,
            let url = URL(string: rawValue)
        {
            return url
        }

        return URL(string: "http://localhost:8080")!
    }
}
