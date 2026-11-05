#!/usr/bin/env python3
"""golos — сервис озвучки на хосте HA.

POST /say  {"text": "...", "room": "max", "force": false}
    → синтез на ПК (Wyoming Silero, xenia) → WAV раздаётся отсюда же →
      Music Assistant play_announcement прямо на плеер комнаты.
    Если на плеере играла музыка — после фразы та же очередь продолжается
    с прежней громкостью. С 22:00 до 10:00 молчит (force снимает запрет).
GET  /rooms   — какие комнаты есть
GET  /health  — жив ли сервис
GET  /audio/<id>.wav — отдаёт синтезированное (это URL для MA)

Почему прямо на плеер, а не на MA-группу «Гостинная»: объявление на группу
MA принимает и молча не воспроизводит (MA 2.11.0b5, проверено 05.11).
"""
import asyncio
import datetime
import io
import json
import logging
import os
import time
import uuid
import wave

from aiohttp import ClientSession, web

HERE = os.path.dirname(os.path.abspath(__file__))
ADDON_OPTIONS = "/data/options.json"  # в аддоне настройки даёт супервизор


def load_conf():
    if not os.path.exists(ADDON_OPTIONS):
        return json.load(open(os.path.join(HERE, "config.json")))
    o = json.load(open(ADDON_OPTIONS))
    return {
        "port": 8790,
        "public_url": o["public_url"],
        "wyoming": [o["wyoming_host"], o["wyoming_port"]],
        "voice": o["voice"],
        "ma_ws": o["ma_ws"],
        "ma_token": o["ma_token"],
        "quiet": [o["quiet_from"], o["quiet_to"]],
        "rooms": {r["name"]: r["player_id"] for r in o["rooms"]},
    }


CONF = load_conf()
PORT = CONF.get("port", 8790)
PUBLIC = CONF.get("public_url", f"http://192.168.4.220:{PORT}")
WYOMING = CONF.get("wyoming", ["192.168.1.74", 10203])
VOICE = CONF.get("voice", "xenia")
MA_WS = CONF.get("ma_ws", "http://172.30.32.1:8094/ws")
ROOMS = CONF["rooms"]  # имя → player_id MA
QUIET = CONF.get("quiet", [22, 10])
AUDIO_TTL = 600  # сколько секунд держать файлы для MA

log = logging.getLogger("golos")
audio = {}  # id → (время, байты wav)
lock = asyncio.Lock()  # одна фраза за раз, иначе объявления перебивают друг друга


def ma_token():
    if CONF.get("ma_token"):
        return CONF["ma_token"]
    return open(os.path.join(HERE, CONF.get("ma_token_file", "ma_token"))).read().strip()


def quiet_now():
    h = datetime.datetime.now().hour
    return h >= QUIET[0] or h < QUIET[1]


async def synthesize(text):
    """Wyoming synthesize → WAV-байты."""
    r, w = await asyncio.open_connection(*WYOMING)
    data = json.dumps({"text": text, "voice": {"name": VOICE}}).encode()
    w.write(json.dumps({"type": "synthesize", "data_length": len(data)}).encode() + b"\n" + data)
    await w.drain()
    pcm, fmt = bytearray(), None
    try:
        while True:
            line = await asyncio.wait_for(r.readline(), 60)
            if not line:
                break
            ev = json.loads(line)
            ev_data = ev.get("data") or {}
            if ev.get("data_length"):
                ev_data.update(json.loads(await r.readexactly(ev["data_length"])))
            payload = await r.readexactly(ev["payload_length"]) if ev.get("payload_length") else b""
            if ev["type"] == "audio-start":
                fmt = ev_data
            elif ev["type"] == "audio-chunk":
                fmt = fmt or ev_data
                pcm += payload
            elif ev["type"] == "audio-stop":
                break
    finally:
        w.close()
    if not pcm or not fmt:
        raise RuntimeError("Wyoming не вернул звук")
    buf = io.BytesIO()
    with wave.open(buf, "wb") as f:
        f.setnchannels(fmt.get("channels", 1))
        f.setsampwidth(fmt.get("width", 2))
        f.setframerate(fmt.get("rate", 24000))
        f.writeframes(bytes(pcm))
    seconds = len(pcm) / (fmt.get("rate", 24000) * fmt.get("width", 2) * fmt.get("channels", 1))
    return buf.getvalue(), seconds


class MA:
    """Короткая сессия WebSocket к Music Assistant."""

    async def __aenter__(self):
        self.session = ClientSession()
        self.ws = await self.session.ws_connect(MA_WS)
        await self.ws.receive_json()
        self.n = 0
        r = await self.cmd("auth", token=ma_token())
        if r.get("error_code"):
            raise RuntimeError(f"MA не принял токен: {r}")
        return self

    async def __aexit__(self, *exc):
        await self.ws.close()
        await self.session.close()

    async def cmd(self, command, **args):
        self.n += 1
        mid = str(self.n)
        await self.ws.send_json({"message_id": mid, "command": command, "args": args})
        while True:
            m = await asyncio.wait_for(self.ws.receive_json(), 90)
            if m.get("message_id") == mid:
                return m


async def say(text, player):
    wav, seconds = await synthesize(text)
    aid = uuid.uuid4().hex
    audio[aid] = (time.time(), wav)
    url = f"{PUBLIC}/audio/{aid}.wav"
    async with MA() as ma:
        p = (await ma.cmd("players/get", player_id=player)).get("result") or {}
        queue_id = p.get("active_source") or player
        q = (await ma.cmd("player_queues/get", queue_id=queue_id)).get("result") or {}
        music = q.get("state") == "playing"
        volume = p.get("volume_level")
        log.info("say %r → %s (%.1f с), музыка=%s, очередь=%s, громкость=%s",
                 text[:60], player, seconds, music, queue_id, volume)
        # Обработчик объявлений станции Яндекса играет фразу поверх потока и музыку
        # не возвращает; объявление через группу MA звучит беззвучно. Поэтому сами:
        # пауза очереди → фраза прямо на плеер → продолжить очередь (тест 14, 05.11).
        if music:
            await ma.cmd("player_queues/pause", queue_id=queue_id)
            await asyncio.sleep(1.5)
        r = await ma.cmd("players/cmd/play_announcement", player_id=player, url=url,
                         use_pre_announce=False)
        if r.get("error_code"):
            raise RuntimeError(f"MA: {r}")
        if not music:
            return {"ok": True, "seconds": round(seconds, 1), "music": False}
        back, plays = False, 0
        for plays in range(1, 6):
            await ma.cmd("player_queues/play", queue_id=queue_id)
            await asyncio.sleep(3)
            q1 = (await ma.cmd("player_queues/get", queue_id=queue_id)).get("result") or {}
            await asyncio.sleep(2)
            q2 = (await ma.cmd("player_queues/get", queue_id=queue_id)).get("result") or {}
            if q2.get("state") == "playing" and (q2.get("elapsed_time") or 0) > (q1.get("elapsed_time") or 0):
                back = True
                break
        p = (await ma.cmd("players/get", player_id=player)).get("result") or {}
        if volume is not None and p.get("volume_level") != volume:
            await ma.cmd("players/cmd/volume_set", player_id=player, volume_level=volume)
        log.info("музыка вернулась=%s, попыток play=%d", back, plays)
        return {"ok": back, "seconds": round(seconds, 1), "music": True, "resumed": back,
                "plays": plays}


async def announce_bg(player, url):
    async with MA() as ma:
        r = await ma.cmd("players/cmd/play_announcement", player_id=player, url=url,
                         use_pre_announce=False)
    if r.get("error_code"):
        log.error("MA play_announcement: %s", r)
        raise RuntimeError(f"MA: {r}")


async def h_say(request):
    body = await request.json()
    text = (body.get("text") or "").strip()
    room = body.get("room") or "max"
    player = ROOMS.get(room, room if room.startswith(("ys_", "ugp_")) else None)
    if not text or not player:
        return web.json_response({"ok": False, "error": f"нужен text и room из {list(ROOMS)}"}, status=400)
    if quiet_now() and not body.get("force"):
        return web.json_response({"ok": False, "quiet": True, "error": "тихие часы 22:00–10:00"}, status=409)
    async with lock:
        try:
            return web.json_response(await say(text, player))
        except Exception as e:
            log.exception("say упал")
            return web.json_response({"ok": False, "error": str(e)}, status=502)


async def h_audio(request):
    item = audio.get(request.match_info["aid"])
    if not item:
        raise web.HTTPNotFound()
    return web.Response(body=item[1], content_type="audio/wav")


async def h_rooms(request):
    return web.json_response(ROOMS)


async def h_health(request):
    return web.json_response({"ok": True, "quiet": quiet_now()})


async def cleanup(app):
    async def loop():
        while True:
            await asyncio.sleep(60)
            for k, (t, _) in list(audio.items()):
                if time.time() - t > AUDIO_TTL:
                    audio.pop(k, None)
    task = asyncio.create_task(loop())
    yield
    task.cancel()


def main():
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    app = web.Application()
    app.add_routes([web.post("/say", h_say), web.get("/audio/{aid}.wav", h_audio),
                    web.get("/rooms", h_rooms), web.get("/health", h_health)])
    app.cleanup_ctx.append(cleanup)
    web.run_app(app, host="0.0.0.0", port=PORT, print=None)


if __name__ == "__main__":
    main()
