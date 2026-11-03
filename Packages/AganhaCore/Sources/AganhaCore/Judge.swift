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

    /// Resultado com o que o juiz viu, para mostrar no replay ("mediu 0,31 · precisava ≤ 0,25").
    /// Uma medida nos instantes finais da janela (para diagnóstico).
    public struct TracePoint: Sendable, Equatable {
        /// Segundos antes do fim da janela (0 = o fim).
        public let secondsBeforeEnd: Double
        public let crouchIndex: Double?
        public let posture: Posture
    }

    public struct Assessment: Sendable, Equatable {
        public let verdict: Verdict
        /// Última medida de agachamento na janela (nil se não houve).
        public let crouchIndex: Double?
        public let posture: Posture?
        /// Medidas dos últimos ~1,5 s, da mais antiga para a mais nova.
        public let trace: [TracePoint]
    }

    /// Quando o jogador chegou à postura certa e ficou nela até o fim da janela.
    public enum Settle: Sendable, Equatable {
        /// Já estava na postura certa desde a primeira medida da janela.
        case held
        /// Instante (mesmo relógio das amostras) da primeira medida certa depois da última errada.
        case at(Double)
        /// No fim da janela não estava na postura certa.
        case never
    }

    /// Mesma régua do julgamento (postura e, se houver, índice de agachamento), olhando a janela toda.
    public static func settle(expected: Stance, samples: [PostureSample], windowEnd: Double,
                              rules: JudgeRules = JudgeRules()) -> Settle {
        let ordered = samples.filter { $0.timestamp <= windowEnd }.sorted { $0.timestamp < $1.timestamp }
        func satisfied(_ sample: PostureSample) -> Bool {
            guard sample.posture == expected.posture else { return false }
            guard let index = sample.crouchIndex else { return true }
            return expected == .up ? index <= rules.standMax : index >= rules.crouchMin
        }
        guard let last = ordered.last, satisfied(last) else { return .never }
        guard let lastWrong = ordered.lastIndex(where: { !satisfied($0) }) else { return .held }
        return .at(ordered[lastWrong + 1].timestamp)
    }

    /// Uma medida a cada 0,3 s nos últimos 1,5 s da janela.
    static func trace(of samples: [PostureSample], windowEnd: Double) -> [TracePoint] {
        let ordered = samples.filter { $0.timestamp <= windowEnd }.sorted { $0.timestamp < $1.timestamp }
        return (0...5).reversed().compactMap { step -> TracePoint? in
            let target = windowEnd - 0.3 * Double(step)
            guard let sample = ordered.last(where: { $0.timestamp <= target && $0.timestamp > target - 0.3 }) else { return nil }
            return TracePoint(secondsBeforeEnd: 0.3 * Double(step), crouchIndex: sample.crouchIndex, posture: sample.posture)
        }
    }

    public static func verdict(expected: Stance, samples: [PostureSample], windowEnd: Double,
                               rules: JudgeRules = JudgeRules(),
                               maxStaleness: Double = defaultMaxStaleness) -> Verdict {
        assess(expected: expected, samples: samples, windowEnd: windowEnd, rules: rules, maxStaleness: maxStaleness).verdict
    }

    /// A decisão vale pelo estado **no fim da janela**: a última amostra até `windowEnd`.
    /// Sem amostra recente, ou com postura desconhecida, a criança está ausente.
    /// Se a amostra traz o índice de agachamento, o movimento precisa estar completo.
    public static func assess(expected: Stance, samples: [PostureSample], windowEnd: Double,
                              rules: JudgeRules = JudgeRules(),
                              maxStaleness: Double = defaultMaxStaleness) -> Assessment {
        guard let last = samples.filter({ $0.timestamp <= windowEnd }).max(by: { $0.timestamp < $1.timestamp }),
              windowEnd - last.timestamp <= maxStaleness,
              last.posture != .unknown
        else { return Assessment(verdict: .absent, crouchIndex: nil, posture: nil, trace: trace(of: samples, windowEnd: windowEnd)) }

        func result(_ verdict: Verdict) -> Assessment {
            Assessment(verdict: verdict, crouchIndex: last.crouchIndex, posture: last.posture,
                       trace: trace(of: samples, windowEnd: windowEnd))
        }
        guard last.posture == expected.posture else { return result(.wrong) }
        guard let index = last.crouchIndex else { return result(.ok) }
        switch expected {
        case .up: return result(index <= rules.standMax ? .ok : .wrong)
        case .down: return result(index >= rules.crouchMin ? .ok : .wrong)
        }
    }
}
