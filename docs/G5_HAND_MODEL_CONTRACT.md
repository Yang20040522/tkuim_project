# G5 MediaPipe Hand Contract

Schema2, `landmarkSource=mediapipe_hand_21`, `extractorVersion=hand-image-proxy-v1`, `modelInputVersion=hand-features-v1`, preprocessing `mediapipe21-image-proxy-v1;features-identity;float32`. Action IDs match existing Dart actions exactly. Definitions use `<actionId>-hand-v1`, labelVersion `hand-research-v1`. Registry registration is not professional approval.

Payload retains existing sampleId, subjectId, actionId, featureNames/features, capturedAt, cameraView, frames and segment. Adds orderedFeatureNames (must equal featureNames), landmarkSource, extractorVersion, modelInputVersion, timestampOrigin=channel-arrival-stopwatch, anatomicalSide (unknown unless independently reliable). movementSide=unknown is storage compatibility, not a guessed side. Top-level timestampMs equals final frame monotonic arrival time. Frames contain timestampMs and exactly21 finite xyz points, no confidence/angles/images. segment kind=rule-rep-boundaries and completedReps=1. Native-selected hand identity is not guaranteed through occlusion; tracking jumps are conservatively rejected, and unobservable switches remain a manual acceptance limitation.

Quality: x/y in [0,1], |z|<=5, wrist-to-middle-MCP image length 0.02..0.8; valid palm span; at least4 frames, <=200, monotonic timestamps, gaps<=350ms, full interval 0.3..20s. Decimate to at most10Hz while inspecting every raw observation for loss/invalidity. Occlusion cannot be proved absent from landmarks alone. No per-joint confidence is fabricated.

Image-axis features outside a single revolution (unwrapped excursion/range above360°) are rejected consistently in Dart/Python/backend, not clipped. This is a contract quality bound, not a change to the original rehabilitation rules.

Features normalize lengths by wrist-to-middle-MCP XY length; no pixels/force/medical 3D angle. Axis bearing is atan2(middleMCP.y-wrist.y,middleMCP.x-wrist.x), relative to first frame, circularly unwrapped. Mean absolute step is an image-motion proxy, not tremor diagnosis. Native front input/output conventions are preserved; no new reflection/LR swap. Camera view is metadata and camera switches discard the active interval.

| Action | Ordered features | Draft trainable labels |
|---|---|---|
| turnPalm | axis_x_range, palm_normal_z_range, orientation_range_deg, orientation_step_mean_deg, duration_seconds | meets_requirement, limited_rotation_proxy, unstable_motion |
| sidePinch | minimum_pinch_ratio, maximum_pinch_ratio, pinch_range, wrist_travel_ratio, duration_seconds | meets_requirement, limited_pinch_motion, unstable_motion |
| wristExtension | minimum_relative_axis_deg, maximum_relative_axis_deg, axis_range_deg, axis_step_mean_deg, duration_seconds | meets_requirement, limited_wrist_motion, unstable_motion |
| wristSideBend | same named features as wristExtension, independent action/version/model | meets_requirement, limited_wrist_motion, unstable_motion |

All add unassessable for review, never training output. First rep anchors segmentation. Rule success only signals a completed interval, never supplies professional Ground Truth. Static/fragmentary intervals must not become samples. Each classifier trained independently using existing reviewed-export governance/grouped RF pipeline.

Cloud schema unchanged: JSON payload can store21 points, unknown fits existing side column. Backend must validate schema2 independently and recompute features. Hand cloud sync remains closed until separately approved hand consent/version/retention; `RESEARCH_COLLECTION_ENABLED=false` unchanged. Existing binding/grants/independent-review/withdrawal/approved-export gates retained. No implicit expansion of professional study approval.
