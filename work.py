#!/usr/bin/env python3
"""
🤖 Roblox Farm v16.2 (FILE LICENSE INJECT)
✅ ВСЕГДА перезаписывает /storage/emulated/0/Delta/Autoexecute/1.lua при запуске
✅ Прямой запрос к ZEN-API
✅ 24-часовой таймер байпаса
✅ Записывает ключ напрямую в файл license (без ввода через экран)
✅ 3 тапа по рекламе для получения ссылки
"""
import requests, time, subprocess, os, json, sys, re, urllib.parse
from datetime import datetime

# ==========================================
# ⚙️ НАСТРОЙКИ
# ==========================================

ZEN_API_KEY = "e1209faf-f7a0-4b3c-9eb1-dab8b5155869"
ZEN_API_URL = "https://api.izen.lol/v1/bypass"

DELTA_AUTOEXEC_PATH = "/storage/emulated/0/Delta/Autoexecute/1.lua"
DELTA_LICENSE_PATH = "/storage/emulated/0/Delta/Internals/Cache/license"
DELTA_LUA_CONTENT = "loadstring(game:HttpGet('https://raw.githubusercontent.com/staffere228-alt/vanna/refs/heads/main/farm.lua'))()"

FARM_CYCLE_SECONDS = 14400

AD_BTN_X, AD_BTN_Y = 1000, 470

FORCE_BYPASS = False
DEBUG_MODE = True
BYPASS_COOLDOWN = 86400
MAX_RETRIES = 3
PACKAGE_MAIN = "com.roblox.client"
PLACE_ID = "142823291"
STATE_FILE = "farm_state.json"

state = {"last_key_time": 0.0}

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)

def run_su(cmd, timeout=15):
    try:
        res = subprocess.run(["su", "-c", cmd], capture_output=True, text=True, timeout=timeout)
        return res.returncode == 0, res.stdout.strip(), res.stderr.strip()
    except Exception as e:
        return False, "", str(e)

def tap(x, y):
    run_su(f"input tap {x} {y}", timeout=5)

# 🔥 ИСПРАВЛЕННАЯ ФУНКЦИЯ — ВСЕГДА перезаписывает файл
def create_delta_lua():
    """🔥 ВСЕГДА перезаписывает Delta Lua файл при каждом запуске"""
    log(f"📝 ПЕРЕЗАПИСЫВАЮ Delta Lua: {DELTA_AUTOEXEC_PATH}")
    log(f"   📄 Содержимое: {DELTA_LUA_CONTENT}")
    
    try:
        # Создаём папку, если нет
        folder = os.path.dirname(DELTA_AUTOEXEC_PATH)
        if not os.path.exists(folder):
            run_su(f"mkdir -p '{folder}'", timeout=5)
            log(f"   📁 Создана папка: {folder}")
        
        # ВСЕГДА перезаписываем файл
        with open(DELTA_AUTOEXEC_PATH, 'w') as f:
            f.write(DELTA_LUA_CONTENT)
        
        # Даём права на чтение
        run_su(f"chmod 644 '{DELTA_AUTOEXEC_PATH}'", timeout=3)
        
        # Проверяем что записалось
        try:
            with open(DELTA_AUTOEXEC_PATH, 'r') as f:
                content = f.read().strip()
            if content == DELTA_LUA_CONTENT:
                log("✅ Delta Lua перезаписан УСПЕШНО")
            else:
                log(f"⚠️ Содержимое отличается! Записано: {content[:50]}")
        except Exception as e:
            log(f"⚠️ Не удалось проверить содержимое: {e}")
        
        return True
    except Exception as e:
        log(f"❌ Ошибка перезаписи Lua: {e}")
        
        # Фоллбэк: пробуем через su
        log("🔄 Пробую через su...")
        try:
            escaped_content = DELTA_LUA_CONTENT.replace("'", "'\"'\"'")
            ok, out, err = run_su(f"echo '{escaped_content}' > '{DELTA_AUTOEXEC_PATH}'", timeout=5)
            if ok:
                run_su(f"chmod 644 '{DELTA_AUTOEXEC_PATH}'", timeout=3)
                log("✅ Delta Lua перезаписан через su")
                return True
            else:
                log(f"❌ su тоже не сработал: {err}")
        except Exception as e2:
            log(f"❌ Фоллбэк провалился: {e2}")
        
        return False

def kill_all_roblox():
    log("🛑 Убиваю ВСЕ процессы Roblox...")
    killed = 0
    ok, out, _ = run_su("pm list packages com.roblox", timeout=10)
    if ok:
        pkgs = [line.split(":")[1] for line in out.splitlines() if line.startswith("package:")]
        for pkg in pkgs:
            run_su(f"am force-stop {pkg}", timeout=5)
            killed += 1
    run_su("am force-stop com.android.chrome", timeout=5)
    run_su("am force-stop com.android.browser", timeout=5)
    log(f"   ✅ Остановлено: {killed} пакетов")
    time.sleep(2)

def launch_delta():
    log(f"🔓 Запускаю Дельту...")
    deep_link = f"'roblox://experiences/start?placeId={PLACE_ID}'"
    run_su(f"am start -a android.intent.action.VIEW -d {deep_link} {PACKAGE_MAIN}", timeout=10)

def launch_roblox_light_farm():
    log("🚜 Запускаю ферму...")
    ok, out, _ = run_su("pm list packages com.roblox", timeout=10)
    if not ok: return
    pkgs = [line.split(":")[1] for line in out.splitlines() if line.startswith("package:")]
    launched = 0
    for pkg in pkgs:
        if pkg == PACKAGE_MAIN: continue
        deep_link = f"'roblox://experiences/start?placeId={PLACE_ID}'"
        run_su(f"am start -a android.intent.action.VIEW -d {deep_link} {pkg}", timeout=5)
        launched += 1
        time.sleep(2)
        if launched >= 4: break
    log(f"   ✅ Фермеров запущено: {launched}")

def get_link_from_browser():
    try:
        res = subprocess.run(
            ["/data/data/com.termux/files/usr/bin/termux-clipboard-get"],
            capture_output=True, text=True, timeout=3
        )
        if res.returncode == 0 and res.stdout.strip():
            match = re.search(r'(https?://[^\s\"\'<>\}\]\)\;]+)', res.stdout.strip())
            if match: return match.group(0).rstrip('.,;')
    except: pass
    
    ok, out, _ = run_su("/system/bin/dumpsys activity activities", timeout=5)
    if ok and out:
        match = re.search(r'(https?://[^\s\"\'<>\}\]\)\;]+)', out)
        if match: return match.group(0).rstrip('.,;')
    return None

def bypass_with_zen(url):
    if not ZEN_API_KEY or ZEN_API_KEY == "YOUR_API_KEY_HERE":
        log("❌ ZEN_API_KEY не настроен!")
        return None
    
    try:
        clean = url.strip()
        if not clean.startswith(("http://", "https://")):
            log("❌ Invalid URL")
            return None
        encoded = urllib.parse.quote(clean, safe=":/?=&#")
    except Exception as e:
        log(f"❌ URL encode error: {e}")
        return None
    
    endpoint = f"{ZEN_API_URL}?url={encoded}"
    headers = {"x-api-key": ZEN_API_KEY, "User-Agent": "FarmBot/16.2"}
    
    log(f"🔗 Запрос к ZEN-API: {clean[:60]}...")
    
    try:
        resp = requests.get(endpoint, headers=headers, timeout=30)
        log(f"📡 HTTP {resp.status_code}")
        
        if resp.status_code == 200:
            try:
                data = resp.json()
            except json.JSONDecodeError:
                log(f"❌ Invalid JSON: {resp.text[:100]}")
                return None
            
            if data.get("status") == "success" and isinstance(data.get("result"), str):
                key = data["result"].strip()
                if key.startswith("FREE_") or len(key) > 10:
                    log(f"✅ KEY: {key}")
                    return key
                else:
                    log(f"⚠️ Unexpected key format: {key[:20]}")
            else:
                log(f"⚠️ No key in response: {data}")
        elif resp.status_code == 401:
            log("❌ Invalid API key (401)")
        elif resp.status_code == 403:
            log(f"❌ Forbidden (403): {resp.text[:100]}")
        elif resp.status_code == 429:
            log("⏳ Rate limit (429) — жду 60 сек")
            time.sleep(60)
            return bypass_with_zen(url)
        else:
            log(f"❌ HTTP {resp.status_code}: {resp.text[:100]}")
    except requests.Timeout:
        log("⏰ Request timeout")
    except requests.ConnectionError:
        log("🌐 Connection error")
    except Exception as e:
        log(f"💥 Exception: {type(e).__name__}: {e}")
    
    return None

def inject_key(key):
    if not key: 
        log("❌ Ключ пустой")
        return False
    
    log(f"💉 ЗАПИСЬ КЛЮЧА В ФАЙЛ: {DELTA_LICENSE_PATH}")
    log(f"   🔑 Ключ: {key}")
    
    try:
        # Создаём папку, если её нет
        folder = os.path.dirname(DELTA_LICENSE_PATH)
        if not os.path.exists(folder):
            run_su(f"mkdir -p '{folder}'", timeout=5)
            log(f"   📁 Создана папка: {folder}")
        
        # Пробуем записать напрямую через Python
        try:
            with open(DELTA_LICENSE_PATH, 'w') as f:
                f.write(key)
            log("✅ Ключ записан через Python")
        except PermissionError:
            log("⚠️ Нет прав через Python, пишу через su...")
            escaped_key = key.replace("'", "'\"'\"'")
            ok, out, err = run_su(f"echo '{escaped_key}' > '{DELTA_LICENSE_PATH}'", timeout=5)
            if not ok:
                log(f"❌ Ошибка записи через su: {err}")
                return False
            log("✅ Ключ записан через su")
            
        # Выставляем права
        run_su(f"chmod 644 '{DELTA_LICENSE_PATH}'", timeout=3)
        
        # Проверяем, что записалось
        try:
            with open(DELTA_LICENSE_PATH, 'r') as f:
                content = f.read().strip()
            if content == key:
                log("✅ Ключ успешно проверен в файле")
            else:
                log(f"⚠️ Содержимое файла отличается: {content[:20]}...")
        except Exception as e:
            log(f"⚠️ Не удалось проверить файл (возможно, нужен su для чтения): {e}")
            
        return True
        
    except Exception as e:
        log(f"❌ Ошибка записи файла: {e}")
        return False

def load_state():
    global state
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, 'r') as f: 
                loaded = json.load(f)
                state.update(loaded)
        except: state = {"last_key_time": 0.0}

def save_state():
    try:
        with open(STATE_FILE, 'w') as f: 
            json.dump(state, f)
    except: pass

def run_bypass_cycle():
    for attempt in range(1, MAX_RETRIES + 1):
        log(f"🔁 Байпас {attempt}/{MAX_RETRIES}")
        
        # 1. Запускаем Дельту, чтобы появилась реклама
        kill_all_roblox(); launch_delta()
        time.sleep(25)
        
        log("📺 Тап рекламы...")
        tap(AD_BTN_X, AD_BTN_Y); time.sleep(1.5)
        tap(AD_BTN_X, AD_BTN_Y); time.sleep(3)
        
        # 2. Получаем ссылку
        link = get_link_from_browser()
        if not link or not link.startswith("https://"):
            log("⚠️ Ссылка не найдена"); time.sleep(2); continue
        
        # 3. Получаем ключ от API
        key = bypass_with_zen(link)
        if not key: 
            log("❌ Ключ не получен от ZEN-API"); time.sleep(2); continue
        
        # 4. Закрываем Roblox/Дельту, чтобы освободить файл и применить лицензию
        kill_all_roblox()
        time.sleep(2)
        
        # 5. Записываем ключ в файл (без запуска приложения и ввода с экрана)
        if inject_key(key):
            state["last_key_time"] = time.time()
            save_state()
            log("💾 Таймер байпаса обновлён")
            return True
            
    return False

def main():
    global state
    log("🤖 Roblox Farm v16.2 FILE LICENSE INJECT START")
    log(f"🔗 ZEN-API: {'✅' if ZEN_API_KEY and ZEN_API_KEY != 'YOUR_API_KEY_HERE' else '❌ Не настроен'}")
    log(f"📁 Delta Lua: {DELTA_AUTOEXEC_PATH}")
    log(f"📁 Delta License: {DELTA_LICENSE_PATH}")
    log(f"⏱️ Фарм: {FARM_CYCLE_SECONDS//60} мин | Байпас: {'каждый цикл' if FORCE_BYPASS else '1 раз в 24ч'}")
    
    # 🔥 1. ВСЕГДА перезаписываем Lua-файл при запуске
    log("\n" + "="*50)
    log("🔥 ШАГ 1: ПЕРЕЗАПИСЬ DELTA LUA")
    log("="*50)
    if create_delta_lua():
        log("✅ Lua файл готов к использованию\n")
    else:
        log("⚠️ Lua файл не удалось перезаписать, но продолжаем\n")
    
    # 2. Загружаем состояние
    load_state()
    
    # ♾️ БЕСКОНЕЧНЫЙ ЦИКЛ
    while True:
        now = time.time()
        elapsed = now - state["last_key_time"]
        
        if not FORCE_BYPASS and state["last_key_time"] > 0 and elapsed < BYPASS_COOLDOWN:
            log(f"⏱️ Кулдаун: {elapsed/3600:.1f}ч / 24ч → ПРОПУСК байпаса")
        else:
            log("🔓 Кулдаун истёк → запускаю байпас")
            if not run_bypass_cycle():
                log("💥 Байпас провален, но продолжаю фарм")
        
        kill_all_roblox()
        launch_roblox_light_farm()
        log(f"💤 Фарм {FARM_CYCLE_SECONDS//60} мин...")
        time.sleep(FARM_CYCLE_SECONDS)

if __name__ == "__main__":
    try: 
        main()
    except KeyboardInterrupt: 
        log("🛑 Остановлено пользователем")
    except Exception as e: 
        log(f"💥 Crash: {e}")
        import traceback; traceback.print_exc()
        time.sleep(60)
