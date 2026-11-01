/// Quão completo o movimento precisa ser. Meio movimento (índice entre os dois valores) é erro.
public struct JudgeRules: Sendable, Equatable {
    /// "Em pé" de verdade: o quadril desceu no máximo isto (em comprimentos de tronco).
    public var standMax = 0.25
    /// "Agachado" de verdade: o quadril desceu pelo menos isto.
    public var crouchMin = 0.45

    public init(standMax: Double = 0.25, crouchMin: Double = 0.45) {
        self.standMax = standMax
        self.crouchMin = crouchMin
    }
}

/// Julga uma criança a partir das posturas amostradas na janela.
public enum Judge {
    /// Amostra mais velha que isso (s) antes do fim da janela não conta como "visto".
    public static let defaultMaxStaleness = 0.3

    /// A decisão vale pelo estado **no fim da janela**: a última amostra até `windowEnd`.
    /// Sem amostra recente, ou com postura desconhecida, a criança está ausente.
    /// Se a amostra traz o índice de agachamento, o movimento precisa estar completo.
    public static func verdict(expected: Stance, samples: [PostureSample], windowEnd: Double,
                               rules: JudgeRules = JudgeRules(),
                               maxStaleness: Double = defaultMaxStaleness) -> Verdict {
        guard let last = samples.filter({ $0.timestamp <= windowEnd }).max(by: { $0.timestamp < $1.timestamp }),
              windowEnd - last.timestamp <= maxStaleness,
              last.posture != .unknown
        else { return .absent }
        guard last.posture == expected.posture else { return .wrong }
        guard let index = last.crouchIndex else { return .ok }
        switch expected {
        case .up: return index <= rules.standMax ? .ok : .wrong
        case .down: return index >= rules.crouchMin ? .ok : .wrong
        }
    }
}
