#!/bin/bash
# 헤더 이미지 생성 스크립트 (ImageMagick 사용)
# 4096px x 2304px 크기의 헤더 이미지를 생성합니다.

# ImageMagick이 설치되어 있는지 확인
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick이 설치되어 있지 않습니다."
    echo "   macOS 설치: brew install imagemagick"
    echo "   또는 Python Pillow 사용: pip install Pillow && python3 create_header_image.py"
    exit 1
fi

# assets/images 디렉토리 생성
mkdir -p assets/images

# 헤더 이미지 생성 (배경색: #4A90E2)
convert -size 4096x2304 xc:"#4A90E2" \
    -quality 95 \
    assets/images/header.png

echo "✅ 헤더 이미지 생성 완료: assets/images/header.png"
echo "   크기: 4096px x 2304px"
