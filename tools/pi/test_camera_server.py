import asyncio
import hashlib
import json
import math
import unittest
from unittest.mock import patch
from types import SimpleNamespace
import time

from camera_server import (Camera, Broadcast, bbox_pixels, edge_handshake,
                           metadata_packet, padded_roi, select_person)


class EdgeLogicTests(unittest.TestCase):
    def test_category_resolved_from_actual_labels_not_fixed_index(self):
        labels = ["chair", "person"]
        person = select_person([[.1, .2, .9, .8]] * 2, [.99, .8], [0, 1],
                               labels, lambda c: (128, 48, 384, 384), 640, 480)
        self.assertEqual(person[0], .8)

    def test_no_person_and_low_confidence(self):
        for score, category in [(.2, 0), (.9, 1), (math.nan, 0), (.9, math.inf)]:
            self.assertIsNone(select_person([[0, 0, 1, 1]], [score], [category],
                ["person", "chair"], lambda _: (0, 0, 640, 480), 640, 480))

    def test_highest_confidence_and_deterministic_area_tie(self):
        person = select_person([[0, 0, 1, 1], [0, 0, .5, .5]], [.8, .9], [0, 0],
            ["person"], lambda c: (0, 0, c[3]*640, c[2]*480), 640, 480)
        self.assertEqual(person[0], .9)
        self.assertEqual(person[-1]["right"], 320)

    def test_converter_called_with_valid_yx_coords_only(self):
        calls = []
        def convert(coords):
            calls.append(coords)
            return 100, 40, 200, 350
        result = select_person([[.1, .2, .9, .8], [0, 0, math.nan, 1]], [.9, .9],
            [0, 0], ["person"], convert, 640, 480)
        self.assertEqual(calls, [(.1, .2, .9, .8)])
        self.assertEqual(result[-1]["bottom"], 390)

    def test_clamping_padding_non_square_and_edges(self):
        box = bbox_pixels((-20, 40, 600, 500), 640, 480)
        self.assertEqual(box, dict(left=0, top=40, right=580, bottom=480))
        self.assertEqual(padded_roi(box, 640, 480),
                         dict(left=0, top=0, right=640, bottom=480))

    def test_degenerate_small_outside_and_nonfinite(self):
        for box in [(1, 1, 0, 20), (1, 1, 5, 5), (700, 500, 100, 100),
                    (math.inf, 0, 20, 20), (0, 0, math.nan, 50)]:
            self.assertIsNone(bbox_pixels(box, 640, 480))

    def test_padding_config_rejects_invalid(self):
        for padding in [-1, 1, math.inf, math.nan]:
            with self.assertRaises(ValueError):
                padded_roi(dict(left=10, top=10, right=100, bottom=100), 640, 480, padding)

    def test_handshake_explicit_and_legacy_compatible(self):
        self.assertTrue(edge_handshake('{"protocol":"edge-v1"}'))
        for value in [None, b'jpeg', '{}', 'invalid', '{"protocol":"v2"}', 'x'*129]:
            self.assertFalse(edge_handshake(value))

    def test_exact_packet_jpeg_digest_and_no_private_fields(self):
        person = (.8, 100, 0, 0, dict(left=160, top=80, right=480, bottom=400))
        data = metadata_packet(7, 123, 640, 480, b'jpeg7', True, 'model', 'sha', person)
        self.assertEqual(data['frameId'], 7)
        self.assertEqual(data['jpegSha256'], hashlib.sha256(b'jpeg7').hexdigest())
        self.assertEqual(data['roiRecommended']['left'], 96)
        self.assertEqual(data['roiNormalized']['left'], 96/640)
        self.assertNotIn('userId', data)
        self.assertNotIn('landmarks', data)
        json.dumps(data, allow_nan=False)

    def test_no_inference_never_reuses_previous_person(self):
        data = metadata_packet(8, 124, 640, 480, b'jpeg8', False, 'model', 'sha')
        self.assertFalse(data['personDetected'])
        self.assertFalse(data['edgeAiAvailable'])
        self.assertNotIn('roiRecommended', data)


class StopClient(Exception):
    pass


class RequestTests(unittest.TestCase):
    def capture(self, edge, encoder_error=False):
        class Array:
            shape = (480, 640, 3)
            def __getitem__(self, key):
                return self
        class Request:
            releases = metadata_reads = image_reads = 0
            def make_array(self, stream):
                self.image_reads += 1
                return Array()
            def get_metadata(self):
                self.metadata_reads += 1
                return {'SensorTimestamp': 123000000}
            def release(self):
                self.releases += 1
        request = Request()
        camera = Camera.__new__(Camera)
        camera.edge = edge
        camera.picam = SimpleNamespace(capture_request=lambda: request)
        camera.frames = camera.tensors = camera.person_frames = 0
        camera.model_name, camera.model_version = 'synthetic', 'test'
        camera.padding, camera.last_summary = .2, time.monotonic()
        def save(output, **kwargs):
            if encoder_error:
                raise ValueError('Synthetic encoding error')
            output.write(b'synthetic-jpeg')
        fake_image = SimpleNamespace(fromarray=lambda _: SimpleNamespace(save=save))
        with patch.dict('sys.modules', {'PIL': SimpleNamespace(Image=fake_image)}):
            try:
                result = camera.capture()
            finally:
                self.assertEqual(request.releases, 1)
                self.assertEqual(request.metadata_reads, 1)
                self.assertEqual(request.image_reads, 1)
        return json.loads(result[0])

    def test_missing_tensor_no_cached_detection_and_same_request(self):
        result = self.capture(SimpleNamespace(get_outputs=lambda *a, **k: None))
        self.assertFalse(result['edgeAiAvailable'])
        self.assertFalse(result['personDetected'])
        self.assertNotIn('roiRecommended', result)

    def test_inference_exception_still_returns_jpeg(self):
        def fail(*args, **kwargs):
            raise ValueError('Synthetic sensor metadata error')
        self.assertFalse(self.capture(SimpleNamespace(get_outputs=fail))['edgeAiAvailable'])

    def test_encoder_failure_releases_request(self):
        with self.assertRaises(ValueError):
            self.capture(None, encoder_error=True)


class ProtocolTests(unittest.IsolatedAsyncioTestCase):
    async def exchange(self, handshake):
        packets = [('meta1', b'jpeg1'), ('meta2', b'jpeg2')]
        class FakeCamera:
            def capture(self):
                return packets.pop(0) if packets else ('meta3', b'jpeg3')
        class Socket:
            sent = []
            async def recv(self):
                return handshake
            async def send(self, message):
                self.sent.append(message)
                if message == b'jpeg2':
                    raise StopClient()
        broadcast, socket = Broadcast(FakeCamera()), Socket()
        producer = asyncio.create_task(broadcast.produce())
        try:
            with self.assertRaises(StopClient):
                await broadcast.handler(socket)
        finally:
            producer.cancel()
            try:
                await producer
            except asyncio.CancelledError:
                pass
        self.assertFalse(broadcast.clients)
        return socket.sent

    async def test_edge_pairs_never_interleave(self):
        self.assertEqual(await self.exchange('{"protocol":"edge-v1"}'),
                         ['meta1', b'jpeg1', 'meta2', b'jpeg2'])

    async def test_legacy_invalid_handshake_only_binary(self):
        self.assertEqual(await self.exchange('{}'), [b'jpeg1', b'jpeg2'])


if __name__ == '__main__':
    unittest.main()
