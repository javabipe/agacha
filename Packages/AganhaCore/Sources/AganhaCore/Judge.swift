/// Julga uma criança a partir das posturas amostradas na janela.
public enum Judge {
    /// Amostra mais velha que isso (s) antes do fim da janela não conta como "visto".
    public static let defaultMaxStaleness = 0.3

    /// A decisão vale pelo estado **no fim da janela**: a última amostra até `windowEnd`.
    /// Sem amostra recente, ou com postura desconhecida, a criança está ausente.
    public static func verdict(expected: Stance, samples: [PostureSample], windowEnd: Double,
                               maxStaleness: Double = defaultMaxStaleness) -> Verdict {
        guard let last = samples.filter({ $0.timestamp <= windowEnd }).max(by: { $0.timestamp < $1.timestamp }),
              windowEnd - last.timestamp <= maxStaleness,
              last.posture != .unknown
        else { return .absent }
        return last.posture == expected.posture ? .ok : .wrong
    }
}
