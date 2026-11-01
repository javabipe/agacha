/// Extrai um nome de uma frase falada ("meu nome é paulo" → "Paulo").
public enum NameParser {
    static let leadIns = [
        "meu nome é", "meu nome e", "eu me chamo", "me chamo", "eu sou o", "eu sou a", "eu sou",
        "aqui é o", "aqui é a", "aqui é", "sou o", "sou a", "sou", "é o", "é a", "oi", "olá"
    ]
    public static let maxWords = 2
    public static let maxLength = 20

    public static func clean(_ transcript: String) -> String? {
        var text = transcript.lowercased().split(whereSeparator: { $0 == " " || $0 == "\n" }).joined(separator: " ")
        var stripped = true
        while stripped {
            stripped = false
            for lead in leadIns {
                if text == lead {
                    text = ""
                } else if text.hasPrefix(lead + " ") {
                    text = String(text.dropFirst(lead.count + 1))
                } else {
                    continue
                }
                stripped = true
            }
        }
        let words = text.split(separator: " ").prefix(maxWords).map { word in
            word.filter { $0.isLetter || $0 == "-" }
        }.filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        let name = words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
        return String(name.prefix(maxLength))
    }
}

/// Lista dos últimos nomes usados (mais recente primeiro), sem repetir.
public enum RecentNames {
    public static func adding(_ name: String, to list: [String], limit: Int = 12) -> [String] {
        let key = name.lowercased()
        let rest = list.filter { $0.lowercased() != key }
        return Array(([name] + rest).prefix(limit))
    }
}
