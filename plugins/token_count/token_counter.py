import sys
import os
import chardet
import tiktoken
from pathlib import Path

def detect_encoding(file_path):
    with open(file_path, 'rb') as file:
        raw_data = file.read()
        result = chardet.detect(raw_data)
        return result['encoding']

def count_tokens(text, model="cl100k_base"):
    try:
        encoding = tiktoken.get_encoding(model)
        token_count = len(encoding.encode(text))
        return token_count
    except Exception as e:
        print(f"Error counting tokens: {str(e)}", file=sys.stderr)
        return None

def process_file(file_path):
    try:
        encoding = detect_encoding(file_path)
        with open(file_path, 'r', encoding=encoding) as file:
            content = file.read()
            
        char_count = len(content)
        word_count = len(content.split())
        token_count = count_tokens(content)
        
        return {
            'encoding': encoding,
            'chars': char_count,
            'words': word_count,
            'tokens': token_count,
            'size': os.path.getsize(file_path)
        }
    except Exception as e:
        print(f"Error processing file: {str(e)}", file=sys.stderr)
        return None

def main():
    if len(sys.argv) < 2:
        print("Usage: python token_counter.py <file_path>", file=sys.stderr)
        sys.exit(1)
        
    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"File not found: {file_path}", file=sys.stderr)
        sys.exit(1)
        
    result = process_file(file_path)
    if result:
        print(f"""{{
            "encoding": "{result['encoding']}",
            "chars": {result['chars']},
            "words": {result['words']},
            "tokens": {result['tokens']},
            "size": {result['size']}
        }}""")
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
