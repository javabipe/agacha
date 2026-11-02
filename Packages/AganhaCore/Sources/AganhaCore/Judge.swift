/// Quão completo o movimento precisa ser. Meio movimento (índice entre os dois valores) é erro.
public struct JudgeRules: Sendable, Equatable {
    /// "Em pé" de verdade: o quadril desceu no máximo isto (em comprimentos de tronco).
    public var standMax = 0.30
    /// "Agachado" de verdade: o quadril desceu pelo menos isto.
    public var crouchMin = 0.45

    public init(standMax: Double = 0.30, crouchMin: Double = 0.45) {
        self.standMax = standMax
        self.crouchMin = crouchMin
    }
}

/// Julga uma criança a partir das posturas amostradas na janela.
public enum Judge {
    /// Só contam as amostras dos últimos instantes antes do fim da janela (s).
    public static let defaultMaxStaleness = 0.3

    /// Resultado com o que o juiz viu, para mostrar no replay ("índice 0,31, esperado até 0,30").
    public struct Assessment: Sendable, Equatable {
        public let verdict: Verdict
        /// Última medida de agachamento na janela (nil se não houve).
        public let crouchIndex: Double?
        public let posture: Posture?
    }

    public static func verdict(expected: Stance, samples: [PostureSample], windowEnd: Double,
                               rules: JudgeRules = JudgeRules(),
                               maxStaleness: Double = defaultMaxStaleness) -> Verdict {
        assess(expected: expected, samples: samples, windowEnd: windowEnd, rules: rules, maxStaleness: maxStaleness).verdict
    }

    /// A decisão vale pelo **fim da janela**: a maioria das amostras dos últimos 0,3 s (empate: a última).
    /// Quando há índice de agachamento, o movimento precisa estar completo (meio movimento é erro),
    /// sem depender da demora da histerese da postura. Sem amostra recente ou com postura desconhecida: ausente.
    public static func assess(expected: Stance, samples: [PostureSample], windowEnd: Double,
                              rules: JudgeRules = JudgeRules(),
                              maxStaleness: Double = defaultMaxStaleness) -> Assessment {
        let recent = samples
            .filter { $0.timestamp <= windowEnd && windowEnd - $0.timestamp <= maxStaleness && $0.posture != .unknown }
            .sorted { $0.timestamp < $1.timestamp }
        guard let last = recent.last else { return Assessment(verdict: .absent, crouchIndex: nil, posture: nil) }

        func satisfies(_ sample: PostureSample) -> Bool {
            if let index = sample.crouchIndex {
                return expected == .up ? index <= rules.standMax : index >= rules.crouchMin
            }
            return sample.posture == expected.posture
        }
        let good = recent.filter(satisfies).count
        let ok: Bool = good * 2 == recent.count ? satisfies(last) : good * 2 > recent.count
        return Assessment(verdict: ok ? .ok : .wrong, crouchIndex: last.crouchIndex, posture: last.posture)
    }
}
