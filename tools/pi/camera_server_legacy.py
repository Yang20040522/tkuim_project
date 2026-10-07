from picamera2 import Picamera2
import websockets
import asyncio, io
from PIL import Image

picam = Picamera2()
picam.start()

async def handler(ws):
    print(f"Client connected: {ws.remote_address}")
    while True:
        frame = picam.capture_array()
        buf = io.BytesIO()
        Image.fromarray(frame).convert('RGB').save(buf, format='JPEG', quality=60)
        await ws.send(buf.getvalue())
        await asyncio.sleep(0.033)  # ~30fps

async def main():
    async with websockets.serve(handler, '0.0.0.0', 8765):
        await asyncio.Future()  # 永久執行

asyncio.run(main())
