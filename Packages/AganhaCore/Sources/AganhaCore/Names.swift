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

/// O que a pessoa quer fazer no fim da partida, a partir do que disse.
public enum VoiceIntent: Sendable, Equatable {
    case playAgain
    case menu

    private static let menuPhrases = [
        "menu", "sair", "chega", "parar", "para", "terminar", "acabou", "nao", "nao quero", "cansei", "encerrar"
    ]
    private static let againPhrases = [
        "de novo", "novamente", "outra vez", "mais uma", "mais um", "jogar", "continuar", "continua", "vamos",
        "sim", "bora", "quero", "repetir", "revanche"
    ]

    /// Reconhece frases como "de novo!", "vamos jogar", "não quero mais" (nada → nil).
    /// "Não" e "sair" têm prioridade: "não quero jogar de novo" é menu.
    public static func parse(_ transcript: String) -> VoiceIntent? {
        let text = " " + words(transcript).joined(separator: " ") + " "
        if menuPhrases.contains(where: { text.contains(" \($0) ") }) { return .menu }
        if againPhrases.contains(where: { text.contains(" \($0) ") }) { return .playAgain }
        return nil
    }

    private static func words(_ text: String) -> [String] {
        let folded = text.lowercased().map { character -> Character in
            switch character {
            case "á", "à", "â", "ã", "ä": "a"
            case "é", "è", "ê", "ë": "e"
            case "í", "ì", "î", "ï": "i"
            case "ó", "ò", "ô", "õ", "ö": "o"
            case "ú", "ù", "û", "ü": "u"
            case "ç": "c"
            default: character
            }
        }
        return String(folded.map { $0.isLetter ? $0 : " " }).split(separator: " ").map(String.init)
    }
}
