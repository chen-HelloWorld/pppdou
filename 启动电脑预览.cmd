@echo off
cd /d "%~dp0"
set "PREVIEW_URL=http://127.0.0.1:4174/preview/?v=%RANDOM%"
set "COLOR_CARD_URL=http://127.0.0.1:4174/color_card/MRAD_color.json"
start "拼豆预览服务" /min node "%~dp0preview-server.js"
rem 等待服务真正返回页面后再打开浏览器，避免启动瞬间点击识别导致 Failed to fetch。
powershell -NoProfile -ExecutionPolicy Bypass -Command "$url='%PREVIEW_URL%'; $card='%COLOR_CARD_URL%'; for($i=0;$i -lt 30;$i++){try{$r=Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 1;if($r.StatusCode -eq 200){Start-Process $url; Start-Process $card; exit 0}}catch{} Start-Sleep -Milliseconds 300}; Start-Process $url; Start-Process $card"
