import sys
import os
import magic
import chardet
import tiktoken
import pdfplumber
import json  # 添加json模块导入
from pathlib import Path

def get_file_type(file_path):
    mime = magic.Magic(mime=True)
    return mime.from_file(file_path)

def extract_pdf_text(file_path):
    try:
        with pdfplumber.open(file_path) as pdf:
            text = ""
            for page in pdf.pages:
                extracted = page.extract_text()
                if extracted:
                    text += extracted
            if not text:
                print(f"Warning: No text extracted from PDF: {file_path}", file=sys.stderr)
                return ""
            return text
    except Exception as e:
        print(f"Error extracting PDF text: {str(e)}", file=sys.stderr)
        return None

def detect_encoding(file_path):
    try:
        with open(file_path, 'rb') as file:
            # 只读取前几KB数据来加快检测
            raw_data = file.read(4096 * 4)  # 16KB should be enough for encoding detection
            if not raw_data:  # 文件为空
                return 'utf-8'  # 默认使用UTF-8
            result = chardet.detect(raw_data)
            encoding = result['encoding']
            if encoding is None:
                print(f"Warning: Could not detect encoding for {file_path}, using utf-8", file=sys.stderr)
                return 'utf-8'
            return encoding
    except Exception as e:
        print(f"Error detecting encoding: {str(e)}", file=sys.stderr)
        return 'utf-8'  # 出错时默认使用UTF-8

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
        file_type = get_file_type(file_path)
        file_size = os.path.getsize(file_path)
        content = None
        encoding = None

        # 检查文件类型是否支持
        supported_types = [
            "text/", "application/json", "application/x-script", "application/xml", 
            "application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument"
        ]
        
        is_supported = False
        for t in supported_types:
            if t in file_type:
                is_supported = True
                break
                
        if not is_supported:
            print(f"Error: Unsupported file type: {file_type}", file=sys.stderr)
            return None

        if file_type == "application/pdf":
            content = extract_pdf_text(file_path)
            encoding = "pdf"
        else:
            try:
                encoding = detect_encoding(file_path)
                with open(file_path, 'r', encoding=encoding) as file:
                    content = file.read()
            except UnicodeDecodeError as e:
                print(f"Error: Unable to decode file with detected encoding ({encoding}): {str(e)}", file=sys.stderr)
                # 尝试使用常见编码
                for fallback_encoding in ['utf-8', 'latin1', 'cp1252', 'ascii']:
                    try:
                        with open(file_path, 'r', encoding=fallback_encoding) as file:
                            content = file.read()
                            encoding = fallback_encoding
                            print(f"Successfully read file using fallback encoding: {fallback_encoding}", file=sys.stderr)
                            break
                    except UnicodeDecodeError:
                        continue

        if content is None:
            print(f"Error: Unable to extract content from file", file=sys.stderr)
            return None

        char_count = len(content)
        word_count = len(content.split())
        token_count = count_tokens(content)
        
        if token_count is None:
            token_count = 0

        return {
            'type': file_type,
            'encoding': encoding,
            'chars': char_count,
            'words': word_count,
            'tokens': token_count,
            'size': file_size
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
    
    if not os.path.isfile(file_path):
        print(f"Not a file: {file_path}", file=sys.stderr)
        sys.exit(1)
        
    result = process_file(file_path)
    
    if result:
        # 使用json模块输出简洁的单行JSON
        print(json.dumps(result))
    else:
        sys.exit(1)

if __name__ == "__main__":
    main()
