#!/usr/bin/env python3
"""
헤더 이미지 생성 스크립트
4096px x 2304px 크기의 헤더 이미지를 생성합니다.
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_header_image():
    # 이미지 크기
    width = 4096
    height = 2304
    
    # 새 이미지 생성 (배경색: #4A90E2 - 앱 테마 색상)
    bg_color = (74, 144, 226)  # #4A90E2
    image = Image.new('RGB', (width, height), bg_color)
    draw = ImageDraw.Draw(image)
    
    # 그라데이션 효과 추가 (선택사항)
    for y in range(height):
        # 상단에서 하단으로 약간 어두워지는 그라데이션
        ratio = y / height
        r = int(bg_color[0] * (1 - ratio * 0.1))
        g = int(bg_color[1] * (1 - ratio * 0.1))
        b = int(bg_color[2] * (1 - ratio * 0.1))
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    # 중앙에 로고나 텍스트 추가 (선택사항)
    # 실제 로고 이미지가 있다면 여기에 추가할 수 있습니다
    
    # assets/images 디렉토리 확인 및 생성
    output_dir = 'assets/images'
    os.makedirs(output_dir, exist_ok=True)
    
    # 이미지 저장
    output_path = os.path.join(output_dir, 'header.png')
    image.save(output_path, 'PNG', quality=95)
    print(f'✅ 헤더 이미지 생성 완료: {output_path}')
    print(f'   크기: {width}px x {height}px')
    
    return output_path

if __name__ == '__main__':
    try:
        create_header_image()
    except ImportError:
        print('❌ PIL(Pillow) 라이브러리가 필요합니다.')
        print('   설치 방법: pip install Pillow')
    except Exception as e:
        print(f'❌ 오류 발생: {e}')
