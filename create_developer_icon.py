#!/usr/bin/env python3
"""
개발자 아이콘 생성 스크립트
512x512 픽셀, 1MB 이하, JPEG 또는 24비트 PNG (투명하지 않음)
"""

from PIL import Image
import os

def create_developer_icon():
    # 기존 아이콘 경로 확인
    source_icon = 'assets/ai_talk.png'
    
    if not os.path.exists(source_icon):
        print(f'❌ 소스 아이콘을 찾을 수 없습니다: {source_icon}')
        print('   기본 아이콘을 생성합니다...')
        # 기본 아이콘 생성
        create_default_icon()
        return
    
    try:
        # 기존 아이콘 열기
        img = Image.open(source_icon)
        
        # RGBA 모드면 RGB로 변환 (투명도 제거)
        if img.mode == 'RGBA':
            # 흰색 배경에 합성
            background = Image.new('RGB', img.size, (255, 255, 255))
            background.paste(img, mask=img.split()[3])  # 알파 채널을 마스크로 사용
            img = background
        elif img.mode != 'RGB':
            img = img.convert('RGB')
        
        # 512x512로 리사이즈 (비율 유지하면서 중앙 정렬)
        target_size = (512, 512)
        
        # 비율 유지하면서 리사이즈
        img.thumbnail(target_size, Image.Resampling.LANCZOS)
        
        # 정사각형 캔버스 생성 (흰색 배경)
        new_img = Image.new('RGB', target_size, (255, 255, 255))
        
        # 중앙에 배치
        paste_x = (target_size[0] - img.size[0]) // 2
        paste_y = (target_size[1] - img.size[1]) // 2
        new_img.paste(img, (paste_x, paste_y))
        
        # assets/images 디렉토리 확인 및 생성
        output_dir = 'assets/images'
        os.makedirs(output_dir, exist_ok=True)
        
        # PNG로 저장 (압축 최적화)
        output_path_png = os.path.join(output_dir, 'developer_icon.png')
        new_img.save(output_path_png, 'PNG', optimize=True, quality=95)
        
        # 파일 크기 확인
        file_size_png = os.path.getsize(output_path_png)
        file_size_mb_png = file_size_png / (1024 * 1024)
        
        print(f'✅ PNG 아이콘 생성 완료: {output_path_png}')
        print(f'   크기: 512x512px')
        print(f'   파일 크기: {file_size_mb_png:.2f}MB')
        
        # 1MB 초과하면 JPEG로도 생성
        if file_size_mb_png > 1.0:
            print('   ⚠️ PNG 파일이 1MB를 초과합니다. JPEG 버전을 생성합니다...')
            output_path_jpg = os.path.join(output_dir, 'developer_icon.jpg')
            # JPEG 품질 조정하여 1MB 이하로 만들기
            quality = 85
            while quality > 50:
                new_img.save(output_path_jpg, 'JPEG', quality=quality, optimize=True)
                file_size_jpg = os.path.getsize(output_path_jpg)
                file_size_mb_jpg = file_size_jpg / (1024 * 1024)
                if file_size_mb_jpg <= 1.0:
                    print(f'✅ JPEG 아이콘 생성 완료: {output_path_jpg}')
                    print(f'   크기: 512x512px')
                    print(f'   파일 크기: {file_size_mb_jpg:.2f}MB (품질: {quality})')
                    break
                quality -= 5
        else:
            # PNG가 1MB 이하면 JPEG도 생성 (선택사항)
            output_path_jpg = os.path.join(output_dir, 'developer_icon.jpg')
            new_img.save(output_path_jpg, 'JPEG', quality=90, optimize=True)
            file_size_jpg = os.path.getsize(output_path_jpg)
            file_size_mb_jpg = file_size_jpg / (1024 * 1024)
            print(f'✅ JPEG 아이콘 생성 완료: {output_path_jpg}')
            print(f'   크기: 512x512px')
            print(f'   파일 크기: {file_size_mb_jpg:.2f}MB')
        
    except Exception as e:
        print(f'❌ 오류 발생: {e}')
        print('   기본 아이콘을 생성합니다...')
        create_default_icon()

def create_default_icon():
    """기본 개발자 아이콘 생성"""
    # 512x512 크기
    size = (512, 512)
    
    # 배경색: #4A90E2 (앱 테마 색상)
    bg_color = (74, 144, 226)
    
    # 새 이미지 생성
    img = Image.new('RGB', size, bg_color)
    
    # assets/images 디렉토리 확인 및 생성
    output_dir = 'assets/images'
    os.makedirs(output_dir, exist_ok=True)
    
    # PNG로 저장
    output_path_png = os.path.join(output_dir, 'developer_icon.png')
    img.save(output_path_png, 'PNG', optimize=True)
    
    # JPEG로 저장
    output_path_jpg = os.path.join(output_dir, 'developer_icon.jpg')
    img.save(output_path_jpg, 'JPEG', quality=90, optimize=True)
    
    file_size_png = os.path.getsize(output_path_png) / (1024 * 1024)
    file_size_jpg = os.path.getsize(output_path_jpg) / (1024 * 1024)
    
    print(f'✅ 기본 아이콘 생성 완료:')
    print(f'   PNG: {output_path_png} ({file_size_png:.2f}MB)')
    print(f'   JPEG: {output_path_jpg} ({file_size_jpg:.2f}MB)')
    print(f'   크기: 512x512px')

if __name__ == '__main__':
    try:
        create_developer_icon()
    except ImportError:
        print('❌ PIL(Pillow) 라이브러리가 필요합니다.')
        print('   설치 방법: pip install Pillow')
    except Exception as e:
        print(f'❌ 오류 발생: {e}')
