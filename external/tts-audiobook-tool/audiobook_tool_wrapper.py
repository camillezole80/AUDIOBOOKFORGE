#!/usr/bin/env python3
"""
AudiobookForge Wrapper for tts-audiobook-tool
Provides a simple CLI interface for AudiobookForge to use tts-audiobook-tool's capabilities
"""

import sys
import json
import argparse
import os
import subprocess
import tempfile
import traceback
from pathlib import Path
from typing import Optional
import librosa
import numpy as np
import soundfile

# Add tts_audiobook_tool to path
sys.path.insert(0, str(Path(__file__).parent))

from tts_audiobook_tool.app_types import Sound, SttConfig, SttVariant, Strictness
from tts_audiobook_tool.sound_file_util import SoundFileUtil
from tts_audiobook_tool.loudness_normalization_util import LoudnessNormalizationUtil
from tts_audiobook_tool.sidon_util import SidonUtil
from tts_audiobook_tool.stt import Stt
from tts_audiobook_tool.validate_util import ValidateUtil
from tts_audiobook_tool.validation_result import ValidationResult
from tts_audiobook_tool.whisper_util import WhisperUtil
from tts_audiobook_tool.prefs import Prefs
from tts_audiobook_tool.state import State
from tts_audiobook_tool.project import Project


class AudiobookToolWrapper:
    """Wrapper class for tts-audiobook-tool integration"""

    def __init__(
        self,
        model_name: str,
        load_model: bool = True,
        model_target: Optional[str] = None
    ):
        """
        model_name : nom du modèle (fish-s2 / chatterbox / qwen3). Garde sa valeur
                     même quand `load_model=False` pour pouvoir charger plus tard.
        load_model : si False, on n'instancie pas le modèle (utile pour
                     normalize/upsample qui n'en ont pas besoin).
        """
        self.model_name = model_name
        self.model_target = model_target
        self.model = None
        if load_model:
            self._load_model()

    def ensure_model_loaded(self):
        """Charge le modèle si pas déjà chargé (idempotent)."""
        if self.model is None:
            self._load_model()

    def _load_model(self):
        """Load the specified TTS model"""
        try:
            if self.model_name == "fish-s2":
                from tts_audiobook_tool.tts_model.fish_s2_model import FishS2Model
                self.model = FishS2Model()
            elif self.model_name == "chatterbox":
                from tts_audiobook_tool.tts_model.chatterbox_model import ChatterboxModel
                from tts_audiobook_tool.tts_model.chatterbox_base_model import ChatterboxType
                import torch
                device = "cuda" if torch.cuda.is_available() else "cpu"
                # Use MULTILINGUAL as the default model type for Chatterbox
                self.model = ChatterboxModel(model_type=ChatterboxType.MULTILINGUAL, device=device)
            elif self.model_name == "qwen3":
                import torch
                from tts_audiobook_tool.tts_model.qwen3_base_model import Qwen3BaseModel
                from tts_audiobook_tool.tts_model.qwen3_model import Qwen3Model
                device = "mps" if torch.backends.mps.is_available() else (
                    "cuda" if torch.cuda.is_available() else "cpu"
                )
                target = self.model_target or Qwen3BaseModel.DEFAULT_REPO_ID
                self.model = Qwen3Model(target, device)
            else:
                raise ValueError(f"Unknown model: {self.model_name}")
            
            self._log_progress({"status": "model_loaded", "model": self.model_name})
        except Exception as e:
            self._log_error(f"Failed to load model {self.model_name}: {str(e)}")
            raise
    
    def generate(
        self,
        text: str,
        reference_audio: str,
        reference_text: str,
        output: str,
        temperature: float = 0.8,
        max_retries: int = 3,
        enable_stt_validation: bool = True,
        top_p: Optional[float] = None,
        top_k: Optional[int] = None,
        seed: Optional[int] = None,
        qwen_instruction: Optional[str] = None,
        qwen_speaker_id: Optional[str] = None,
        qwen_language: Optional[str] = None,
        qwen_max_new_tokens: Optional[int] = None
    ):
        """
        Generate audio with STT validation and retry logic
        """
        try:
            self._log_progress({"status": "starting", "text_length": len(text)})
            
            # Create a minimal project object for generation
            project = self._create_project(
                reference_audio=reference_audio,
                reference_text=reference_text,
                temperature=temperature,
                top_p=top_p,
                top_k=top_k,
                seed=seed,
                qwen_instruction=qwen_instruction,
                qwen_speaker_id=qwen_speaker_id,
                qwen_language=qwen_language,
                qwen_max_new_tokens=qwen_max_new_tokens
            )
            
            best_sound = None
            best_word_errors = float('inf')
            
            for attempt in range(max_retries):
                self._log_progress({
                    "status": "generating",
                    "attempt": attempt + 1,
                    "max_attempts": max_retries
                })
                
                # Generate audio
                force_random_seed = (attempt > 0)  # Use random seed for retries
                result = self.model.generate_using_project(
                    project=project,
                    prompts=[text],
                    force_random_seed=force_random_seed
                )
                
                if isinstance(result, str):
                    # Error occurred
                    self._log_error(f"Generation failed: {result}")
                    if attempt == max_retries - 1:
                        raise RuntimeError(f"Generation failed after {max_retries} attempts: {result}")
                    continue
                
                sound = result[0]
                
                # Validate with STT if enabled
                if enable_stt_validation:
                    self._log_progress({"status": "validating", "attempt": attempt + 1})
                    
                    validation_result = self._validate_sound(sound, text, project)
                    
                    word_errors = getattr(validation_result, "num_errors", 0)
                    if not validation_result.is_fail:
                        self._log_progress({
                            "status": "validation_passed",
                            "attempt": attempt + 1,
                            "word_errors": word_errors
                        })
                        best_sound = validation_result.sound
                        break
                    else:
                        self._log_progress({
                            "status": "validation_failed",
                            "attempt": attempt + 1,
                            "word_errors": word_errors,
                            "reason": validation_result.get_ui_message()
                        })
                        
                        # Keep track of best attempt
                        if word_errors < best_word_errors:
                            best_word_errors = word_errors
                            best_sound = sound
                        
                        if attempt == max_retries - 1:
                            if self.model_name == "qwen3":
                                raise RuntimeError(
                                    f"Qwen STT validation failed after {max_retries} attempts "
                                    f"(best word errors: {best_word_errors})"
                                )
                            self._log_progress({
                                "status": "using_best_attempt",
                                "word_errors": best_word_errors
                            })
                else:
                    # No validation, use first generation
                    best_sound = sound
                    break
            
            if best_sound is None:
                raise RuntimeError("Failed to generate valid audio")
            
            # Save the audio
            self._log_progress({"status": "saving", "output": output})
            soundfile.write(output, best_sound.data, best_sound.sr, subtype="PCM_16")
            
            self._log_progress({
                "status": "completed",
                "output": output,
                "duration": best_sound.duration
            })
            
        except Exception as e:
            self._log_error(f"Generation failed: {str(e)}\n{traceback.format_exc()}")
            raise
    
    def _create_project(
        self,
        reference_audio: str,
        reference_text: str,
        temperature: float,
        top_p: Optional[float],
        top_k: Optional[int],
        seed: Optional[int],
        qwen_instruction: Optional[str],
        qwen_speaker_id: Optional[str],
        qwen_language: Optional[str],
        qwen_max_new_tokens: Optional[int]
    ) -> Project:
        """Create a minimal project object for generation"""
        project = Project()
        
        # Set model-specific fields based on the model name
        if self.model_name == "chatterbox":
            project.chatterbox_voice_file_name = reference_audio
            project.chatterbox_temperature = temperature
            if top_p is not None:
                project.chatterbox_top_p = top_p
            if seed is not None:
                project.chatterbox_seed = seed
        elif self.model_name == "fish-s2":
            project.fish_s2_voice_file_name = reference_audio
            project.fish_s2_voice_transcript = reference_text
            project.fish_s2_temperature = temperature
            if top_p is not None:
                project.fish_s2_top_p = top_p
            if top_k is not None:
                project.fish_s2_top_k = top_k
            if seed is not None:
                project.fish_s2_seed = seed
        elif self.model_name == "qwen3":
            project.qwen3_target = self.model_target or ""
            project.qwen3_model_type = getattr(self.model, "model_type", "")
            project.qwen3_voice_file_name = reference_audio
            project.qwen3_voice_transcript = reference_text
            project.qwen3_instructions = qwen_instruction or ""
            project.qwen3_speaker_id = qwen_speaker_id or "ryan"
            project.language_code = qwen_language or "fr"
            project.qwen3_max_new_tokens = qwen_max_new_tokens or 2048
            project.qwen3_temperature = temperature
            if top_p is not None:
                project.qwen3_top_p = top_p
            if top_k is not None:
                project.qwen3_top_k = top_k
            if seed is not None:
                project.qwen3_seed = seed
        
        return project
    
    def _validate_sound(self, sound: Sound, expected_text: str, project: Project) -> ValidationResult:
        """Validate generated audio using STT"""
        transcript_words = WhisperUtil.transcribe_to_words(
            sound=sound,
            language_code=project.language_code,
            stt_variant=SttVariant.LARGE_V3_TURBO,
            stt_config=SttConfig.CPU_INT8FLOAT32,
        )
        if isinstance(transcript_words, str):
            raise RuntimeError(f"Whisper validation failed: {transcript_words}")

        return ValidateUtil.validate(
            sound=sound,
            source=expected_text,
            transcript_words=transcript_words,
            language_code=project.language_code,
            strictness=Strictness.MODERATE,
        )
    
    def normalize(self, input_path: str, output_path: str):
        """Normalize audio loudness using EBU R128"""
        try:
            self._log_progress({"status": "normalizing", "input": input_path})

            output_dir = str(Path(output_path).parent)
            os.makedirs(output_dir, exist_ok=True)
            sample_rate = int(soundfile.info(input_path).samplerate)
            fd, temp_path = tempfile.mkstemp(
                prefix=".audiobookforge-normalized-",
                suffix=".wav",
                dir=output_dir
            )
            os.close(fd)
            try:
                subprocess.run(
                    [
                        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
                        "-i", input_path,
                        "-af", "loudnorm=I=-18:LRA=11:TP=-1.5",
                        "-ar", str(sample_rate),
                        "-c:a", "pcm_s16le",
                        temp_path,
                    ],
                    check=True,
                    capture_output=True,
                    text=True,
                )
                os.replace(temp_path, output_path)
            finally:
                if os.path.exists(temp_path):
                    os.remove(temp_path)
            
            self._log_progress({"status": "completed", "output": output_path})
            
        except Exception as e:
            self._log_error(f"Normalization failed: {str(e)}")
            raise
    
    def upsample(self, input_path: str, output_path: str):
        """Upsample audio to 48kHz using high-quality SoXR resampling."""
        try:
            self._log_progress({"status": "upsampling", "input": input_path})

            data, sample_rate = soundfile.read(input_path, dtype="float32")
            upsampled = librosa.resample(
                data,
                orig_sr=int(sample_rate),
                target_sr=48_000,
                res_type="soxr_hq"
            )
            soundfile.write(output_path, upsampled, 48_000, subtype="PCM_16")
            
            self._log_progress({"status": "completed", "output": output_path})
            
        except Exception as e:
            self._log_error(f"Upsampling failed: {str(e)}")
            raise
    
    def _log_progress(self, data: dict):
        """Log progress as JSON to stdout"""
        print(json.dumps({"type": "progress", "data": data}), flush=True)

    def _log_error(self, message: str):
        """Log error as JSON to stdout"""
        print(json.dumps({"type": "error", "message": message}), flush=True)


def _emit(payload: dict) -> None:
    """Émet un JSON sur stdout, flush immédiat (sinon Swift attend indéfiniment)."""
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def run_daemon(model_name: str, model_target: Optional[str] = None) -> int:
    """
    Boucle daemon : charge le modèle UNE fois, lit du JSON sur stdin,
    génère/normalize/upsample en boucle. Évite de recharger ~17 Go par chunk.

    Protocole (chaque ligne = un JSON unique) :

        stdout -> {"type":"ready","model":"<nom>"}                  (au démarrage)

        stdin <-  {"id":"42","command":"generate","text":"…","reference_audio":"…",
                   "reference_text":"…","output":"/path/out.wav",
                   "temperature":0.8,"max_retries":3,
                   "enable_stt_validation":false,
                   "top_p":null,"top_k":null,"seed":null}
        stdout -> {"type":"result","id":"42","status":"ok","output":"…"}
        stdout -> {"type":"result","id":"42","status":"error","message":"…"}

        stdin <-  {"id":"43","command":"normalize","input":"…","output":"…"}
        stdin <-  {"id":"44","command":"upsample","input":"…","output":"…"}
        stdin <-  {"id":"99","command":"shutdown"}
        EOF -> arrêt propre
    """
    try:
        wrapper = AudiobookToolWrapper(
            model_name,
            load_model=True,
            model_target=model_target
        )
    except Exception as e:
        _emit({
            "type": "fatal",
            "message": f"échec du chargement du modèle {model_name} : {e}",
            "traceback": traceback.format_exc(),
        })
        return 1

    _emit({"type": "ready", "model": model_name})

    for raw_line in sys.stdin:
        line = raw_line.strip()
        if not line:
            continue

        try:
            req = json.loads(line)
        except json.JSONDecodeError as e:
            _emit({"type": "error", "message": f"JSON invalide : {e}"})
            continue

        req_id = str(req.get("id", ""))
        command = req.get("command", "")

        if command == "shutdown":
            _emit({"type": "result", "id": req_id, "status": "ok"})
            return 0

        try:
            if command == "generate":
                wrapper.generate(
                    text=req["text"],
                    reference_audio=req["reference_audio"],
                    reference_text=req["reference_text"],
                    output=req["output"],
                    temperature=float(req.get("temperature", 0.8)),
                    max_retries=int(req.get("max_retries", 3)),
                    enable_stt_validation=bool(req.get("enable_stt_validation", False)),
                    top_p=req.get("top_p"),
                    top_k=req.get("top_k"),
                    seed=req.get("seed"),
                    qwen_instruction=req.get("qwen_instruction"),
                    qwen_speaker_id=req.get("qwen_speaker_id"),
                    qwen_language=req.get("qwen_language"),
                    qwen_max_new_tokens=req.get("qwen_max_new_tokens"),
                )
                _emit({"type": "result", "id": req_id, "status": "ok", "output": req["output"]})

            elif command == "normalize":
                wrapper.normalize(req["input"], req["output"])
                _emit({"type": "result", "id": req_id, "status": "ok", "output": req["output"]})

            elif command == "upsample":
                wrapper.upsample(req["input"], req["output"])
                _emit({"type": "result", "id": req_id, "status": "ok", "output": req["output"]})

            else:
                _emit({
                    "type": "result", "id": req_id, "status": "error",
                    "message": f"commande inconnue : {command}",
                })
        except Exception as e:
            _emit({
                "type": "result", "id": req_id, "status": "error",
                "message": str(e),
                "traceback": traceback.format_exc(),
            })

    return 0


def main():
    parser = argparse.ArgumentParser(description="AudiobookForge TTS Wrapper")
    subparsers = parser.add_subparsers(dest='command', required=True)

    # Daemon command : modèle chargé une fois, requêtes JSON sur stdin
    daemon_parser = subparsers.add_parser('daemon', help='Mode daemon stdin/stdout JSON')
    daemon_parser.add_argument('--model', required=True, choices=['fish-s2', 'chatterbox', 'qwen3'],
                               help='TTS model to keep loaded')
    daemon_parser.add_argument('--qwen-model-target',
                               help='Local path or Hugging Face ID for Qwen3-TTS')

    # Generate command
    gen_parser = subparsers.add_parser('generate', help='Generate audio from text')
    gen_parser.add_argument('--model', required=True, choices=['fish-s2', 'chatterbox', 'qwen3'],
                           help='TTS model to use')
    gen_parser.add_argument('--text', required=True, help='Text to generate')
    gen_parser.add_argument('--reference-audio', required=True, help='Path to reference audio')
    gen_parser.add_argument('--reference-text', required=True, help='Transcription of reference audio')
    gen_parser.add_argument('--output', required=True, help='Output WAV file path')
    gen_parser.add_argument('--temperature', type=float, default=0.8, help='Temperature (default: 0.8)')
    gen_parser.add_argument('--max-retries', type=int, default=3, help='Max retry attempts (default: 3)')
    gen_parser.add_argument('--enable-stt-validation', action='store_true',
                           help='Enable STT validation with retry')
    gen_parser.add_argument('--top-p', type=float, help='Top-p sampling')
    gen_parser.add_argument('--top-k', type=int, help='Top-k sampling')
    gen_parser.add_argument('--seed', type=int, help='Random seed')
    gen_parser.add_argument('--qwen-instruction', help='Qwen3-TTS natural-language style instruction')
    gen_parser.add_argument('--qwen-model-target',
                            help='Local path or Hugging Face ID for Qwen3-TTS')
    gen_parser.add_argument('--qwen-speaker-id', default='ryan',
                            help='Qwen3-TTS CustomVoice speaker id')
    gen_parser.add_argument('--qwen-language', default='fr',
                            help='Two-letter language code for Qwen3-TTS')
    
    # Normalize command
    norm_parser = subparsers.add_parser('normalize', help='Normalize audio loudness')
    norm_parser.add_argument('--input', required=True, help='Input audio file')
    norm_parser.add_argument('--output', required=True, help='Output audio file')
    
    # Upsample command
    up_parser = subparsers.add_parser('upsample', help='Upsample audio to 48kHz')
    up_parser.add_argument('--input', required=True, help='Input audio file')
    up_parser.add_argument('--output', required=True, help='Output audio file')
    
    args = parser.parse_args()

    try:
        if args.command == 'daemon':
            sys.exit(run_daemon(args.model, args.qwen_model_target))

        if args.command == 'generate':
            wrapper = AudiobookToolWrapper(args.model, model_target=args.qwen_model_target)
            wrapper.generate(
                text=args.text,
                reference_audio=args.reference_audio,
                reference_text=args.reference_text,
                output=args.output,
                temperature=args.temperature,
                max_retries=args.max_retries,
                enable_stt_validation=args.enable_stt_validation,
                top_p=args.top_p,
                top_k=args.top_k,
                seed=args.seed,
                qwen_instruction=args.qwen_instruction,
                qwen_speaker_id=args.qwen_speaker_id,
                qwen_language=args.qwen_language
            )
        elif args.command == 'normalize':
            # normalize n'utilise pas le modèle TTS : on évite de charger 17 Go pour rien
            wrapper = AudiobookToolWrapper('fish-s2', load_model=False)
            wrapper.normalize(args.input, args.output)
        elif args.command == 'upsample':
            # upsample n'utilise pas le modèle TTS : on évite de charger 17 Go pour rien
            wrapper = AudiobookToolWrapper('fish-s2', load_model=False)
            wrapper.upsample(args.input, args.output)

        sys.exit(0)
        
    except Exception as e:
        print(json.dumps({
            "type": "error",
            "message": str(e),
            "traceback": traceback.format_exc()
        }), flush=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
