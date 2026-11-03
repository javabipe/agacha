/// Visual do avatar: cabelo curto ou cabelo comprido com laço.
public enum AvatarLook: String, Codable, Sendable, CaseIterable {
    case boy
    case girl

    public var toggled: AvatarLook { self == .boy ? .girl : .boy }
}

/// Palpite do visual do avatar a partir do **nome** (nada da câmera ou do rosto): listas de nomes comuns no Brasil e,
/// na falta, a terminação. Nome desconhecido ou ambíguo (Alex, Dani) devolve nil e o avatar fica com o visual padrão;
/// quem joga pode trocar com um toque. É só uma sugestão, e pode errar.
public enum NameGender {
    private static let girls: Set<String> = [
        "maria", "ana", "julia", "juliana", "beatriz", "laura", "alice", "helena", "sofia", "isabela", "isabella", "manuela",
        "valentina", "luiza", "luisa", "giovanna", "livia", "lara", "cecilia", "heloisa", "yasmin", "gabriela", "larissa",
        "camila", "amanda", "bruna", "carolina", "fernanda", "patricia", "paula", "paola", "aline", "bia", "duda", "malu", "lu",
        "nina", "clara", "eduarda", "rafaela", "leticia", "vitoria", "melissa", "mariana", "marina", "natalia", "renata",
        "sandra", "simone", "tatiana", "vanessa", "vera", "thais", "raquel", "isadora", "emily", "emilly", "bianca", "antonia",
        "joana", "daniela", "debora", "elisa", "eloisa", "flavia", "gisele", "jessica", "karen", "luana", "marcela", "michele",
        "monica", "priscila", "rita", "sara", "sarah", "stella", "estela", "rebeca", "ingrid", "ines", "isis", "iris", "ester",
        "esther", "noemi", "nicole", "olivia", "agatha", "agata", "mel", "maite", "kamila", "lais", "lorena", "luma", "milena",
        "pietra", "analu", "anna", "maya", "mayara", "rayssa", "raissa", "stefany", "stephany", "tais", "vivian", "alessandra",
        "adriana", "andreia", "andrea", "angela", "barbara", "bruna", "celia", "cristina", "denise", "eliane", "elaine", "fatima",
        "gloria", "graca", "irene", "janaina", "jaqueline", "joice", "leila", "lilian", "lucia", "luciana", "marta", "miriam",
        "neusa", "regina", "roberta", "rosa", "silvia", "sonia", "suelen", "tereza", "teresa", "vilma", "zilda"
    ]
    private static let boys: Set<String> = [
        "pedro", "joao", "lucas", "gabriel", "miguel", "arthur", "artur", "davi", "david", "bernardo", "samuel", "heitor", "enzo",
        "theo", "teo", "lorenzo", "matheus", "mateus", "guilherme", "gustavo", "rafael", "felipe", "daniel", "henrique", "nicolas",
        "nicolau", "benicio", "leonardo", "leo", "eduardo", "vinicius", "vini", "thiago", "tiago", "bruno", "caio", "carlos",
        "paulo", "ricardo", "rodrigo", "marcos", "marcelo", "fernando", "fabio", "andre", "antonio", "jose", "luiz", "luis",
        "otavio", "murilo", "igor", "ian", "yuri", "kaue", "noah", "joaquim", "bento", "caua", "emanuel", "pietro", "vitor",
        "victor", "augusto", "cesar", "diego", "erick", "erik", "francisco", "hugo", "isaac", "jorge", "julio", "kevin", "lucca",
        "luca", "marco", "mauricio", "nathan", "natan", "renato", "roberto", "sergio", "tomas", "valentim", "wesley", "wagner",
        "jonas", "josue", "joshua", "elias", "alan", "alexandre", "anderson", "antonio", "claudio", "cristiano", "edson", "elton",
        "fabricio", "flavio", "geraldo", "gilberto", "helio", "jair", "jefferson", "jonatas", "junior", "leandro", "lincoln",
        "mario", "moises", "nelson", "orlando", "oscar", "patrick", "raul", "reinaldo", "samir", "sidney", "tales", "ulisses",
        "vagner", "washington", "william", "zeca"
    ]
    /// Terminam em "a" mas costumam ser de menino.
    private static let boysEndingInA: Set<String> = ["luca", "joshua", "jonata", "noa", "bartolomeu"]

    public static func guess(_ name: String) -> AvatarLook? {
        let key = firstWord(of: name)
        guard !key.isEmpty else { return nil }
        if girls.contains(key) { return .girl }
        if boys.contains(key) || boysEndingInA.contains(key) { return .boy }
        guard let last = key.last else { return nil }
        switch last {
        case "a": return .girl
        case "o", "r", "l", "s", "m", "n", "u", "k": return .boy
        default: return nil
        }
    }

    /// Primeira palavra, em minúsculas e sem acentos ("João Pedro" → "joao").
    static func firstWord(of name: String) -> String {
        let folded = name.lowercased().map { character -> Character in
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
        let word = String(folded).split(whereSeparator: { !$0.isLetter }).first.map(String.init) ?? ""
        return word
    }
}
