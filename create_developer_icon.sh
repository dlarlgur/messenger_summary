#!/bin/bash
# 개발자 아이콘 생성 스크립트 (ImageMagick 사용)
# 512x512 픽셀, 1MB 이하, JPEG 또는 24비트 PNG

# ImageMagick이 설치되어 있는지 확인
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick이 설치되어 있지 않습니다."
    echo "   macOS 설치: brew install imagemagick"
    echo "   또는 Python Pillow 사용: pip install Pillow && python3 create_developer_icon.py"
    exit 1
fi

# assets/images 디렉토리 생성
mkdir -p assets/images

# 소스 아이콘 확인
source_icon="assets/ai_talk.png"

if [ ! -f "$source_icon" ]; then
    echo "⚠️ 소스 아이콘을 찾을 수 없습니다: $source_icon"
    echo "   기본 아이콘을 생성합니다..."
    # 기본 아이콘 생성 (512x512, 배경색 #4A90E2)
    convert -size 512x512 xc:"#4A90E2" \
        -quality 90 \
        assets/images/developer_icon.png
    convert -size 512x512 xc:"#4A90E2" \
        -quality 90 \
        assets/images/developer_icon.jpg
else
    # 기존 아이콘을 512x512로 리사이즈
    # 투명도 제거하고 흰색 배경에 배치
    convert "$source_icon" \
        -resize 512x512 \
        -background white \
        -alpha remove \
        -alpha off \
        -quality 95 \
        assets/images/developer_icon.png
    
    # JPEG 버전 생성 (1MB 이하로 최적화)
    convert "$source_icon" \
        -resize 512x512 \
        -background white \
        -alpha remove \
        -alpha off \
        -quality 85 \
        assets/images/developer_icon.jpg
fi

# 파일 크기 확인
png_size=$(stat -f%z assets/images/developer_icon.png 2>/dev/null || stat -c%s assets/images/developer_icon.png 2>/dev/null)
jpg_size=$(stat -f%z assets/images/developer_icon.jpg 2>/dev/null || stat -c%s assets/images/developer_icon.jpg 2>/dev/null)

png_size_mb=$(echo "scale=2; $png_size / 1024 / 1024" | bc)
jpg_size_mb=$(echo "scale=2; $jpg_size / 1024 / 1024" | bc)

echo "✅ 개발자 아이콘 생성 완료:"
echo "   PNG: assets/images/developer_icon.png (${png_size_mb}MB)"
echo "   JPEG: assets/images/developer_icon.jpg (${jpg_size_mb}MB)"
echo "   크기: 512x512px"
