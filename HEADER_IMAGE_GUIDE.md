# 이미지 생성 가이드

## 헤더 이미지 (4096px x 2304px)

4096px x 2304px 크기의 헤더 이미지를 생성하는 방법입니다.

## 방법 1: Python 스크립트 사용 (권장)

1. Pillow 설치:
```bash
pip install Pillow
```

2. 스크립트 실행:
```bash
python3 create_header_image.py
```

이미지가 `assets/images/header.png`에 생성됩니다.

## 방법 2: ImageMagick 사용

1. ImageMagick 설치:
```bash
brew install imagemagick
```

2. 스크립트 실행:
```bash
./create_header_image.sh
```

## 방법 3: 온라인 도구 사용

1. [Canva](https://www.canva.com/) 또는 [Figma](https://www.figma.com/) 같은 디자인 도구 사용
2. 새 디자인 생성: 4096px x 2304px
3. 배경색: #4A90E2 (앱 테마 색상)
4. 로고나 원하는 디자인 추가
5. PNG로 내보내기
6. `assets/images/header.png`로 저장

## 방법 4: 기존 이미지 리사이즈

기존 이미지가 있다면:

```bash
# ImageMagick 사용
convert input_image.png -resize 4096x2304! assets/images/header.png

# 또는 sips (macOS 기본 제공)
sips -z 2304 4096 input_image.png --out assets/images/header.png
```

## 이미지 사용

생성된 이미지는 `assets/images/header.png`에 저장되며, `pubspec.yaml`의 assets 설정에 이미 포함되어 있습니다.

---

## 개발자 아이콘 (512x512px, 1MB 이하)

512x512 픽셀, 1MB 이하, JPEG 또는 24비트 PNG (투명하지 않음) 형식의 개발자 아이콘을 생성하는 방법입니다.

### 방법 1: Python 스크립트 사용 (권장)

1. Pillow 설치:
```bash
pip install Pillow
```

2. 스크립트 실행:
```bash
python3 create_developer_icon.py
```

이미지가 `assets/images/developer_icon.png`와 `assets/images/developer_icon.jpg`에 생성됩니다.

### 방법 2: ImageMagick 사용

1. ImageMagick 설치:
```bash
brew install imagemagick
```

2. 스크립트 실행:
```bash
./create_developer_icon.sh
```

### 방법 3: 온라인 도구 사용

1. [Canva](https://www.canva.com/) 또는 [Figma](https://www.figma.com/) 같은 디자인 도구 사용
2. 새 디자인 생성: **512px x 512px**
3. 배경색: **#4A90E2** (앱 테마 색상) 또는 흰색
4. 로고나 원하는 디자인 추가
5. **JPEG 또는 PNG (24비트, 투명도 없음)**로 내보내기
6. 파일 크기가 1MB 이하인지 확인
7. `assets/images/developer_icon.png` 또는 `.jpg`로 저장

### 방법 4: 기존 아이콘 리사이즈

기존 아이콘이 있다면:

```bash
# ImageMagick 사용
convert assets/ai_talk.png -resize 512x512 -background white -alpha remove assets/images/developer_icon.png

# 또는 sips (macOS 기본 제공)
sips -z 512 512 assets/ai_talk.png --out assets/images/developer_icon.png
```

### 요구사항 확인

- ✅ 크기: 512x512 픽셀
- ✅ 형식: JPEG 또는 24비트 PNG (투명하지 않음)
- ✅ 파일 크기: 1MB 이하

생성된 이미지는 `assets/images/` 디렉토리에 저장되며, `pubspec.yaml`의 assets 설정에 이미 포함되어 있습니다.
