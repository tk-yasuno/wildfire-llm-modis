# 🔥 WildFireDetector 環境セットアップガイド

## 🎯 概要

衛星画像×LLM森林火災検知プロジェクト専用の仮想環境セットアップ手順です。

## 📋 前提条件

- Python 3.8以上がインストールされていること
- pipが利用可能であること
- インターネット接続が利用可能であること

## 🚀 セットアップ手順

### 1. プロジェクトディレクトリへ移動

```powershell
cd "c:\Users\yasun\PyTorch\WildFireDetector"
```

### 2. 仮想環境の作成

```powershell
python -m venv wildfire_env
```

### 3. 仮想環境のアクティベーション

```powershell
# Windows PowerShell
.\wildfire_env\Scripts\Activate.ps1

# Windows コマンドプロンプト
wildfire_env\Scripts\activate.bat
```

### 4. pipのアップグレード

```powershell
python -m pip install --upgrade pip
```

### 5. 必要パッケージのインストール

```powershell
pip install -r requirements.txt
```

### 6. Jupyterカーネルとして登録

```powershell
python -m ipykernel install --user --name=wildfire_env --display-name="WildFire Detection Environment"
```

## 🔧 VS Codeでの使用方法

### 1. カーネルの選択

1. ノートブックを開く
2. 右上の「カーネルを選択」をクリック
3. "WildFire Detection Environment" を選択

### 2. Python インタープリターの選択

1. `Ctrl+Shift+P` でコマンドパレットを開く
2. "Python: Select Interpreter" を入力
3. `wildfire_env\Scripts\python.exe` を選択

## 📦 インストールパッケージ一覧

### 基本ライブラリ

- `requests` - HTTP通信
- `numpy` - 数値計算
- `pandas` - データ処理
- `matplotlib` - グラフ描画
- `seaborn` - 統計的可視化
- `Pillow` - 画像処理

### AI/MLライブラリ

- `torch` - PyTorch深層学習フレームワーク
- `torchvision` - 画像処理用ツール
- `transformers` - HuggingFace トランスフォーマー

### 衛星データAPI

- `earthengine-api` - Google Earth Engine
- `sentinelhub` - Sentinel Hub

### Webフレームワーク

- `streamlit` - データアプリケーション
- `fastapi` - 高速APIフレームワーク
- `uvicorn` - ASGIサーバー

### 可視化・地図

- `plotly` - インタラクティブグラフ
- `folium` - 地図可視化

### Jupyter環境

- `jupyter` - Jupyterノートブック
- `ipykernel` - Jupyterカーネル

## 🔍 トラブルシューティング

### パッケージインストールエラー

```powershell
# pip キャッシュをクリア
pip cache purge

# パッケージを個別にインストール
pip install numpy pandas matplotlib
```

### カーネルが見つからない場合

```powershell
# カーネルリストを確認
jupyter kernelspec list

# カーネルを再登録
python -m ipykernel install --user --name=wildfire_env --display-name="WildFire Detection Environment" --force
```

### 権限エラーの場合

```powershell
# 管理者として実行するか、ユーザー領域にインストール
pip install --user package_name
```

## 📊 環境確認コマンド

```powershell
# Python版本確認
python --version

# インストール済みパッケージ確認
pip list

# 特定パッケージの確認
pip show numpy matplotlib torch
```

## 🎯 次のステップ

1. ノートブック `satellite_detection_test.ipynb` を開く
2. カーネルを "WildFire Detection Environment" に変更
3. 最初のセルからセルを順番に実行
4. 環境確認セルで全てのライブラリが正常にインポートされることを確認

## 🆘 サポート

環境セットアップで問題が発生した場合は、以下を確認してください：

1. Python版本が3.8以上であること
2. 十分なディスク容量があること（最低2GB）
3. インターネット接続が安定していること
4. ウイルス対策ソフトがPythonの実行を阻害していないこと
