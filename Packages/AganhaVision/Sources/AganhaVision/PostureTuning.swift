import Foundation

/// Limiares do classificador de postura. Valores "Normal" da especificação (6.1).
public struct PostureTuning: Codable, Sendable, Equatable {
    /// Vira `.crouching` quando o índice de agachamento passa deste valor.
    public var crouchEnter: Double = 0.45
    /// Vira `.standing` quando o índice cai abaixo deste valor.
    public var standEnter: Double = 0.25
    /// Tempo (s) que a condição precisa se manter para trocar de postura.
    public var debounce: TimeInterval = 0.15
    /// Confiança mínima de ombros e quadris.
    public var minConfidence: Double = 0.3
    /// Tempo (s) sem medida válida até a postura virar `.unknown`.
    public var lostTimeout: TimeInterval = 0.3
    /// Tempo (s) em pé antes de a calibração começar a acompanhar a criança.
    public var recalibrationHold: TimeInterval = 1.0
    /// Peso da média móvel da recalibração lenta (por quadro).
    public var recalibrationRate: Double = 0.02
    /// Quadros usados na calibração inicial.
    public var calibrationFrames: Int = 10

    public init() {}

    public static let normal = PostureTuning()
}
