# Scanify

Transform PDF documents to look like scanned documents.

## Installation

### Homebrew (coming soon)

```bash
brew tap Francium-Tech/tap
brew install scanify
```

### From Source

```bash
git clone https://github.com/Francium-Tech/scanify.git
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

# Bent paper effect - like a phone photo of curved paper
scanify --bent document.pdf

# Combine options
scanify --aggressive --bent document.pdf
```

## Options

| Option | Description |
|--------|-------------|
| `--aggressive` | Apply stronger scan effects (more noise, rotation, artifacts) |
| `--bent` | Add paper warp/bend effect (like a phone photo of curved paper) |
| `--version` | Show version |
| `--help` | Show help |

## Effects Applied

| Effect | Description |
|--------|-------------|
| Paper darkening | Whites become slightly gray (scanned paper is never pure white) |
| Edge shadows | Vignette effect from scanner lid |
| Top shadow | Gradient shadow at top edge |
| Uneven lighting | Slightly off-center lighting variation |
| Noise/grain | Paper texture simulation |
| Slight blur | Optical imperfection |
| Random rotation | Paper feed misalignment |
| Saturation reduction | Scanner color limitations |

### Bent Paper Effect (`--bent`)

Simulates a phone photo of curved/bent paper with randomized warp styles:
- Horizontal wave (paper curling top-to-bottom)
- Vertical wave (paper curling left-to-right)
- Corner lift (one corner lifted)

## Requirements

- macOS 12.0 or later

## License

MIT License - see [LICENSE](LICENSE)
