// Compile-time spike: confirms import whisper + C API symbols resolve from XCFramework binary target.
// Not a runtime test — if this file compiles, the integration works.
import whisper

enum WhisperSpike {
    static func verify() {
        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.token_timestamps = true
        _ = params
    }
}
