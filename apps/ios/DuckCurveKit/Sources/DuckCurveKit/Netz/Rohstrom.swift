import Foundation

#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif

/// Der rohe Bytestrom einer Antwort, als `AsyncThrowingStream`.
///
/// Das ist die Huelle um `URLSessionDataDelegate`, die es unter iOS und unter Linux gleich
/// aussehen laesst.
///
/// **Warum nicht `URLSession.bytes(for:)`.** Das waere unter iOS der kurze Weg, gibt es aber
/// in der Foundation unter Linux nicht - und damit waere dieses Stueck der Netzschicht das
/// einzige, das sich auf dem Pruefrechner nicht einmal uebersetzen liesse. Der Weg ueber
/// `URLSessionDataDelegate` ist zwei Dutzend Zeilen laenger und laeuft auf beiden Seiten.
///
/// **Modulweit sichtbar und nicht mehr `private`:** zwei Stroeme brauchen ihn, der Live-Strom
/// des Hauses und Alfreds Fortschritt. Zweimal dieselben zwei Dutzend Zeilen waeren zwei
/// Stellen, an denen ein Abbruch verschieden behandelt wird.
final class Rohstrom: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var fort: AsyncThrowingStream<Data, any Error>.Continuation?
    private let sperre = NSLock()

    func oeffne(_ anfrage: URLRequest, in sitzung: URLSession) -> AsyncThrowingStream<Data, any Error> {
        AsyncThrowingStream { fortsetzung in
            self.sperre.lock()
            self.fort = fortsetzung
            self.sperre.unlock()
            let aufgabe = sitzung.dataTask(with: anfrage)
            fortsetzung.onTermination = { _ in aufgabe.cancel() }
            aufgabe.resume()
        }
    }

    func urlSession(
        _ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let http = response as? HTTPURLResponse else {
            completionHandler(.allow)
            return
        }
        // Ein 401 kommt als Antwort mit Rumpf, nicht als Netzfehler. Ohne diese Pruefung wartet
        // der Strom auf Ereignisse, die nie kommen, und die Anzeige sagt „verbindet" statt
        // „das Token stimmt nicht".
        guard (200..<300).contains(http.statusCode) else {
            sperre.lock()
            let f = fort
            sperre.unlock()
            f?.finish(
                throwing: ApiFehler(
                    code: http.statusCode == 401 ? "unauthorized" : "http_error",
                    meldung: "Der Ereignisstrom antwortet mit \(http.statusCode).",
                    status: http.statusCode
                ))
            completionHandler(.cancel)
            return
        }
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        sperre.lock()
        let f = fort
        sperre.unlock()
        f?.yield(data)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        sperre.lock()
        let f = fort
        sperre.unlock()
        if let error {
            f?.finish(throwing: ApiFehler.netz((error as NSError).localizedDescription))
        } else {
            f?.finish()
        }
    }
}
