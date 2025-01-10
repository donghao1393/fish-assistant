import whisper
import datetime
import os
import argparse
import warnings
import torch
import time
import sys

# 过滤特定的警告
warnings.filterwarnings("ignore", category=UserWarning)
warnings.filterwarnings("ignore", category=FutureWarning)

def format_timestamp(seconds):
    """将秒数转换为 SRT 时间戳格式 (00:00:00,000)"""
    hours = int(seconds // 3600)
    minutes = int((seconds % 3600) // 60)
    seconds = seconds % 60
    milliseconds = int((seconds % 1) * 1000)
    seconds = int(seconds)
    return f"{hours:02d}:{minutes:02d}:{seconds:02d},{milliseconds:03d}"

def save_as_srt(result, output_path):
    """将转录结果保存为 SRT 格式"""
    with open(output_path, 'w', encoding='utf-8') as f:
        for i, segment in enumerate(result["segments"], 1):
            start = format_timestamp(segment["start"])
            end = format_timestamp(segment["end"])
            f.write(f"{i}\n")
            f.write(f"{start} --> {end}\n")
            f.write(f"{segment['text'].strip()}\n\n")

def save_as_txt(result, output_path, audio_path, model_name, device):
    """将转录结果保存为带时间戳的文本格式"""
    with open(output_path, "w", encoding='utf-8') as f:
        # 写入基本信息
        f.write(f"转录时间: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"源文件: {audio_path}\n")
        f.write(f"使用模型: {model_name}\n")
        f.write(f"运行设备: {device}\n")
        if result.get("language"):
            f.write(f"检测语言: {result['language']}\n")
        f.write("\n=== 转录内容 ===\n\n")
        
        # 写入转录内容
        if "segments" in result:
            for segment in result["segments"]:
                time_start = format_timestamp(segment["start"])
                time_end = format_timestamp(segment["end"])
                f.write(f"[{time_start} --> {time_end}] {segment['text'].strip()}\n")

def transcribe_audio(audio_path, model_name="base", device="cpu", output_format="txt", language=None, verbose=False):
    """
    转录音频文件并保存为指定格式
    """
    if not os.path.exists(audio_path):
        raise FileNotFoundError(f"找不到音频文件: {audio_path}")
    
    print(f"[1/3] 使用设备: {device}")
    
    try:
        start_time = time.time()
        print(f"[2/3] 加载模型: {model_name}")
        model = whisper.load_model(model_name, device=device)
        
        print(f"[3/3] 开始转录音频: {os.path.basename(audio_path)}")
        if verbose:
            print("转录中，将实时显示结果...")
        else:
            print("转录中，请稍候...")
        
        # 设置 verbose 参数以获取实时输出
        transcribe_options = {
            "verbose": verbose,  # 这将启用 Whisper 的原生进度输出
            "fp16": False       # 禁用FP16以避免警告
        }
        if language:
            transcribe_options["language"] = language
            print(f"指定语言: {language}")
        
        result = model.transcribe(audio_path, **transcribe_options)
        
        # 生成输出文件名
        timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
        audio_filename = os.path.splitext(os.path.basename(audio_path))[0]
        extension = ".srt" if output_format.lower() == "srt" else ".txt"
        output_filename = f"transcript_{audio_filename}_{timestamp}{extension}"
        
        # 保存转录结果
        if output_format.lower() == "srt":
            save_as_srt(result, output_filename)
        else:
            save_as_txt(result, output_filename, audio_path, model_name, device)
        
        end_time = time.time()
        elapsed = end_time - start_time
        elapsed_str = str(datetime.timedelta(seconds=int(elapsed)))
        
        print(f"\n转录完成！耗时: {elapsed_str}")
        print(f"结果已保存至: {output_filename}")
        return output_filename
        
    except Exception as e:
        print(f"转录过程中出现错误: {e}")
        raise

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='使用Whisper转录音频文件')
    parser.add_argument('audio_file', help='要转录的音频文件路径')
    parser.add_argument('--model', default='base', 
                      choices=['tiny', 'base', 'small', 'medium', 'large'],
                      help='使用的Whisper模型 (默认: base)')
    parser.add_argument('--device', 
                      choices=['cpu', 'cuda'],
                      default='cpu',
                      help='运行设备 (默认: cpu)')
    parser.add_argument('--format',
                      choices=['txt', 'srt'],
                      default='txt',
                      help='输出文件格式 (默认: txt)')
    parser.add_argument('--language',
                      help='音频语言 (例如: "zh" 表示中文，默认自动检测)')
    parser.add_argument('-v', '--verbose',
                      action='store_true',
                      help='显示详细输出，包括实时转录结果')
    
    args = parser.parse_args()
    
    try:
        transcribe_audio(
            args.audio_file,
            args.model,
            args.device,
            args.format,
            args.language,
            args.verbose
        )
    except FileNotFoundError as e:
        print(f"错误: {e}")
    except Exception as e:
        print(f"转录过程中出现错误: {e}")
