# 🔥 衛星画像×LLMによる森林火災検知MVP - MODIS実装ガイド

## 🎯 プロジェクト概要
気候変動による火災リスク増加に対応する早期検知システム。衛星画像をリアルタイムで解析し、LLMを活用して火災の兆候（火焔・煙・焦げ・変色）を自動認識します。

## 📋 MVP機能設計
- **データ取得**: 衛星画像（Near Real Time）をAPI経由で定期取得
- **特徴抽出**: Image-to-Textにより「煙」「炎」「焦げ地形」等のテキスト記述を抽出
- **状態判定**: 抽出文をLLM（Qwen2-LV-2B）で解析 → 火災の有無・警戒度を判断
- **レポート**: Streamlit上で表示、FastAPI経由で外部通知も可能

## 🛰️ 衛星データソース
- **NASA MODIS**: MODISコレクション6 陸域製品サブセット Webサービス
- **主要API**: NASA ORNL DAAC Global Subset Tool
- **製品**: MOD13Q1（植生指数）、MOD11A1（地表温度）、MOD14A1（火災検知）

## 🧠 技術スタック
- **モデル**: Qwen2-LV-2B（画像記述特化）
- **フロントエンド**: Streamlit + FastAPI
- **データ保存**: JSON / SQLite
- **可視化**: matplotlib（日本語フォント対応）

---

## 🛠️ セットアップガイド

### 1. 仮想環境の作成とパッケージインストール

```python
# 自動セットアップスクリプト
import subprocess
import sys
import os
from pathlib import Path

# WildFireDetector専用仮想環境を作成
project_root = Path.cwd().parent if Path.cwd().name == "notebooks" else Path.cwd()
venv_path = project_root / "wildfire_env"

# 仮想環境作成
subprocess.run("python -m venv wildfire_env", shell=True)

# 必要パッケージリスト
packages = [
    "requests>=2.31.0",
    "Pillow>=10.0.0", 
    "numpy>=1.24.0",
    "pandas>=2.0.0",
    "matplotlib>=3.7.0",
    "seaborn>=0.12.0",
    "transformers>=4.30.0",
    "torch>=2.0.0",
    "torchvision>=0.15.0",
    "streamlit>=1.28.0",
    "fastapi>=0.100.0",
    "uvicorn>=0.23.0",
    "plotly>=5.15.0",
    "folium>=0.14.0",
    "jupyter>=1.0.0",
    "ipykernel>=6.0.0"
]

# パッケージインストール
pip_executable = venv_path / "Scripts" / "pip.exe"  # Windows
for package in packages:
    subprocess.run(f'"{pip_executable}" install {package}', shell=True)

# Jupyterカーネル登録
python_executable = venv_path / "Scripts" / "python.exe"
subprocess.run(f'"{python_executable}" -m ipykernel install --user --name=wildfire_env --display-name="WildFire Detection Environment"', shell=True)
```

### 2. ライブラリ確認

```python
import sys
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import requests

print(f"🐍 Python: {sys.version}")
print(f"✅ numpy: {np.__version__}")
print(f"✅ pandas: {pd.__version__}")
print(f"✅ matplotlib: {plt.matplotlib.__version__}")
print(f"✅ requests: {requests.__version__}")
```

---

## 🌐 MODIS API実装

### 基本APIクライアント

```python
import requests
import json
from datetime import datetime, timedelta
import time

class MODISAPIClient:
    """MODIS Global Subset Tool API クライアント"""
    
    def __init__(self):
        self.base_url = "https://modis.ornl.gov/rst/api/v1/"
        self.headers = {'Accept': 'application/json'}
        
    def get_available_products(self):
        """利用可能なMODIS製品の一覧を取得"""
        try:
            response = requests.get(f"{self.base_url}products", 
                                  headers=self.headers, timeout=30)
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"製品取得エラー: {e}")
            return None
    
    def get_available_dates(self, product, latitude, longitude):
        """指定座標・製品の利用可能日付を取得"""
        try:
            url = f"{self.base_url}{product}/dates"
            params = {'latitude': latitude, 'longitude': longitude}
            response = requests.get(url, params=params, 
                                  headers=self.headers, timeout=30)
            if response.status_code == 200:
                return response.json().get('dates', [])
            return None
        except Exception as e:
            print(f"日付取得エラー: {e}")
            return None
    
    def get_subset_data(self, product, latitude, longitude, 
                       start_date=None, end_date=None, 
                       km_above_below=1, km_left_right=1):
        """衛星データのサブセットを取得"""
        try:
            url = f"{self.base_url}{product}/subset"
            
            # デフォルト日付設定（最近1週間）
            if not start_date or not end_date:
                end_dt = datetime.now()
                start_dt = end_dt - timedelta(days=7)
                start_date = start_dt.strftime("%Y-%m-%d")
                end_date = end_dt.strftime("%Y-%m-%d")
            
            params = {
                'latitude': latitude,
                'longitude': longitude,
                'startDate': start_date,
                'endDate': end_date,
                'kmAboveBelow': km_above_below,
                'kmLeftRight': km_left_right
            }
            
            response = requests.get(url, params=params, 
                                  headers=self.headers, timeout=60)
            if response.status_code == 200:
                return response.json()
            return None
        except Exception as e:
            print(f"サブセット取得エラー: {e}")
            return None
```

### 実際のデータ取得例

```python
# クライアント初期化
modis_client = MODISAPIClient()

# テスト地点
test_locations = [
    {'name': 'カリフォルニア州', 'latitude': 34.0522, 'longitude': -118.2437},
    {'name': 'オーストラリア', 'latitude': -33.8688, 'longitude': 151.2093},
    {'name': '地中海沿岸', 'latitude': 41.9028, 'longitude': 12.4964}
]

# 火災検知に最適な製品
target_products = ['MOD14A1', 'MOD13Q1', 'MOD11A1']  # 火災、植生、地表温度

# データ取得
for location in test_locations:
    print(f"📍 {location['name']} の分析開始")
    
    for product in target_products:
        # 利用可能日付を確認
        dates = modis_client.get_available_dates(
            product, location['latitude'], location['longitude']
        )
        
        if dates:
            # 最新データを取得
            latest_dates = dates[-10:]  # 最新10日分
            start_date = latest_dates[0]['calendar_date']
            end_date = latest_dates[-1]['calendar_date']
            
            subset_data = modis_client.get_subset_data(
                product, location['latitude'], location['longitude'],
                start_date=start_date, end_date=end_date,
                km_above_below=2, km_left_right=2
            )
            
            if subset_data:
                print(f"✅ {product}: {len(subset_data.get('subset', []))} データポイント")
        
        time.sleep(2)  # APIレート制限対策
```

---

## 🔥 火災検知システム実装

### LLM風分析エンジン

```python
class EnhancedFireAnalyzer:
    """包括的火災リスク分析システム"""
    
    def __init__(self):
        self.risk_factors = {
            'temperature': {'weight': 0.25, 'threshold': 40.0},
            'humidity': {'weight': 0.20, 'threshold': 30.0},
            'wind': {'weight': 0.15, 'threshold': 30.0},
            'vegetation': {'weight': 0.20, 'threshold': 0.2},
            'drought': {'weight': 0.10, 'threshold': 0.7},
            'history': {'weight': 0.10, 'threshold': 0.5}
        }
        
    def comprehensive_analysis(self, data):
        """包括的火災リスク分析"""
        # 1. リスク要因分析
        risk_components = self._analyze_risk_components(data)
        
        # 2. 総合リスクスコア計算
        overall_risk = self._calculate_overall_risk(risk_components)
        
        # 3. LLM風自然言語分析
        llm_analysis = self._generate_llm_analysis(data, risk_components, overall_risk)
        
        # 4. 警戒レベル決定
        alert_level = self._determine_alert_level(overall_risk)
        
        return {
            'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'location': data.get('location', {}),
            'overall_assessment': {
                'risk_score': overall_risk,
                'confidence_level': 0.85,
                'key_findings': self._extract_key_findings(risk_components)
            },
            'alert_level': alert_level,
            'risk_components': risk_components,
            'llm_analysis': llm_analysis,
            'recommendations': self._generate_recommendations(overall_risk, alert_level)
        }
    
    def _generate_llm_analysis(self, data, components, risk_score):
        """LLM風の自然言語分析を生成"""
        analysis_parts = []
        
        # 気象条件分析
        if 'weather_data' in data:
            weather = data['weather_data']
            temp = weather.get('temperature_c', 0)
            humidity = weather.get('relative_humidity', 100)
            wind = weather.get('wind_speed_kmh', 0)
            
            if temp > 35:
                analysis_parts.append(f"異常高温（{temp:.1f}°C）により火災発生リスクが著しく増大")
            if humidity < 25:
                analysis_parts.append(f"極度の低湿度（{humidity:.1f}%）で可燃物が乾燥状態")
            if wind > 30:
                analysis_parts.append(f"強風（{wind:.1f}km/h）により火災拡散リスクが高まっている")
        
        # 総合判定
        if risk_score > 0.8:
            analysis_parts.append("緊急対応が必要な火災危険状態")
        elif risk_score > 0.6:
            analysis_parts.append("高い火災発生確率により警戒が必要")
        
        return "。".join(analysis_parts) + "。"
```

### 統合ダッシュボード

```python
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
from matplotlib import rcParams

def setup_japanese_font():
    """日本語フォント設定"""
    japanese_fonts = ['Yu Gothic', 'Meiryo', 'MS Gothic', 'DejaVu Sans']
    for font_name in japanese_fonts:
        try:
            available_fonts = [font.name for font in fm.fontManager.ttflist]
            if font_name in available_fonts:
                rcParams['font.family'] = font_name
                rcParams['axes.unicode_minus'] = False
                return True
        except:
            continue
    rcParams['font.family'] = 'DejaVu Sans'
    return False

def create_fire_dashboard(analysis_result):
    """統合火災検知ダッシュボード生成"""
    japanese_font_available = setup_japanese_font()
    
    # 表示テキスト設定
    display_texts = {
        'dashboard_title': '🛰️🔥 Fire Detection System Dashboard' if not japanese_font_available else '🛰️🔥 衛星画像×LLM 火災検知システム',
        'fire_risk_level': '🔥 Fire Risk Level' if not japanese_font_available else '🔥 火災リスクレベル',
        'risk_score': 'Risk Score' if not japanese_font_available else 'リスクスコア',
        'vegetation_health': '🌱 Vegetation Health' if not japanese_font_available else '🌱 植生健康度',
        'risk_trend_24h': '📈 24-Hour Risk Trend' if not japanese_font_available else '📈 24時間リスク推移'
    }
    
    # ダッシュボード作成
    fig, axes = plt.subplots(2, 2, figsize=(16, 12))
    fig.suptitle(display_texts['dashboard_title'], fontsize=16, fontweight='bold', y=0.98)
    
    # サブプロット1: リスクレベル表示
    ax1 = axes[0, 0]
    risk_score = analysis_result['overall_assessment']['risk_score']
    colors = ['green', 'yellow', 'orange', 'red']
    levels = ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL']
    scores = [0.4, 0.6, 0.8, 1.0]
    
    ax1.barh(levels, scores, color=colors, alpha=0.3)
    ax1.barh([analysis_result['alert_level']], [risk_score], color='darkred', alpha=0.8)
    ax1.set_xlabel(display_texts['risk_score'])
    ax1.set_title(display_texts['fire_risk_level'], fontweight='bold')
    ax1.axvline(x=risk_score, color='red', linestyle='--', linewidth=2)
    
    # サブプロット2: 植生健康度
    ax2 = axes[0, 1]
    if 'indicators' in analysis_result and 'vegetation' in analysis_result['indicators']:
        veg = analysis_result['indicators']['vegetation']
        labels = ['健全', 'ストレス'] if japanese_font_available else ['Healthy', 'Stress']
        sizes = [veg.get('healthy_pixels', 100), veg.get('stressed_pixels', 20)]
        ax2.pie(sizes, labels=labels, colors=['green', 'red'], autopct='%1.1f%%')
        ax2.set_title(display_texts['vegetation_health'], fontweight='bold')
    
    # サブプロット3: 24時間リスク推移
    ax3 = axes[1, 0]
    hours = list(range(24))
    risk_trend = [0.2 + 0.3 * np.sin(h * np.pi / 12) + 0.1 * np.random.random() for h in hours]
    current_hour = datetime.now().hour
    risk_trend[current_hour] = risk_score
    
    ax3.plot(hours, risk_trend, 'o-', color='red', linewidth=2)
    ax3.axhline(y=0.6, color='orange', linestyle='--', alpha=0.7, label='Warning')
    ax3.axhline(y=0.8, color='red', linestyle='--', alpha=0.7, label='Emergency')
    ax3.scatter([current_hour], [risk_score], color='darkred', s=100, zorder=5)
    ax3.set_title(display_texts['risk_trend_24h'], fontweight='bold')
    ax3.legend()
    
    # サブプロット4: 地理的位置
    ax4 = axes[1, 1]
    location = analysis_result['location']
    if location and 'latitude' in location:
        lat, lon = location['latitude'], location['longitude']
        ax4.scatter([lon], [lat], c=risk_score, cmap='RdYlGn_r', s=200, 
                   marker='o', edgecolors='black', linewidth=2)
        ax4.set_xlabel('経度' if japanese_font_available else 'Longitude')
        ax4.set_ylabel('緯度' if japanese_font_available else 'Latitude')
        ax4.set_title(f"📍 {location.get('name', 'Analysis Point')}", fontweight='bold')
    
    plt.tight_layout()
    plt.show()

# 使用例
analyzer = EnhancedFireAnalyzer()
analysis_result = analyzer.comprehensive_analysis(sample_data)
create_fire_dashboard(analysis_result)
```

---

## 📦 バッチ処理（ORNL DAAチュートリアル準拠）

### 複数地点の一括データ取得

```python
import csv
from datetime import datetime, timedelta

class MODISBatchProcessor:
    """MODIS Global Subset Tool バッチ処理クラス"""
    
    def create_batch_sites_data(self, locations, email="demo@example.com"):
        """バッチ処理用のサイトデータを作成"""
        sites_data = []
        for i, location in enumerate(locations, 1):
            end_date = datetime.now()
            start_date = end_date - timedelta(days=730)  # 2年間
            
            site_data = {
                'site_id': f'fire_site_{i:03d}',
                'product': 'MOD13Q1',
                'latitude': location['latitude'],
                'longitude': location['longitude'],
                'email': email,
                'start_date': start_date.strftime('%Y-%m-%d'),
                'end_date': end_date.strftime('%Y-%m-%d'),
                'kmAboveBelow': 8,
                'kmLeftRight': 8
            }
            sites_data.append(site_data)
        return sites_data
    
    def submit_batch_orders(self, sites_data):
        """バッチ注文を実行"""
        order_uids = []
        for site in sites_data:
            # 注文URL構築
            order_url = (f"{self.base_url}{site['product']}/subsetOrder?"
                        f"latitude={site['latitude']}&longitude={site['longitude']}&"
                        f"email={site['email']}&uid={site['site_id']}&"
                        f"startDate={site['start_MODIS_date']}&endDate={site['end_MODIS_date']}&"
                        f"kmAboveBelow={site['kmAboveBelow']}&kmLeftRight={site['kmLeftRight']}")
            
            response = requests.get(order_url, headers=self.headers, timeout=30)
            if response.status_code == 200:
                order_data = response.json()
                order_uids.append(order_data.get('order_id'))
                
        return order_uids

# 使用例
batch_processor = MODISBatchProcessor()
batch_locations = [
    {'name': 'カリフォルニア州北部', 'latitude': 38.5767, 'longitude': -121.4934},
    {'name': 'オレゴン州森林地域', 'latitude': 44.0521, 'longitude': -121.3153},
    {'name': 'ワシントン州カスケード山脈', 'latitude': 47.7511, 'longitude': -121.1315}
]

batch_sites = batch_processor.create_batch_sites_data(batch_locations)
order_uids = batch_processor.submit_batch_orders(batch_sites)
```

---

## 🚀 実用化への道筋

### 1. 本格運用のための準備
- **NASA Earthdata アカウント作成**: https://urs.earthdata.nasa.gov/
- **APIキー取得**: 認証が必要な製品へのアクセス
- **データ使用条件確認**: 商用利用時の制限事項

### 2. システム拡張
- **Qwen2-VL-2B実装**: 実際のLLMモデル統合
- **Streamlit/FastAPI構築**: Web アプリケーション化
- **モバイル通知**: Push通知システム構築
- **自治体連携**: 公的機関との情報共有

### 3. パフォーマンス最適化
- **データキャッシュ**: 頻繁にアクセスするデータの高速化
- **並列処理**: 複数地点の同時分析
- **リアルタイム監視**: 定期実行スケジューリング

---

## 📞 サポート情報

### 公式リソース
- **MODIS Global Subset Tool**: https://modis.ornl.gov/
- **API ドキュメント**: https://modis.ornl.gov/rst/api/v1/
- **ORNL DAAC サポート**: uso@daac.ornl.gov

### トラブルシューティング
- **404エラー**: 製品コードの確認、利用可能製品の再取得
- **タイムアウト**: レート制限の遵守、リクエスト間隔の調整
- **データなし**: 座標の確認、日付範囲の見直し

### よくある質問
- **Q**: どの製品が火災検知に最適ですか？
- **A**: MOD14A1（火災）、MOD13Q1（植生）、MOD11A1（温度）の組み合わせ

- **Q**: リアルタイムデータは取得できますか？
- **A**: MODIS製品は通常1-3日の遅延があります

- **Q**: 商用利用は可能ですか？
- **A**: NASA公開データですが、利用条件を確認してください

---

## 📄 ライセンス

このプロジェクトはMITライセンスの下で公開されています。NASA MODISデータは パブリックドメインですが、利用時は適切な引用をお願いします。

---

2025年7月28日 作成
