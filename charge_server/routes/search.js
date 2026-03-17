const express = require('express');
const router = express.Router();
const axios = require('axios');

/**
 * GET /api/search/places?query=판교역
 * 1순위: Kakao 로컬 검색 (장소명/주소 모두 지원)
 * 2순위: Naver Geocoding 폴백 (주소 정밀 검색)
 */
router.get('/places', async (req, res) => {
  const { query } = req.query;
  if (!query) return res.status(400).json({ error: 'query 필수' });

  const { lat, lng } = req.query;
  console.log(`[Search] ▶ 검색 요청: "${query}" (위치: ${lat && lng ? `${lat}, ${lng}` : '없음'})`);

  // ─── 1순위: Kakao 키워드 검색 ───
  const kakaoKey = process.env.KAKAO_REST_API_KEY;
  console.log(`[Search] KAKAO_REST_API_KEY: ${kakaoKey ? `설정됨 (${kakaoKey.slice(0,6)}...)` : '❌ 없음 → 카카오 스킵'}`);

  if (kakaoKey) {
    try {
      console.log(`[Search] 카카오 키워드 검색 호출 중...`);
      const kakaoParams = { query, size: 5 };
      if (lat && lng) {
        kakaoParams.x = lng;  // 카카오는 경도가 x
        kakaoParams.y = lat;  // 카카오는 위도가 y
        kakaoParams.sort = 'distance';
      }
      const resp = await axios.get('https://dapi.kakao.com/v2/local/search/keyword.json', {
        params: kakaoParams,
        headers: { Authorization: `KakaoAK ${kakaoKey}` },
        timeout: 5000,
      });

      const documents = resp.data?.documents || [];
      console.log(`[Search] 카카오 응답 HTTP ${resp.status}, documents: ${documents.length}건`);

      if (documents.length > 0) {
        const results = documents.map(d => ({
          name: d.place_name,
          address: d.road_address_name || d.address_name || '',
          lat: parseFloat(d.y),
          lng: parseFloat(d.x),
        }));
        console.log(`[Search] ✅ 카카오 결과 반환:`, results.map(r => r.name));
        return res.json({ results });
      } else {
        console.log(`[Search] ⚠️ 카카오 결과 0건 → 네이버 폴백으로`);
      }
    } catch (err) {
      console.error(`[Search] ❌ 카카오 호출 실패: ${err.message}`, {
        status: err.response?.status,
        data: err.response?.data,
      });
    }
  }

  // ─── 2순위: Naver Geocoding 폴백 ───
  const mapId = process.env.NAVER_MAP_CLIENT_ID;
  const mapSecret = process.env.NAVER_MAP_CLIENT_SECRET;
  console.log(`[Search] 네이버 지오코딩 폴백: NAVER_MAP_CLIENT_ID=${mapId ? `설정됨` : '❌ 없음'}`);

  if (!mapId || !mapSecret) return res.status(500).json({ error: 'API 키 미설정' });

  try {
    console.log(`[Search] 네이버 지오코딩 호출 중...`);
    const resp = await axios.get('https://maps.apigw.ntruss.com/map-geocode/v2/geocode', {
      params: { query, count: 5 },
      headers: {
        'X-NCP-APIGW-API-KEY-ID': mapId,
        'X-NCP-APIGW-API-KEY': mapSecret,
        'Accept': 'application/json',
      },
      timeout: 5000,
    });

    const addresses = resp.data?.addresses || [];
    console.log(`[Search] 네이버 응답 HTTP ${resp.status}, addresses: ${addresses.length}건`);

    const results = addresses.map(a => {
      const buildingEl = a.addressElements?.find(e => e.types?.includes('BUILDING_NAME') && e.longName);
      return {
        name: buildingEl?.longName || a.roadAddress || a.jibunAddress || query,
        address: a.roadAddress || a.jibunAddress || '',
        lat: parseFloat(a.y),
        lng: parseFloat(a.x),
      };
    });

    console.log(`[Search] ✅ 네이버 결과 반환:`, results.map(r => r.name));
    res.json({ results });
  } catch (err) {
    console.error(`[Search] ❌ 네이버 지오코딩 실패: ${err.message}`, {
      status: err.response?.status,
      data: err.response?.data,
    });
    res.status(500).json({ error: '검색 실패' });
  }
});

module.exports = router;
