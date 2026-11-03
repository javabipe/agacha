// Ferramenta de desenvolvimento: abre a página da TV num WebKit do Mac, executa passos de JavaScript e salva capturas em PNG.
// Uso: swiftc scripts/render_tv_page.swift -o /tmp/render_tv && /tmp/render_tv pagina.html 1920 1080 passos.json
// passos.json: [{"js": "render({...})", "wait": 500, "png": "/tmp/a.png"}, ...]
import AppKit
import WebKit

struct Step: Decodable {
    var js: String?
    var wait: Int?
    var png: String?
}

final class Runner: NSObject, WKNavigationDelegate {
    private let web: WKWebView
    private let window: NSWindow
    private let steps: [Step]
    private var index = 0

    init(html: String, width: Double, height: Double, steps: [Step]) {
        self.steps = steps
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless],
                          backing: .buffered, defer: false)
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        super.init()
        window.contentView?.addSubview(web)
        window.setFrameOrigin(NSPoint(x: 0, y: 0))   // na tela: o WebKit pausa animações fora dela
        window.orderFrontRegardless()
        web.navigationDelegate = self
        web.loadHTMLString(html, baseURL: URL(string: "http://127.0.0.1:8080/"))
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        runNext()
    }

    private func runNext() {
        guard index < steps.count else { NSApp.terminate(nil); return }
        let step = steps[index]
        index += 1
        let after = { [self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(step.wait ?? 100)) {
                if let png = step.png { self.snapshot(to: png) } else { self.runNext() }
            }
        }
        if let js = step.js {
            web.evaluateJavaScript(js) { _, error in
                if let error {
                    let info = (error as NSError).userInfo
                    print("erro de JS:", info["WKJavaScriptExceptionMessage"] ?? error.localizedDescription,
                          "linha", info["WKJavaScriptExceptionLineNumber"] ?? "?")
                }
                after()
            }
        } else {
            after()
        }
    }

    private func snapshot(to path: String) {
        web.takeSnapshot(with: WKSnapshotConfiguration()) { [self] image, error in
            if let image, let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
               let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: path))
                print("salvo:", path)
            } else {
                print("falha na captura:", error?.localizedDescription ?? "?")
            }
            runNext()
        }
    }
}

let arguments = CommandLine.arguments
guard arguments.count >= 5, let html = try? String(contentsOfFile: arguments[1], encoding: .utf8),
      let width = Double(arguments[2]), let height = Double(arguments[3]),
      let data = try? Data(contentsOf: URL(fileURLWithPath: arguments[4])),
      let steps = try? JSONDecoder().decode([Step].self, from: data)
else {
    print("uso: render_tv pagina.html largura altura passos.json")
    exit(1)
}
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let runner = Runner(html: html, width: width, height: height, steps: steps)
withExtendedLifetime(runner) { app.run() }
