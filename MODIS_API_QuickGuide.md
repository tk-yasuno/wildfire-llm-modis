# 📖 MODIS API QuickGuide

## 🌍 概要
NASA ORNL DAAC（Oak Ridge National Laboratory Distributed Active Archive Center）が提供するMODIS Global Subset Tool APIを使用して、衛星データを取得し火災検知に活用するためのガイドです。

---

## 🔗 基本情報

### API エンドポイント
```
Base URL: https://modis.ornl.gov/rst/api/v1/
```

### 認証
- **不要**: パブリックAPIのため認証なしで利用可能
- **レート制限**: 連続リクエスト時は1-2秒の間隔を推奨

### レスポンス形式
- **JSON**: `{'Accept': 'application/json'}`
- **CSV**: `{'Accept': 'text/csv'}`

---

## 🛰️ 主要なMODIS製品（火災検知関連）

| 製品コード | 名称 | 解像度 | 更新頻度 | 用途 |
|-----------|------|--------|----------|------|
| **MOD14A1** | 熱異常・火災検知 | 1km | 日次 | 🔥 アクティブファイア検知 |
| **MOD13Q1** | 植生指数 | 250m | 16日 | 🌱 植生健康度・NDVI |
| **MOD11A1** | 地表温度 | 1km | 日次 | 🌡️ 地表温度監視 |
| **MOD09A1** | 地表反射率 | 500m | 8日 | 🌍 地表状態分析 |

---

## 🔧 API エンドポイント一覧

### 1. 製品一覧取得
```http
GET /api/v1/products
```
**用途**: 利用可能なすべてのMODIS製品を取得

**レスポンス例**:
```json
[
  {
    "product": "MOD14A1",
    "description": "MODIS/Terra Thermal Anomalies/Fire Daily L3 Global 1km SIN Grid V061",
    "frequency": "daily",
    "resolution_meters": 1000
  }
]
```

### 2. 利用可能日付取得
```http
GET /api/v1/{product}/dates?latitude={lat}&longitude={lon}
```
**パラメータ**:
- `product`: MODIS製品コード（例: MOD14A1）
- `latitude`: 緯度（-90 ~ 90）
- `longitude`: 経度（-180 ~ 180）

**レスポンス例**:
```json
{
  "dates": [
    {
      "calendar_date": "2024-07-27",
      "modis_date": "A2024209"
    }
  ]
}
```

### 3. データサブセット取得
```http
GET /api/v1/{product}/subset?latitude={lat}&longitude={lon}&startDate={start}&endDate={end}&kmAboveBelow={km}&kmLeftRight={km}
```
**パラメータ**:
- `latitude`, `longitude`: 中心座標
- `startDate`, `endDate`: 日付範囲（YYYY-MM-DD）
- `kmAboveBelow`: 上下方向の範囲（km）
- `kmLeftRight`: 左右方向の範囲（km）

### 4. バッチ注文（大量データ）
```http
GET /api/v1/{product}/subsetOrder?latitude={lat}&longitude={lon}&email={email}&uid={uid}&startDate={modis_start}&endDate={modis_end}&kmAboveBelow={km}&kmLeftRight={km}
```
**注意**: 大量データの場合は注文システムを使用。処理完了後にメール通知。

---

## 💻 実装例

### 基本的なデータ取得
```python
import requests
import json

# 1. APIクライアント設定
base_url = "https://modis.ornl.gov/rst/api/v1/"
headers = {'Accept': 'application/json'}

# 2. 製品一覧取得
response = requests.get(f"{base_url}products", headers=headers)
products = response.json()

# 3. 特定地点の日付取得
lat, lon = 34.0522, -118.2437  # ロサンゼルス
dates_url = f"{base_url}MOD14A1/dates"
params = {'latitude': lat, 'longitude': lon}
dates_response = requests.get(dates_url, params=params, headers=headers)
available_dates = dates_response.json()['dates']

# 4. データサブセット取得
subset_url = f"{base_url}MOD14A1/subset"
subset_params = {
    'latitude': lat,
    'longitude': lon,
    'startDate': '2024-07-20',
    'endDate': '2024-07-27',
    'kmAboveBelow': 5,
    'kmLeftRight': 5
}
subset_response = requests.get(subset_url, params=subset_params, headers=headers)
data = subset_response.json()
```

### エラーハンドリング
```python
def safe_api_request(url, params=None, timeout=30):
    try:
        response = requests.get(url, params=params, headers=headers, timeout=timeout)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"API Error: {response.status_code}")
            return None
    except Exception as e:
        print(f"Request failed: {e}")
        return None
```

---

## 📊 データ解析のポイント

### MOD14A1（火災検知）データの読み方
```python
def analyze_fire_data(subset_data):
    fire_pixels = 0
    high_confidence_fires = 0
    
    for data_point in subset_data['subset']:
        band = data_point['band']
        values = data_point['data']
        
        if 'Fire' in band:
            # 火災ピクセル数をカウント
            fire_pixels += sum(1 for v in values if v > 0)
            
        elif 'FireMask' in band:
            # 高信頼度火災を特定
            high_confidence_fires += sum(1 for v in values if v >= 7)
    
    return fire_pixels, high_confidence_fires
```

### MOD13Q1（植生指数）の正規化
```python
def calculate_ndvi(subset_data):
    for data_point in subset_data['subset']:
        if 'NDVI' in data_point['band']:
            # MODISのNDVIはスケール係数0.0001で保存
            ndvi_values = [v * 0.0001 for v in data_point['data'] if v != -3000]
            return ndvi_values
    return []
```

---

## ⚠️ 注意事項とベストプラクティス

### レート制限対策
```python
import time

# リクエスト間に1-2秒の間隔
for location in locations:
    response = requests.get(url, params=params)
    time.sleep(2)  # レート制限対策
```

### データ品質チェック
- **NoData値**: -3000, -1000などは無効データ
- **雲の影響**: QA（品質保証）バンドを確認
- **センサー異常**: 異常に高い・低い値をフィルタリング

### 大量データ処理
- **バッチ注文**: 2年以上のデータや複数地点は注文システム使用
- **処理時間**: 通常30分、大量注文は数時間
- **メール通知**: 処理完了後に指定アドレスに通知

---

## 🔥 火災検知への応用

### 1. リアルタイム監視
```python
# 毎日実行する火災監視スクリプト
def daily_fire_check(locations):
    alerts = []
    for loc in locations:
        # 最新のMOD14A1データを取得
        fire_data = get_latest_fire_data(loc['lat'], loc['lon'])
        if detect_fire_anomaly(fire_data):
            alerts.append(create_alert(loc, fire_data))
    return alerts
```

### 2. 複合指標による評価
```python
def comprehensive_fire_risk(lat, lon):
    # 火災 + 植生 + 温度データを統合
    fire_data = get_modis_data('MOD14A1', lat, lon)
    vegetation_data = get_modis_data('MOD13Q1', lat, lon)
    temperature_data = get_modis_data('MOD11A1', lat, lon)
    
    risk_score = calculate_composite_risk(fire_data, vegetation_data, temperature_data)
    return risk_score
```

---

## 🛠️ クラス設計例

### MODISAPIClient クラス
```python
class MODISAPIClient:
    def __init__(self):
        self.base_url = "https://modis.ornl.gov/rst/api/v1/"
        self.headers = {'Accept': 'application/json'}
        
    def get_products(self):
        """利用可能な製品一覧を取得"""
        return self._safe_request(f"{self.base_url}products")
        
    def get_dates(self, product, lat, lon):
        """指定座標・製品の利用可能日付を取得"""
        url = f"{self.base_url}{product}/dates"
        params = {'latitude': lat, 'longitude': lon}
        return self._safe_request(url, params)
        
    def get_subset(self, product, lat, lon, start_date, end_date, km_range=5):
        """データサブセットを取得"""
        url = f"{self.base_url}{product}/subset"
        params = {
            'latitude': lat, 'longitude': lon,
            'startDate': start_date, 'endDate': end_date,
            'kmAboveBelow': km_range, 'kmLeftRight': km_range
        }
        return self._safe_request(url, params)
        
    def _safe_request(self, url, params=None):
        """安全なAPIリクエスト"""
        try:
            response = requests.get(url, params=params, headers=self.headers, timeout=30)
            return response.json() if response.status_code == 200 else None
        except Exception as e:
            print(f"API Error: {e}")
            return None
```

---

## 📈 パフォーマンス最適化

### 1. 並列処理
```python
import concurrent.futures
import threading

def parallel_data_fetch(locations, product):
    results = {}
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        future_to_location = {
            executor.submit(fetch_modis_data, loc, product): loc 
            for loc in locations
        }
        
        for future in concurrent.futures.as_completed(future_to_location):
            location = future_to_location[future]
            try:
                data = future.result()
                results[location['name']] = data
            except Exception as e:
                print(f"Error for {location['name']}: {e}")
    
    return results
```

### 2. キャッシュ機能
```python
import pickle
from datetime import datetime, timedelta

class MODISDataCache:
    def __init__(self, cache_duration_hours=6):
        self.cache_duration = timedelta(hours=cache_duration_hours)
        self.cache = {}
        
    def get_cached_data(self, cache_key):
        if cache_key in self.cache:
            data, timestamp = self.cache[cache_key]
            if datetime.now() - timestamp < self.cache_duration:
                return data
        return None
        
    def cache_data(self, cache_key, data):
        self.cache[cache_key] = (data, datetime.now())
```

---

## 🔍 トラブルシューティング

### よくあるエラーとその対処法

#### 1. HTTP 400 Bad Request
```python
# 原因: パラメータが不正
# 対処: 緯度経度の範囲確認（緯度: -90~90, 経度: -180~180）
if not (-90 <= latitude <= 90):
    raise ValueError("緯度は-90から90の範囲で指定してください")
if not (-180 <= longitude <= 180):
    raise ValueError("経度は-180から180の範囲で指定してください")
```

#### 2. HTTP 500 Internal Server Error
```python
# 原因: サーバー側の一時的な問題
# 対処: リトライ機能の実装
import time
import random

def retry_request(func, max_retries=3):
    for attempt in range(max_retries):
        try:
            result = func()
            if result is not None:
                return result
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            wait_time = 2 ** attempt + random.uniform(0, 1)
            time.sleep(wait_time)
    return None
```

#### 3. データが空の場合
```python
def validate_modis_data(data):
    if not data or 'subset' not in data:
        return False, "データが取得できませんでした"
    
    if len(data['subset']) == 0:
        return False, "指定期間にデータがありません"
    
    # 有効なデータポイントの確認
    valid_points = 0
    for point in data['subset']:
        if point.get('data') and any(v != -3000 for v in point['data']):
            valid_points += 1
    
    if valid_points == 0:
        return False, "有効なデータポイントがありません"
    
    return True, f"有効なデータポイント: {valid_points}個"
```

---

## 📚 参考リンク

- **公式ドキュメント**: https://modis.ornl.gov/
- **MODIS製品詳細**: https://lpdaac.usgs.gov/products/
- **ORNL DAAC**: https://daac.ornl.gov/
- **チュートリアル**: https://modis.ornl.gov/rst/tutorials/
- **MODIS データ仕様**: https://modis.gsfc.nasa.gov/data/

---

## 🚀 次のステップ

1. **🔧 環境準備**
   ```bash
   pip install requests pandas numpy matplotlib
   ```

2. **🧪 基本テスト**
   - 1地点、1週間のデータで動作確認
   - エラーハンドリングの確認

3. **📈 スケールアップ**
   - バッチ処理で複数地点・長期間データ
   - 並列処理の導入

4. **🤖 LLM統合**
   - 取得データをQwen2-VLで画像解析
   - 自然言語での結果解釈

5. **🔄 運用化**
   - 定期実行スクリプト
   - 警報システムとの連携
   - ダッシュボード作成

---

## 💡 活用アイデア

- **🔥 山火事早期警戒システム**: リアルタイム監視＋自動通報
- **🌾 農業支援**: 植生指数による作物健康度監視  
- **🌡️ 気候変動研究**: 長期間の地表温度変化分析
- **🏞️ 環境保護**: 森林減少・砂漠化のモニタリング

準備完了です！このガイドを参考に、実際のMODIS APIを活用した火災検知システムを構築してください。🛰️🔥
