package com.example.flutter_body.pose

import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.RectF
import androidx.camera.view.TransformExperimental
import androidx.camera.view.transform.CoordinateTransform
import androidx.camera.view.transform.OutputTransform

/** Display-only geometry. Neither world landmarks nor anatomical landmark indices are changed. */
@androidx.annotation.OptIn(TransformExperimental::class)
internal object PosePreviewGeometry {
    /** Matches Bitmap.createBitmap's rotation and automatic translation to positive bounds. */
    fun rawToUpright(width: Int, height: Int, rotationDegrees: Int): Matrix {
        val rotation = Matrix().apply { setRotate(rotationDegrees.toFloat()) }
        val bounds = RectF(0f, 0f, width.toFloat(), height.toFloat())
        rotation.mapRect(bounds)
        rotation.postTranslate(-bounds.left, -bounds.top)
        return rotation
    }

    fun create(
        source: OutputTransform,
        target: OutputTransform,
        rawWidth: Int,
        rawHeight: Int,
        uprightWidth: Int,
        uprightHeight: Int,
        rotationDegrees: Int,
        cropRect: Rect,
        previewWidth: Int,
        previewHeight: Int,
        revision: Int,
    ): Map<String, Any>? {
        if (previewWidth <= 0 || previewHeight <= 0) return null
        val uprightToRaw = Matrix()
        if (!rawToUpright(rawWidth, rawHeight, rotationDegrees).invert(uprightToRaw)) {
            return null
        }
        val rawToPreview = Matrix()
        // source is the FULL, UNROTATED ImageProxy buffer. CameraX's source matrix still
        // contains its authoritative ViewPort crop. Both use cases share this ViewPort.
        // target comes directly from PreviewView.outputTransform, including front mirroring.
        CoordinateTransform(source, target).transform(rawToPreview)
        val transform = Matrix().apply {
            setScale(uprightWidth.toFloat(), uprightHeight.toFloat())
            postConcat(uprightToRaw)
            postConcat(rawToPreview)
            postScale(1f / previewWidth, 1f / previewHeight)
        }
        val values = FloatArray(9)
        transform.getValues(values)
        if (values.any { !it.isFinite() }) return null
        return mapOf(
            "imageWidth" to uprightWidth,
            "imageHeight" to uprightHeight,
            "rawImageWidth" to rawWidth,
            "rawImageHeight" to rawHeight,
            "rotationDegrees" to rotationDegrees,
            "mirrored" to true,
            "cropRect" to listOf(cropRect.left, cropRect.top, cropRect.right, cropRect.bottom),
            "previewWidth" to previewWidth,
            "previewHeight" to previewHeight,
            // Android Matrix row-major order; normalized upright input -> normalized preview.
            "matrix" to values.map { it.toDouble() },
            "revision" to revision,
        )
    }
}
