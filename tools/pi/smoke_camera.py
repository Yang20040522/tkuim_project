"""Bounded read-only WebSocket smoke. JPEG stays in memory, never persisted."""
import argparse
import asyncio
import hashlib
import json
import time


async def measure(host, edge, count):
    import websockets
    started = time.monotonic()
    frames = metadata_count = tensor_frames = persons = 0
    sizes = []
    previous_id = previous_time = -1
    async with websockets.connect(f"ws://{host}:8765", max_size=8*1024*1024) as socket:
        if edge:
            await socket.send('{"protocol":"edge-v1"}')
        pending = None
        first = None
        while frames < count:
            message = await asyncio.wait_for(socket.recv(), 15)
            if isinstance(message, str):
                pending = json.loads(message)
                assert pending['protocolVersion'] == 'edge-v1'
                assert pending['frameId'] > previous_id
                assert pending['monotonicTimestamp'] > previous_time
                previous_id, previous_time = pending['frameId'], pending['monotonicTimestamp']
                metadata_count += 1
                continue
            assert message[:2] == b'\xff\xd8'
            if pending is not None:
                assert pending['jpegByteLength'] == len(message)
                assert pending['jpegSha256'] == hashlib.sha256(message).hexdigest()
                tensor_frames += int(pending['edgeAiAvailable'])
                persons += int(pending['personDetected'])
                if pending['personDetected']:
                    box = pending['roiRecommended']
                    assert 0 <= box['left'] < box['right'] <= pending['imageWidth']
                    assert 0 <= box['top'] < box['bottom'] <= pending['imageHeight']
                pending = None
            elif edge:
                raise AssertionError('Negotiated edge frame missing metadata')
            frames += 1
            sizes.append(len(message))
            if first is None:
                first = time.monotonic()
    elapsed = time.monotonic() - first
    print(json.dumps(dict(mode='edge-v1' if edge else 'legacy', frames=frames,
        metadataFrames=metadata_count, sensorOutputFrames=tensor_frames,
        personFrames=persons, observedFps=(frames-1)/elapsed,
        jpegMeanBytes=sum(sizes)/len(sizes), firstFrameMs=(first-started)*1000,
        seconds=elapsed), sort_keys=True))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='127.0.0.1')
    parser.add_argument('--edge', action='store_true')
    parser.add_argument('--frames', type=int, default=60)
    args = parser.parse_args()
    asyncio.run(measure(args.host, args.edge, args.frames))
