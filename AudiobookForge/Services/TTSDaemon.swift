import Foundation

/// Daemon Python long-vivant pour les générations TTS.
///
/// Avant ce daemon, chaque chunk relançait `python fish_s2_pro.py` (ou
/// `audiobook_tool_wrapper.py`) → rechargement du modèle Fish-S2 (~17 Go en
/// unified memory MLX) à CHAQUE chunk. 90% du temps de génération était perdu
/// en réchauffage. Avec le daemon : le modèle est chargé une seule fois et
/// reste résident pour tout le projet.
///
/// Protocole : JSON-line bidirectionnel sur stdin/stdout du process Python.
/// Le daemon Python charge son modèle, émet `{"type":"ready"}`, puis traite
/// chaque requête `{"id":..,"command":..,...}` venue de stdin et répond
/// `{"type":"result","id":..,"status":"ok"|"error",...}` sur stdout.
///
/// Côté Swift, on est un acteur : chaque requête écrit une ligne JSON sur
/// stdin et attend (via une continuation indexée par `id`) la réponse
/// correspondante venue de la tâche de lecture stdout.
actor TTSDaemon {
    static let shared = TTSDaemon()

    /// Identifie une configuration de daemon. Deux requêtes pour la même `Kind`
    /// réutilisent le même process. Changer de `Kind` force un restart (les
    /// modèles vivent dans des venvs Python différents).
    enum Kind: Equatable, Hashable {
        case mlxFishS2
        case ttsAudiobookTool(model: String, modelTarget: String?)

        var displayName: String {
            switch self {
            case .mlxFishS2: return "MLX Fish-S2 daemon"
            case .ttsAudiobookTool(let model, _): return "tts-audiobook-tool daemon (\(model))"
            }
        }
    }

    enum DaemonError: Error, LocalizedError {
        case launchFailed(String)
        case notReady(String)
        case processDied(String)
        case timeout(String)
        case remoteError(String)
        case invalidResponse(String)

        var errorDescription: String? {
            switch self {
            case .launchFailed(let m): return "Daemon TTS : lancement échoué — \(m)"
            case .notReady(let m): return "Daemon TTS : pas prêt — \(m)"
            case .processDied(let m): return "Daemon TTS : process mort — \(m)"
            case .timeout(let m): return "Daemon TTS : timeout — \(m)"
            case .remoteError(let m): return "Daemon TTS : erreur Python — \(m)"
            case .invalidResponse(let m): return "Daemon TTS : réponse invalide — \(m)"
            }
        }
    }

    // MARK: - État interne

    private var running: RunningDaemon?
    private var nextRequestId: UInt64 = 0
    private var pending: [String: CheckedContinuation<[String: Any], Error>] = [:]
    private var readyContinuation: CheckedContinuation<Void, Error>?
    private var daemonReady = false
    private var readyAttempt: UInt64 = 0

    /// Buffer stderr pour le diagnostic en cas de crash.
    private var stderrTail: String = ""

    /// Auto-stop après 5 minutes d'inactivité — filet de sécurité si l'app
    /// reste ouverte sans génération en cours (libère ~17 Go de RAM).
    private static let idleTimeoutSeconds: TimeInterval = 300
    private var idleStopTask: Task<Void, Never>?

    private let logger = Logger.shared
    private let pathResolver = PathResolver.shared

    private struct RunningDaemon {
        let kind: Kind
        let process: Process
        let stdinHandle: FileHandle
        let stdoutTask: Task<Void, Never>
        let stderrTask: Task<Void, Never>
    }

    private init() {}

    // MARK: - API publique

    /// Génère un chunk MLX Fish-S2 via le daemon. Lance le daemon si pas encore prêt.
    func mlxGenerate(
        text: String,
        referenceAudio: String,
        referenceText: String,
        output: String,
        maxNewTokens: Int,
        temperature: Double,
        lengthScale: Double,
        timeoutSeconds: Double = 600
    ) async throws {
        try await ensureRunning(.mlxFishS2)
        var payload: [String: Any] = [
            "command": "generate",
            "text": text,
            "reference_audio": referenceAudio,
            "reference_text": referenceText,
            "output": output,
            "max_new_tokens": maxNewTokens,
            "temperature": temperature,
            "length_scale": lengthScale,
        ]
        _ = try await send(payload: &payload, timeoutSeconds: timeoutSeconds)
    }

    /// Génère un chunk via tts-audiobook-tool (fish-s2 / chatterbox / qwen3).
    func ttsToolGenerate(
        model: String,
        text: String,
        referenceAudio: String,
        referenceText: String,
        output: String,
        temperature: Double,
        maxRetries: Int,
        enableSttValidation: Bool,
        topP: Double?,
        topK: Int?,
        seed: Int?,
        qwenInstruction: String?,
        qwenModelPath: String?,
        qwenSpeakerId: String?,
        qwenLanguage: String?,
        qwenMaxNewTokens: Int? = nil,
        timeoutSeconds: Double = 600
    ) async throws {
        let modelTarget = model == "qwen3" ? qwenModelPath : nil
        try await ensureRunning(.ttsAudiobookTool(model: model, modelTarget: modelTarget))
        var payload: [String: Any] = [
            "command": "generate",
            "text": text,
            "reference_audio": referenceAudio,
            "reference_text": referenceText,
            "output": output,
            "temperature": temperature,
            "max_retries": maxRetries,
            "enable_stt_validation": enableSttValidation,
        ]
        if let v = topP { payload["top_p"] = v }
        if let v = topK { payload["top_k"] = v }
        if let v = seed { payload["seed"] = v }
        if let instruction = qwenInstruction, !instruction.isEmpty {
            payload["qwen_instruction"] = instruction
        }
        if let speaker = qwenSpeakerId, !speaker.isEmpty {
            payload["qwen_speaker_id"] = speaker
        }
        if let language = qwenLanguage, !language.isEmpty {
            payload["qwen_language"] = language
        }
        if let maxNewTokens = qwenMaxNewTokens {
            payload["qwen_max_new_tokens"] = maxNewTokens
        }
        _ = try await send(payload: &payload, timeoutSeconds: timeoutSeconds)
    }

    /// Normalise un fichier audio via le daemon tts-audiobook-tool en cours.
    /// Suppose qu'un daemon ttsAudiobookTool est déjà actif (sinon en lance un sur "fish-s2").
    func ttsToolNormalize(input: String, output: String, model: String = "fish-s2") async throws {
        if running?.kind != .ttsAudiobookTool(model: model, modelTarget: nil) {
            try await ensureRunning(.ttsAudiobookTool(model: model, modelTarget: nil))
        }
        var payload: [String: Any] = [
            "command": "normalize",
            "input": input,
            "output": output,
        ]
        _ = try await send(payload: &payload, timeoutSeconds: 120)
    }

    /// Upsample un fichier audio via le daemon tts-audiobook-tool en cours.
    func ttsToolUpsample(input: String, output: String, model: String = "fish-s2") async throws {
        if running?.kind != .ttsAudiobookTool(model: model, modelTarget: nil) {
            try await ensureRunning(.ttsAudiobookTool(model: model, modelTarget: nil))
        }
        var payload: [String: Any] = [
            "command": "upsample",
            "input": input,
            "output": output,
        ]
        _ = try await send(payload: &payload, timeoutSeconds: 300)
    }

    /// Arrête le daemon proprement (envoi `shutdown` + close stdin + wait).
    /// Sans crash si pas de daemon en cours.
    func stop() async {
        idleStopTask?.cancel()
        idleStopTask = nil
        guard let r = running else { return }
        logger.info("🛑 Arrêt du daemon \(r.kind.displayName)…")

        // Tentative d'arrêt propre : envoi de la commande shutdown
        let id = nextId()
        let line = (try? jsonLine(["id": id, "command": "shutdown"])) ?? "{\"command\":\"shutdown\"}\n"
        try? r.stdinHandle.write(contentsOf: Data(line.utf8))

        // Close stdin → Python boucle quitte sur EOF
        try? r.stdinHandle.close()

        // Attente bornée du process Python (2 s)
        let deadline = Date().addingTimeInterval(2.0)
        while r.process.isRunning && Date() < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        if r.process.isRunning {
            r.process.terminate()
        }

        r.stdoutTask.cancel()
        r.stderrTask.cancel()
        running = nil
        daemonReady = false
        readyAttempt &+= 1

        // Réveil de toutes les requêtes en attente avec une erreur
        let failures = pending
        pending.removeAll()
        for (_, cont) in failures {
            cont.resume(throwing: DaemonError.processDied("daemon stoppé pendant que la requête était en cours"))
        }
        readyContinuation?.resume(throwing: DaemonError.processDied("daemon stoppé"))
        readyContinuation = nil

        logger.info("✅ Daemon arrêté")
    }

    // MARK: - Démarrage du process

    /// Garantit qu'un daemon du bon `Kind` tourne. Restart si le kind diffère.
    private func ensureRunning(_ kind: Kind) async throws {
        if let r = running, r.kind == kind, r.process.isRunning {
            if !daemonReady {
                try await waitForReady(timeoutSeconds: startupTimeout(for: kind))
            }
            return
        }
        if running != nil {
            logger.info("🔄 Changement de kind daemon → redémarrage")
            await stop()
        }
        try await start(kind: kind)
    }

    private func start(kind: Kind) async throws {
        let (executable, arguments) = try resolveLaunch(for: kind)
        daemonReady = false
        readyAttempt &+= 1

        logger.info("🚀 Démarrage \(kind.displayName) : \(executable) \(arguments.joined(separator: " "))")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let cacheRoot = "\(pathResolver.projectRoot)/LocalData/Models"
        var environment = ProcessInfo.processInfo.environment
        environment["HF_HOME"] = "\(cacheRoot)/HuggingFace"
        environment["HUGGINGFACE_HUB_CACHE"] = "\(cacheRoot)/HuggingFace/hub"
        environment.removeValue(forKey: "TRANSFORMERS_CACHE")
        environment["TORCH_HOME"] = "\(cacheRoot)/Torch"
        environment["PYTHONUNBUFFERED"] = "1"
        process.environment = environment

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        do {
            try process.run()
        } catch {
            throw DaemonError.launchFailed("\(executable) (\(error.localizedDescription))")
        }

        let stdoutTask = makeStdoutReader(stdoutPipe.fileHandleForReading)
        let stderrTask = makeStderrReader(stderrPipe.fileHandleForReading)

        let daemon = RunningDaemon(
            kind: kind,
            process: process,
            stdinHandle: stdinPipe.fileHandleForWriting,
            stdoutTask: stdoutTask,
            stderrTask: stderrTask
        )
        running = daemon

        // Surveille la mort du process en arrière-plan → réveille les pending.
        // ATTENTION : on capture une référence à `process` (pas seulement `kind`).
        // Sans ça, si l'ancien process meurt après le démarrage d'un nouveau,
        // son `processDidExit` invalide le NOUVEAU daemon par erreur.
        Task.detached { [weak self] in
            process.waitUntilExit()
            await self?.processDidExit(process: process, status: process.terminationStatus)
        }

        do {
            try await waitForReady(timeoutSeconds: startupTimeout(for: kind))
        } catch {
            await stop()
            throw error
        }
        logger.info("✅ Daemon \(kind.displayName) prêt")
    }

    private func startupTimeout(for kind: Kind) -> Double {
        switch kind {
        case .ttsAudiobookTool(let model, _) where model == "qwen3":
            return 180
        case .mlxFishS2, .ttsAudiobookTool:
            return 180
        }
    }

    private func resolveLaunch(for kind: Kind) throws -> (String, [String]) {
        switch kind {
        case .mlxFishS2:
            let python = pathResolver.pythonPath
            let script = "\(pathResolver.backendScriptsPath)/generate/fish_s2_pro.py"
            guard FileManager.default.fileExists(atPath: python) else {
                throw DaemonError.launchFailed("Python backend introuvable : \(python)")
            }
            guard FileManager.default.fileExists(atPath: script) else {
                throw DaemonError.launchFailed("Script MLX introuvable : \(script)")
            }
            return ("/usr/bin/arch", ["-arm64", python, script, "--daemon"])

        case .ttsAudiobookTool(let model, let modelTarget):
            let venvName: String
            switch model {
            case "fish-s2": venvName = "venv-fish-s2"
            case "chatterbox": venvName = "venv-chatterbox"
            case "qwen3": venvName = "venv-qwen3tts"
            default: throw DaemonError.launchFailed("modèle TTS inconnu : \(model)")
            }
            let toolDir = pathResolver.ttsAudiobookToolPath
            let python = "\(toolDir)/\(venvName)/bin/python"
            let wrapper = "\(toolDir)/audiobook_tool_wrapper.py"
            guard FileManager.default.fileExists(atPath: python) else {
                throw DaemonError.launchFailed("Python venv introuvable : \(python)")
            }
            guard FileManager.default.fileExists(atPath: wrapper) else {
                throw DaemonError.launchFailed("Wrapper introuvable : \(wrapper)")
            }
            var arguments = ["-arm64", python, wrapper, "daemon", "--model", model]
            if let modelTarget, !modelTarget.isEmpty {
                arguments += ["--qwen-model-target", modelTarget]
            }
            return ("/usr/bin/arch", arguments)
        }
    }

    private func waitForReady(timeoutSeconds: Double) async throws {
        if daemonReady { return }
        let attempt = readyAttempt

        // Inscription synchrone de la continuation AVANT toute attente :
        // évite que le `ready` Python ne soit dispatché vers `readyContinuation`
        // encore nil → message perdu → timeout artificiel.
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            if let existing = readyContinuation {
                existing.resume(throwing: DaemonError.notReady("continuation écrasée"))
            }
            readyContinuation = cont

            // Timeout en background : si le ready n'arrive pas à temps, on
            // résume la continuation avec une erreur de timeout.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                await self?.timeoutReady(seconds: timeoutSeconds, attempt: attempt)
            }
        }
    }

    private func timeoutReady(seconds: Double, attempt: UInt64) {
        guard !daemonReady, attempt == readyAttempt else { return }
        if let cont = readyContinuation {
            readyContinuation = nil
            cont.resume(throwing: DaemonError.timeout("chargement du modèle (>\(Int(seconds))s)"))
        }
    }

    // MARK: - Lecture stdout/stderr

    private func makeStdoutReader(_ handle: FileHandle) -> Task<Void, Never> {
        return Task.detached { [weak self] in
            var buffer = Data()
            while !Task.isCancelled {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)

                while let newline = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[..<newline]
                    buffer.removeSubrange(...newline)
                    if let line = String(data: lineData, encoding: .utf8) {
                        guard let self else { return }
                        await self.handleStdoutLine(line)
                    }
                }
            }
            if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) {
                guard let self else { return }
                await self.handleStdoutLine(line)
            }
        }
    }

    private func makeStderrReader(_ handle: FileHandle) -> Task<Void, Never> {
        return Task.detached { [weak self] in
            var buffer = Data()
            while !Task.isCancelled {
                let chunk = handle.availableData
                if chunk.isEmpty { break }
                buffer.append(chunk)

                while let newline = buffer.firstIndex(of: 0x0A) {
                    let lineData = buffer[..<newline]
                    buffer.removeSubrange(...newline)
                    if let line = String(data: lineData, encoding: .utf8) {
                        guard let self else { return }
                        await self.appendStderr(line)
                    }
                }
            }
            if !buffer.isEmpty, let line = String(data: buffer, encoding: .utf8) {
                guard let self else { return }
                await self.appendStderr(line)
            }
        }
    }

    private func appendStderr(_ line: String) {
        // On garde les ~4 derniers Ko pour diagnostiquer un crash
        stderrTail.append(line)
        stderrTail.append("\n")
        if stderrTail.count > 4096 {
            stderrTail = String(stderrTail.suffix(4096))
        }
        if line.localizedCaseInsensitiveContains("error")
            || line.localizedCaseInsensitiveContains("traceback") {
            logger.debug("[daemon stderr] \(line)")
        }
    }

    private func handleStdoutLine(_ line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let data = trimmed.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            logger.debug("[daemon stdout non-JSON] \(trimmed)")
            return
        }

        let type = (json["type"] as? String) ?? ""

        switch type {
        case "ready":
            daemonReady = true
            let model = (json["model"] as? String) ?? "?"
            let load = (json["load_seconds"] as? Double).map { " (load \($0)s)" } ?? ""
            logger.info("✅ Daemon ready : modèle \(model)\(load)")
            if let cont = readyContinuation {
                readyContinuation = nil
                cont.resume()
            }

        case "fatal":
            let msg = (json["message"] as? String) ?? "fatal daemon"
            logger.error("💥 Daemon fatal : \(msg)")
            if let cont = readyContinuation {
                readyContinuation = nil
                cont.resume(throwing: DaemonError.notReady(msg))
            }

        case "result":
            let id = (json["id"] as? String) ?? ""
            guard let cont = pending.removeValue(forKey: id) else {
                logger.debug("[daemon] résultat orphelin id=\(id)")
                return
            }
            let status = (json["status"] as? String) ?? ""
            if status == "ok" {
                cont.resume(returning: json)
            } else {
                let msg = (json["message"] as? String) ?? "erreur sans message"
                cont.resume(throwing: DaemonError.remoteError(msg))
            }
            resetIdleTimer()

        case "progress":
            // Logging fin uniquement
            if let data = json["data"] as? [String: Any],
               let status = data["status"] as? String {
                logger.debug("[daemon progress] \(status)")
            } else if let status = json["status"] as? String {
                logger.debug("[daemon progress] \(status)")
            }

        case "error":
            let msg = (json["message"] as? String) ?? "?"
            logger.error("[daemon error] \(msg)")

        default:
            logger.debug("[daemon] message type=\(type) : \(trimmed.prefix(200))")
        }
    }

    private func processDidExit(process: Process, status: Int32) {
        // Vérifie que c'est BIEN le process actuel qui meurt, pas un ancien
        // process déjà remplacé par un redémarrage entre temps.
        guard let r = running, r.process === process else {
            logger.debug("processDidExit ignoré (process obsolète, code \(status))")
            return
        }
        let kind = r.kind
        running = nil
        daemonReady = false
        readyAttempt &+= 1
        logger.error("💥 Daemon \(kind.displayName) terminé (code \(status))\(stderrTail.isEmpty ? "" : " stderr: \(stderrTail.suffix(400))")")
        r.stdoutTask.cancel()
        r.stderrTask.cancel()

        let failures = pending
        pending.removeAll()
        let err = DaemonError.processDied("code \(status). stderr: \(stderrTail.suffix(400))")
        for (_, cont) in failures {
            cont.resume(throwing: err)
        }
        if let cont = readyContinuation {
            readyContinuation = nil
            cont.resume(throwing: err)
        }
    }

    // MARK: - Envoi de requête

    @discardableResult
    private func send(payload: inout [String: Any], timeoutSeconds: Double) async throws -> [String: Any] {
        guard let r = running else {
            throw DaemonError.notReady("aucun daemon actif")
        }
        let id = nextId()
        payload["id"] = id

        let line = try jsonLine(payload)

        // Inscription de la continuation AVANT l'écriture stdin : sans ça, si
        // Python répond très vite, le reader stdout pourrait dispatcher le
        // résultat avant que `pending[id]` soit posé → résultat orphelin perdu.
        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<[String: Any], Error>) in
            pending[id] = cont

            do {
                try r.stdinHandle.write(contentsOf: Data(line.utf8))
            } catch {
                pending.removeValue(forKey: id)
                cont.resume(throwing: DaemonError.processDied("écriture stdin : \(error.localizedDescription)"))
                return
            }

            // Timeout en background
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                await self?.timeoutPending(id: id, seconds: timeoutSeconds)
            }

        }
    }

    private func timeoutPending(id: String, seconds: Double) {
        if let cont = pending.removeValue(forKey: id) {
            cont.resume(throwing: DaemonError.timeout("requête id=\(id) (>\(Int(seconds))s)"))
        }
    }

    /// Relance le timer d'inactivité : si plus aucune requête pendant
    /// `idleTimeoutSeconds`, le daemon s'arrête seul pour libérer la RAM.
    private func resetIdleTimer() {
        idleStopTask?.cancel()
        idleStopTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(TTSDaemon.idleTimeoutSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await self?.idleStop()
        }
    }

    private func idleStop() async {
        guard running != nil, pending.isEmpty else {
            resetIdleTimer()
            return
        }
        logger.info("⏰ Daemon idle \(Int(TTSDaemon.idleTimeoutSeconds))s → arrêt automatique")
        await stop()
    }

    private func nextId() -> String {
        nextRequestId &+= 1
        return String(nextRequestId)
    }

    private func jsonLine(_ payload: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        guard var s = String(data: data, encoding: .utf8) else {
            throw DaemonError.invalidResponse("encodage UTF-8")
        }
        s.append("\n")
        return s
    }
}
