const axios = require('axios');
const { parseStringPromise } = require('xml2js');

const BASE_URL = 'http://www.opinet.co.kr/api';
const API_KEY = process.env.OPINET_API_KEY;

/**
 * 오피넷 API 공통 호출
 */
async function callOpinet(endpoint, params = {}) {
  try {
    const res = await axios.get(`${BASE_URL}/${endpoint}`, {
      params: { code: API_KEY, out: 'json', ...params },
      timeout: 10000,
    });

    // 오피넷은 때때로 XML 반환 → JSON 파싱 시도
    if (typeof res.data === 'string') {
      try {
        return JSON.parse(res.data);
      } catch {
        const xml = await parseStringPromise(res.data, { explicitArray: false });
        return xml;
      }
    }
    return res.data;
  } catch (err) {
    console.error(`[OPINET] ${endpoint} error:`, err.message);
    throw err;
  }
}

/**
 * 반경 내 주유소 검색
 */
async function getAroundStations({ x, y, radius = 5000, prodcd = 'B027', sort = 1 }) {
  const data = await callOpinet('aroundAll.do', { x, y, radius, prodcd, sort });
  return data?.RESULT?.OIL || [];
}

/**
 * 주유소 상세 정보 (유종별 전체 목록 반환)
 */
async function getStationDetail(uniId) {
  const data = await callOpinet('detailById.do', { id: uniId });
  const oils = data?.RESULT?.OIL;
  if (!oils || oils.length === 0) return null;
  // 첫 번째 항목을 기본 정보로, 나머지 항목에서 유종별 가격 추출
  return { base: oils[0], all: oils };
}

/**
 * 전국 평균 유가
 */
async function getAvgAllPrice() {
  const data = await callOpinet('avgAllPrice.do');
  return data?.RESULT?.OIL || [];
}

/**
 * 지역 최저가 TOP 10
 */
async function getLowTop10({ prodcd = 'B027', area = '' }) {
  const params = { prodcd, cnt: 10 };
  if (area) params.SIDO_CD = area;
  const data = await callOpinet('lowTop10.do', params);
  return data?.RESULT?.OIL || [];
}

module.exports = {
  getAroundStations,
  getStationDetail,
  getAvgAllPrice,
  getLowTop10,
};
