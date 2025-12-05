# Scanify

Transform PDF documents to look like scanned documents.

## Installation

### Homebrew (coming soon)

```bash
brew install scanify
```

### From Source

```bash
git clone https://github.com/yourusername/scanify.git
cd scanify
swift build -c release
cp .build/release/scanify /usr/local/bin/
```

## Usage

```bash
# Basic usage - creates input_scanned.pdf
scanify document.pdf

# Specify output path
scanify document.pdf scanned_output.pdf

# Aggressive mode - more noise, rotation, artifacts
scanify --aggressive document.pdf
```

## Options

| Option | Description |
|--------|-------------|
| `--aggressive` | Apply stronger scan effects (more noise, rotation, artifacts) |
| `--version` | Show version |
| `--help` | Show help |

## Effects Applied

- Slight random rotation (simulates paper feed imperfection)
- Noise/grain overlay (simulates scanner sensor noise)
- Contrast and brightness adjustments
- Subtle blur (simulates optical imperfection)
- Saturation reduction (simulates color scanner limitations)

## Requirements

- macOS 12.0 or later

## License

MIT License - see [LICENSE](LICENSE)
