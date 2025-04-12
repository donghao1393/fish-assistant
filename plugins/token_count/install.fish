#!/usr/bin/env fish

echo installing
uv venv -p 3.12
uv pip install -r requirements.txt
brew install libmagic
echo installed
echo testing
uv run token_counter.py README.md
echo "test finished"
