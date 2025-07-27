@echo off
echo =====================================================
echo 🔥 WildFireDetector 仮想環境セットアップスクリプト
echo =====================================================

:: 現在のディレクトリを確認
echo 📁 現在のディレクトリ: %CD%

:: 仮想環境が既に存在するかチェック
if exist "wildfire_env\" (
    echo ✅ 仮想環境は既に存在します
    goto :activate_env
)

:: 仮想環境を作成
echo 🔄 仮想環境を作成中...
python -m venv wildfire_env
if %ERRORLEVEL% neq 0 (
    echo ❌ 仮想環境の作成に失敗しました
    pause
    exit /b 1
)
echo ✅ 仮想環境の作成完了

:activate_env
:: 仮想環境をアクティベート
echo 🔄 仮想環境をアクティベート中...
call wildfire_env\Scripts\activate.bat

:: pipをアップグレード
echo 🔄 pipをアップグレード中...
python -m pip install --upgrade pip

:: 必要なパッケージをインストール
echo 📦 必要パッケージをインストール中...
pip install requests>=2.31.0
pip install Pillow>=10.0.0
pip install numpy>=1.24.0
pip install pandas>=2.0.0
pip install matplotlib>=3.7.0
pip install seaborn>=0.12.0
pip install transformers>=4.30.0
pip install torch>=2.0.0
pip install torchvision>=0.15.0
pip install streamlit>=1.28.0
pip install fastapi>=0.100.0
pip install uvicorn>=0.23.0
pip install plotly>=5.15.0
pip install folium>=0.14.0
pip install jupyter>=1.0.0
pip install ipykernel>=6.0.0

:: Jupyterカーネルとして登録
echo 🔄 Jupyterカーネルを登録中...
python -m ipykernel install --user --name=wildfire_env --display-name="WildFire Detection Environment"

echo.
echo =====================================================
echo 🎉 セットアップ完了！
echo =====================================================
echo.
echo 📋 次の手順:
echo 1. VS CodeまたはJupyterでノートブックを開く
echo 2. カーネルを "WildFire Detection Environment" に変更
echo 3. ノートブックのセルを実行開始
echo.
echo 💡 仮想環境の手動アクティベート:
echo    wildfire_env\Scripts\activate.bat
echo.
echo 🚀 Streamlitアプリの起動:
echo    streamlit run src\ui\fire_detection_dashboard.py
echo.

pause
