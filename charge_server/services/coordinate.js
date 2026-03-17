const proj4 = require('proj4');

// KATEC 좌표계 정의 (오피넷 사용)
proj4.defs('KATEC', '+proj=tmerc +lat_0=38 +lon_0=128 +k=0.9999 +x_0=400000 +y_0=600000 +ellps=bessel +units=m +no_defs +towgs84=-115.80,474.99,674.11,1.16,-2.31,-1.63,6.43');

/**
 * WGS84 (GPS) → KATEC 변환
 * @param {number} lat - 위도 (WGS84)
 * @param {number} lng - 경도 (WGS84)
 * @returns {{ x: number, y: number }} KATEC 좌표
 */
function wgs84ToKatec(lat, lng) {
  const [x, y] = proj4('EPSG:4326', 'KATEC', [lng, lat]);
  return { x, y };
}

/**
 * KATEC → WGS84 (GPS) 변환
 * @param {number} x - KATEC X 좌표
 * @param {number} y - KATEC Y 좌표
 * @returns {{ lat: number, lng: number }} WGS84 좌표
 */
function katecToWgs84(x, y) {
  const [lng, lat] = proj4('KATEC', 'EPSG:4326', [x, y]);
  return { lat, lng };
}

module.exports = { wgs84ToKatec, katecToWgs84 };
