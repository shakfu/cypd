# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-01-19

### Added

- Initial public release
- Full libpd API wrapper via Cython
- Built-in audio backend using miniaudio
- Thread-safe audio processing with `nogil` handling
- Messaging support: bang, float, symbol, list, and typed messages
- Callback system for receiving messages from Pure Data
- MIDI support: noteon, controlchange, programchange, pitchbend, aftertouch
- Array access and manipulation
- Patch management (open, close, search paths)
- Convenience `audio.play()` function for quick patch playback
- Modern build system using scikit-build-core and CMake
- GitHub Actions workflow for building wheels with cibuildwheel (Linux and macOS)

### Supported Platforms

- macOS (x86_64 and arm64)
- Linux (x86_64 and aarch64)
- Python 3.9, 3.10, 3.11, 3.12, 3.13, 3.14
