@echo off
rem ═══════════════════════════════════════════════════════════════
rem  FABRICA VIVA — MODO REAL COMPLETO, TODO EN UNO
rem  1. Enciende el puente local (tu SaaS Factory con Claude Code)
rem  2. Abre la interfaz (detecta el puente automaticamente)
rem  Doble clic y listo. Deja abierta la ventana del puente.
rem ═══════════════════════════════════════════════════════════════

start "Puente Fabrica Viva" powershell -ExecutionPolicy Bypass -File "C:\Users\ingen\Desktop\fabrica-viva-n8n\puente-fabrica.ps1"

timeout /t 2 /nobreak >nul

start "" "C:\Users\ingen\Desktop\fabrica-viva-n8n\fabrica-viva.html"
