#!/usr/bin/env python3
import os
import time
import json
import argparse
import requests
from typing import Dict, Optional, Union
from fractions import Fraction
class FluxImageGenerator:
    """用于生成 Flux AI 图像的类"""
    BASE_URL = 'https://api.bfl.ml/v1'
    SUPPORTED_MODELS = {
        'flux-pro-1.1': {'width', 'height'},
        'flux-pro-1.1-ultra': {'aspect_ratio'}
    }
    # 尺寸限制
    MIN_DIMENSION = 256
    MAX_DIMENSION = 1440
    DIMENSION_STEP = 32
    # 宽高比限制
    MIN_ASPECT_RATIO = Fraction(9, 21)  # 9:21
    MAX_ASPECT_RATIO = Fraction(21, 9)  # 21:9
    def __init__(self, api_key: Optional[str] = None):
        """
        初始化生成器
        api_key: API密钥，如果未提供则从环境变量BFL_API_KEY中获取
        """
        self.api_key = api_key or os.environ.get("BFL_API_KEY")
        if not self.api_key:
            raise ValueError("API key must be provided either directly or via BFL_API_KEY environment variable")
    def _get_headers(self) -> Dict[str, str]:
        """获取API请求头"""
        return {
            'accept': 'application/json',
            'x-key': self.api_key,
            'Content-Type': 'application/json',
        }
    def _validate_dimension(self, value: int, name: str) -> None:
        """验证尺寸是否符合要求"""
        if value is None:
            return
        if not isinstance(value, int):
            raise ValueError(f"{name} must be an integer")
        if value < self.MIN_DIMENSION or value > self.MAX_DIMENSION:
            raise ValueError(
                f"{name} must be between {self.MIN_DIMENSION} and {self.MAX_DIMENSION}"
            )
        if value % self.DIMENSION_STEP != 0:
            raise ValueError(
                f"{name} must be a multiple of {self.DIMENSION_STEP}"
            )
    def _validate_aspect_ratio(self, aspect_ratio: str) -> None:
        """验证宽高比是否符合要求"""
        if aspect_ratio is None:
            return
        try:
            # 解析宽高比字符串（例如 "16:9"）
            width, height = map(int, aspect_ratio.split(':'))
            ratio = Fraction(width, height)
            if ratio < self.MIN_ASPECT_RATIO or ratio > self.MAX_ASPECT_RATIO:
                min_ratio_str = f"{self.MIN_ASPECT_RATIO.numerator}:{self.MIN_ASPECT_RATIO.denominator}"
                max_ratio_str = f"{self.MAX_ASPECT_RATIO.numerator}:{self.MAX_ASPECT_RATIO.denominator}"
                raise ValueError(
                    f"Aspect ratio must be between {min_ratio_str} and {max_ratio_str}"
                )
        except (ValueError, ZeroDivisionError) as e:
            if "must be between" not in str(e):
                raise ValueError("Invalid aspect ratio format. Must be in format 'width:height'") from e
            raise
    def _validate_model_params(self, model: str, params: Dict) -> None:
        """验证模型参数的正确性"""
        if model not in self.SUPPORTED_MODELS:
            raise ValueError(f"Unsupported model: {model}. Supported models are: {list(self.SUPPORTED_MODELS.keys())}")
        allowed_params = self.SUPPORTED_MODELS[model]
        invalid_params = set(params.keys()) & {'width', 'height', 'aspect_ratio'} - allowed_params
        if invalid_params:
            raise ValueError(f"Invalid parameters {invalid_params} for model {model}. Allowed parameters are: {allowed_params}")
        # 验证具体参数值
        if model == 'flux-pro-1.1':
            self._validate_dimension(params.get('width'), 'Width')
            self._validate_dimension(params.get('height'), 'Height')
        elif model == 'flux-pro-1.1-ultra':
            self._validate_aspect_ratio(params.get('aspect_ratio'))
    def generate(self,
                prompt: str,
                model: str = 'flux-pro-1.1',
                seed: Optional[int] = None,
                width: Optional[int] = None,
                height: Optional[int] = None,
                aspect_ratio: Optional[str] = None) -> Dict:
        """
        生成图像
        prompt: 图像生成提示词
        model: 使用的模型名称
        seed: 随机种子
        width: 图像宽度 (仅flux-pro-1.1)
        height: 图像高度 (仅flux-pro-1.1)
        aspect_ratio: 宽高比 (仅flux-pro-1.1-ultra)
        """
        params = {}
        if width is not None:
            params['width'] = width
        if height is not None:
            params['height'] = height
        if aspect_ratio is not None:
            params['aspect_ratio'] = aspect_ratio
        self._validate_model_params(model, params)
        request_data = {
            'prompt': prompt,
            'raw': True
        }
        if seed is not None:
            request_data['seed'] = seed
        request_data.update(params)
        response = requests.post(
            f'{self.BASE_URL}/{model}',
            headers=self._get_headers(),
            json=request_data
        )
        response.raise_for_status()
        return response.json()
    def get_result(self, request_id: str) -> Dict:
        """获取生成结果"""
        response = requests.get(
            f'{self.BASE_URL}/get_result',
            headers=self._get_headers(),
            params={'id': request_id}
        )
        response.raise_for_status()
        return response.json()
    def wait_for_result(self, request_id: str, interval: float = 0.5) -> Dict:
        """等待并获取生成结果"""
        while True:
            result = self.get_result(request_id)
            if result["status"] == "Ready":
                return result
            print(f"Status: {result['status']}")
            time.sleep(interval)
def read_prompt_file(file_path: str) -> str:
    """从文件中读取提示词"""
    with open(file_path, 'r', encoding='utf-8') as f:
        return f.read().strip()
def validate_dimension_arg(value: Optional[str]) -> Optional[int]:
    """验证并转换命令行传入的尺寸参数"""
    if value is None:
        return None
    try:
        return int(value)
    except ValueError:
        raise argparse.ArgumentTypeError(f"'{value}' is not a valid integer")
def main():
    parser = argparse.ArgumentParser(
        description='Generate images using Flux AI models',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
尺寸和宽高比限制:
  - width 和 height (flux-pro-1.1):
    - 必须在 256-1440 之间
    - 必须是 32 的倍数
  - aspect_ratio (flux-pro-1.1-ultra):
    - 必须在 9:21 到 21:9 之间
    - 格式必须为 width:height，例如 16:9
示例:
  %(prog)s --prompt "风景画" --model flux-pro-1.1 --width 1024 --height 768
  %(prog)s --prompt "城市夜景" --model flux-pro-1.1-ultra --aspect-ratio 16:9
        """
    )
    parser.add_argument('--prompt', type=str, help='Text prompt for image generation')
    parser.add_argument('--prompt-file', type=str, help='File containing the prompt')
    parser.add_argument('--model', type=str, choices=['flux-pro-1.1', 'flux-pro-1.1-ultra'],
                      default='flux-pro-1.1', help='Model to use for generation')
    parser.add_argument('--seed', type=int, help='Random seed for generation')
    parser.add_argument('--width', type=validate_dimension_arg,
                      help='Image width (flux-pro-1.1 only, 256-1440, multiple of 32)')
    parser.add_argument('--height', type=validate_dimension_arg,
                      help='Image height (flux-pro-1.1 only, 256-1440, multiple of 32)')
    parser.add_argument('--aspect-ratio', type=str,
                      help='Image aspect ratio (flux-pro-1.1-ultra only, between 9:21 and 21:9)')
    parser.add_argument('--api-key', type=str, help='BFL API key (optional, can use BFL_API_KEY env var)')
    args = parser.parse_args()
    if not args.prompt and not args.prompt_file:
        parser.error("Either --prompt or --prompt-file must be provided")
    if args.prompt and args.prompt_file:
        parser.error("Cannot use both --prompt and --prompt-file")
    prompt = args.prompt if args.prompt else read_prompt_file(args.prompt_file)
    try:
        generator = FluxImageGenerator(api_key=args.api_key)
        # 生成图像
        request = generator.generate(
            prompt=prompt,
            model=args.model,
            seed=args.seed,
            width=args.width,
            height=args.height,
            aspect_ratio=args.aspect_ratio
        )
        print(f"Generation requested, ID: {request['id']}")
        # 等待结果
        result = generator.wait_for_result(request['id'])
        print(f"Generation complete!")
        print(f"Result: {json.dumps(result['result'], indent=2)}")
    except Exception as e:
        print(f"Error: {str(e)}")
        return 1
    return 0
if __name__ == '__main__':
    exit(main())