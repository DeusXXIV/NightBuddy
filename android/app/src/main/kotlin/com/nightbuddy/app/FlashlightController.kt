package com.nightbuddy.app

import android.content.Context
import android.hardware.camera2.CameraCharacteristics
import android.Manifest
import android.content.pm.PackageManager
import android.hardware.camera2.CameraManager
import androidx.core.content.ContextCompat

object FlashlightController {
    @Volatile
    private var cachedCameraId: String? = null
    @Volatile
    private var torchOn: Boolean = false

    fun hasFlash(context: Context): Boolean {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager?
        manager ?: return false
        return findCameraId(manager) != null
    }

    fun isOn(): Boolean = torchOn

    fun hasPermission(context: Context): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    fun setTorch(context: Context, enabled: Boolean): Boolean {
        val manager = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager?
            ?: return false
        val id = findCameraId(manager) ?: return false
        return try {
            manager.setTorchMode(id, enabled)
            torchOn = enabled
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun findCameraId(manager: CameraManager): String? {
        cachedCameraId?.let { return it }
        return try {
            for (id in manager.cameraIdList) {
                val characteristics = manager.getCameraCharacteristics(id)
                val hasFlash = characteristics.get(CameraCharacteristics.FLASH_INFO_AVAILABLE) == true
                val facing = characteristics.get(CameraCharacteristics.LENS_FACING)
                val isBackCamera = facing == null ||
                    facing == CameraCharacteristics.LENS_FACING_BACK ||
                    facing == CameraCharacteristics.LENS_FACING_EXTERNAL
                if (hasFlash && isBackCamera) {
                    cachedCameraId = id
                    return id
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }
}
