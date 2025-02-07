# NVM for Fish Shell

A Node.js version manager for the fish shell, featuring:

- Automatic version switching using `.nvmrc` or `.node-version` files
- Local and remote version management
- Shell completions for all commands
- Support for custom mirrors and architectures
- Default version and packages configuration

## Installation

1. Copy the files to your fish configuration directory:
   ```fish
   mkdir -p ~/.config/fish/functions
   mkdir -p ~/.config/fish/completions
   cp functions/nvm.fish ~/.config/fish/functions/
   cp completions/nvm.fish ~/.config/fish/completions/
   ```

2. (Optional) Configure default settings in your `config.fish`:
   ```fish
   set -g nvm_mirror https://nodejs.org/dist # Default mirror
   set -g nvm_default_version lts            # Default version
   set -g nvm_default_packages yarn jest     # Packages to auto-install
   ```

## Usage

```fish
# Install a specific version
nvm install 16.14.0
nvm install lts
nvm install latest

# Use a version
nvm use 16.14.0
nvm use default     # Use default version
nvm use system      # Use system Node.js

# List versions
nvm list            # Show installed versions
nvm list-remote     # Show available versions
nvm list-remote '^v16' # Filter remote versions

# Show current version
nvm current

# Remove a version
nvm uninstall 16.14.0
```

## Auto-switching

The script automatically detects `.nvmrc` or `.node-version` files in your project directory and switches to the specified Node.js version.

## Options

- `-s, --silent`: Suppress standard output
- `-v, --version`: Print nvm version
- `-h, --help`: Print help message

## Environment Variables

- `nvm_arch`: Override architecture (e.g., x64-musl)
- `nvm_mirror`: Use custom mirror for downloading Node.js
- `nvm_default_version`: Set default version for new shells
- `nvm_default_packages`: Specify packages to install with each Node.js version

## Shell Completions

Tab completion is available for all commands and installed versions.

## Requirements

- fish shell ≥ 3.0.0
- curl