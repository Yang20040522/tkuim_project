"""RehabAssist Pi camera: sensor-only IMX500 detection, legacy JPEG + edge-v1.

No saved images, CPU model inference, patient data, or extra listening ports.
Pure functions below are importable without Picamera2/hardware dependencies.
"""
import asyncio
import hashlib
import io
import json
import logging
import math
import os
from pathlib import Path
import time

LOG = logging.getLogger("rehabassist.camera")
MODEL = "/usr/share/imx500-models/imx500_network_ssd_mobilenetv2_fpnlite_320x320_pp.rpk"
PADDING_VERSION = "person-padding-v1"


def bbox_pixels(xywh, width, height):
    if len(xywh) != 4 or not all(math.isfinite(float(v)) for v in xywh):
        return None
    x, y, w, h = map(float, xywh)
    if w <= 0 or h <= 0:
        return None
    left, top = max(0, x), max(0, y)
    right, bottom = min(width, x + w), min(height, y + h)
    if right - left < 16 or bottom - top < 16:
        return None
    return dict(left=left, top=top, right=right, bottom=bottom)


def padded_roi(box, width, height, padding=.20):
    if not math.isfinite(padding) or not 0 <= padding <= .5:
        raise ValueError("Invalid ROI padding")
    dx = (box["right"] - box["left"]) * padding
    dy = (box["bottom"] - box["top"]) * padding
    return dict(left=max(0, math.floor(box["left"] - dx)),
                top=max(0, math.floor(box["top"] - dy)),
                right=min(width, math.ceil(box["right"] + dx)),
                bottom=min(height, math.ceil(box["bottom"] + dy)))


def select_person(boxes, scores, classes, labels, convert, width, height,
                  threshold=.55):
    """Class IDs resolved using the deployed network's labels, never guessed.

    Highest confidence wins; area/coordinates break ties deterministically.
    convert is the official IMX500 inference→ISP mapping, using THIS request.
    """
    candidates = []
    for coords, score, category in zip(boxes, scores, classes):
        score, category = float(score), float(category)
        if (not math.isfinite(score) or not threshold <= score <= 1 or
                not math.isfinite(category) or not category.is_integer()):
            continue
        index = int(category)
        if not 0 <= index < len(labels) or labels[index].strip().lower() != "person":
            continue
        if len(coords) != 4 or not all(math.isfinite(float(v)) for v in coords):
            continue
        if coords[2] <= coords[0] or coords[3] <= coords[1]:
            continue
        box = bbox_pixels(convert(tuple(map(float, coords))), width, height)
        if box:
            area = (box["right"] - box["left"]) * (box["bottom"] - box["top"])
            candidates.append((score, area, -box["left"], -box["top"], box))
    return max(candidates, key=lambda p: p[:4]) if candidates else None


def edge_handshake(message):
    if not isinstance(message, str) or len(message) > 128:
        return False
    try:
        return json.loads(message) == {"protocol": "edge-v1"}
    except (ValueError, TypeError):
        return False


def metadata_packet(frame_id, timestamp, width, height, jpeg, available,
                    model_name, model_version, person=None, padding=.20):
    data = dict(protocolVersion="edge-v1", frameId=frame_id,
                monotonicTimestamp=timestamp, imageWidth=width, imageHeight=height,
                edgeAiAvailable=available, edgeModelName=model_name,
                edgeModelVersion=model_version, personDetected=person is not None,
                roiPaddingPolicyVersion=PADDING_VERSION,
                jpegByteLength=len(jpeg), jpegSha256=hashlib.sha256(jpeg).hexdigest())
    if person:
        box = person[-1]
        roi = padded_roi(box, width, height, padding)
        data.update(personConfidence=person[0], personBBoxPixels=box,
                    roiRecommended=roi,
                    roiNormalized={k: v / (width if k in ("left", "right") else height)
                                   for k, v in roi.items()})
    return data


class Camera:
    def __init__(self):
        from picamera2 import Picamera2
        self.edge = None
        self.model_name, self.model_version = Path(MODEL).name, "unavailable"
        self.frames = self.tensors = self.person_frames = 0
        self.padding = float(os.environ.get("EDGE_ROI_PADDING", ".20"))
        if not math.isfinite(self.padding) or not 0 <= self.padding <= .5:
            raise ValueError("Invalid EDGE_ROI_PADDING")
        if os.environ.get("EDGE_AI_ENABLED", "true").lower() == "true":
            try:
                from picamera2.devices.imx500 import IMX500
                # Sensor firmware must be selected BEFORE Picamera2 acquisition.
                self.edge = IMX500(MODEL)
                self.intrinsics = self.edge.network_intrinsics
                if not self.intrinsics or self.intrinsics.task != "object detection":
                    raise ValueError("Unsupported model intrinsics")
                self.intrinsics.update_with_defaults()
                self.labels = self.intrinsics.labels
                if self.intrinsics.ignore_dash_labels:
                    self.labels = [label for label in self.labels if label and label != "-"]
                if not self.labels or "person" not in [label.lower() for label in self.labels]:
                    raise ValueError("Model has no authoritative person label")
                self.model_version = hashlib.sha256(Path(MODEL).read_bytes()).hexdigest()
                LOG.info("IMX500 model configured: %s sha256=%s person-index=%s",
                         self.model_name, self.model_version,
                         [i for i, label in enumerate(self.labels) if label.lower() == "person"])
            except Exception as exc:
                # No CPU inference substitute. Continue the original camera stream.
                LOG.warning("EDGE_UNAVAILABLE init: %s", type(exc).__name__)
                if self.edge is not None:
                    self.edge.device_fd.close()
                self.edge = None
        self.picam = Picamera2(self.edge.camera_num if self.edge else 0)
        # Explicit RGB config removes format ambiguity; dimensions retain old default.
        self.picam.configure(self.picam.create_preview_configuration(
            main={"size": (640, 480), "format": "RGB888"},
            controls={"FrameRate": 30}, buffer_count=6))
        self.picam.start()
        self.last_summary = time.monotonic()

    def capture(self):
        from PIL import Image
        # One request owns BOTH ISP pixels and sensor tensor metadata. No
        # capture_array()+capture_metadata() race or previous-tensor cache.
        request = self.picam.capture_request()
        try:
            raw = request.make_array("main")
            metadata = request.get_metadata()
            width, height = raw.shape[1], raw.shape[0]
            # Picamera2 RGB888 memory is BGR on little-endian platforms.
            rgb = raw[:, :, ::-1]
            output = io.BytesIO()
            Image.fromarray(rgb).save(output, format="JPEG", quality=60)
            jpeg = output.getvalue()
            person = None
            available = False
            if self.edge:
                try:
                    outputs = self.edge.get_outputs(metadata, add_batch=True)
                    if outputs is not None:
                        self.tensors += 1
                        if self.tensors == 1:
                            LOG.info("IMX500 sensor tensor shapes=%s (request metadata; no CPU inference)",
                                     [list(output.shape) for output in outputs])
                        available = True
                        boxes, scores, classes = outputs[0][0], outputs[1][0], outputs[2][0]
                        if self.intrinsics.bbox_normalization:
                            boxes = boxes / self.edge.get_input_size()[1]
                        if self.intrinsics.bbox_order == "xy":
                            boxes = boxes[:, [1, 0, 3, 2]]
                        person = select_person(boxes, scores, classes, self.labels,
                            lambda coords: self.edge.convert_inference_coords(
                                coords, metadata, self.picam), width, height)
                except Exception as exc:
                    available = False
                    # Rate-limited below; no raw tensors/images/identities in logs.
                    self.last_edge_error = type(exc).__name__
            self.frames += 1
            self.person_frames += int(person is not None)
            timestamp = metadata.get("SensorTimestamp")
            if not isinstance(timestamp, int) or timestamp < 0:
                timestamp = time.monotonic_ns()
            packet = metadata_packet(self.frames, timestamp // 1_000_000,
                width, height, jpeg, available, self.model_name, self.model_version,
                person, self.padding)
            if time.monotonic() - self.last_summary >= 30:
                LOG.info("frames=%s sensor-output-frames=%s person-frames=%s edge-error=%s",
                         self.frames, self.tensors, self.person_frames,
                         getattr(self, "last_edge_error", "none"))
                self.last_summary = time.monotonic()
            return json.dumps(packet, separators=(",", ":")), jpeg
        finally:
            request.release()

    def close(self):
        self.picam.stop()
        self.picam.close()
        if self.edge:
            self.edge.device_fd.close()


class Broadcast:
    """One camera owner, one capture per tick regardless of connected clients.

    Bounded latest-frame queues prevent slow clients accumulating JPEGs. Each
    client's single writer sends metadata/JPEG together, never interleaved.
    """
    def __init__(self, camera):
        self.camera = camera
        self.clients = set()

    async def produce(self):
        while True:
            if not self.clients:
                await asyncio.sleep(.1)
                continue
            packet = await asyncio.to_thread(self.camera.capture)
            for queue in tuple(self.clients):
                if queue.full():
                    queue.get_nowait()
                queue.put_nowait(packet)
            await asyncio.sleep(.033)  # retain legacy pacing; no speedup claim

    async def handler(self, socket):
        # Optional import keeps pure tests hardware/dependency-free. Production
        # uses the installed official websockets ConnectionClosed superclass.
        connection_errors = (asyncio.TimeoutError,)
        try:
            from websockets.exceptions import ConnectionClosed
            connection_errors += (ConnectionClosed,)
        except ImportError:
            pass
        edge = False
        queue = asyncio.Queue(maxsize=1)
        try:
            try:
                edge = edge_handshake(await asyncio.wait_for(socket.recv(), .3))
            except asyncio.TimeoutError:
                pass  # Old clients receive raw JPEG only.
            self.clients.add(queue)
            while True:
                text, jpeg = await queue.get()
                if edge:
                    await asyncio.wait_for(socket.send(text), 2)
                await asyncio.wait_for(socket.send(jpeg), 2)
        except connection_errors:
            pass  # Normal leave/background/slow consumer: don't log a traceback.
        finally:
            self.clients.discard(queue)


async def main():
    import websockets
    camera = Camera()
    broadcast = Broadcast(camera)
    producer = asyncio.create_task(broadcast.produce())
    try:
        async with websockets.serve(broadcast.handler, "0.0.0.0", 8765,
                                    max_size=1024, max_queue=1):
            await producer
    finally:
        producer.cancel()
        camera.close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)
    asyncio.run(main())
