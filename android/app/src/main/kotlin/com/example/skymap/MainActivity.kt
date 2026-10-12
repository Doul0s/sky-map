package app.doulos.skymap

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.view.Surface
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity(), SensorEventListener {

    companion object {
        private const val ORIENTATION_CHANNEL =
            "skymap/orientation"
    }

    private lateinit var sensorManager: SensorManager
    private var rotationSensor: Sensor? = null

    private var eventSink: EventChannel.EventSink? = null

    private val rotationMatrix = FloatArray(9)

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        sensorManager =
            getSystemService(
                Context.SENSOR_SERVICE
            ) as SensorManager

        rotationSensor =
            sensorManager.getDefaultSensor(
                Sensor.TYPE_ROTATION_VECTOR
            )

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ORIENTATION_CHANNEL
        ).setStreamHandler(
            object : EventChannel.StreamHandler {

                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?
                ) {
                    eventSink = events
                    startSensor()
                }

                override fun onCancel(
                    arguments: Any?
                ) {
                    stopSensor()
                    eventSink = null
                }
            }
        )
    }

    private fun startSensor() {
        val sensor = rotationSensor ?: return

        sensorManager.registerListener(
            this,
            sensor,
            SensorManager.SENSOR_DELAY_GAME
        )
    }

    private fun stopSensor() {
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(
        event: SensorEvent?
    ) {
        if (event == null) {
            return
        }

        if (
            event.sensor.type !=
            Sensor.TYPE_ROTATION_VECTOR
        ) {
            return
        }

        SensorManager.getRotationMatrixFromVector(
            rotationMatrix,
            event.values
        )

        val rotation = getDisplayRotation()

        val adjustedMatrix =
            FloatArray(9)

        when (rotation) {
            Surface.ROTATION_0 -> {
                System.arraycopy(
                    rotationMatrix,
                    0,
                    adjustedMatrix,
                    0,
                    9
                )
            }

            Surface.ROTATION_90 -> {
                SensorManager.remapCoordinateSystem(
                    rotationMatrix,
                    SensorManager.AXIS_Y,
                    SensorManager.AXIS_MINUS_X,
                    adjustedMatrix
                )
            }

            Surface.ROTATION_180 -> {
                SensorManager.remapCoordinateSystem(
                    rotationMatrix,
                    SensorManager.AXIS_MINUS_X,
                    SensorManager.AXIS_MINUS_Y,
                    adjustedMatrix
                )
            }

            Surface.ROTATION_270 -> {
                SensorManager.remapCoordinateSystem(
                    rotationMatrix,
                    SensorManager.AXIS_MINUS_Y,
                    SensorManager.AXIS_X,
                    adjustedMatrix
                )
            }

            else -> {
                System.arraycopy(
                    rotationMatrix,
                    0,
                    adjustedMatrix,
                    0,
                    9
                )
            }
        }

        /*
         * Android rotation matrix (row-major, world = R * device):
         *
         * Row 0 = World X = East
         * Row 1 = World Y = North
         * Row 2 = World Z = Up
         *
         * (This is Android's own convention for the rotation-vector
         * sensor — not North/East/Up.)
         *
         * This app's world frame (SkyCoordinates) is X = North,
         * Y = East, Z = Up, so North/East are swapped here when
         * pulling components out of each column.
         */

        val rightX = adjustedMatrix[3].toDouble()
        val rightY = adjustedMatrix[0].toDouble()
        val rightZ = adjustedMatrix[6].toDouble()

        val upX = adjustedMatrix[4].toDouble()
        val upY = adjustedMatrix[1].toDouble()
        val upZ = adjustedMatrix[7].toDouble()

        val backX = -adjustedMatrix[5].toDouble()
        val backY = -adjustedMatrix[2].toDouble()
        val backZ = -adjustedMatrix[8].toDouble()

        /*
         * World coordinates:
         *
         * X = North
         * Y = East
         * Z = Up
         */

        val azimuth = Math.toDegrees(
            Math.atan2(
                backY,
                backX
            )
        ).let {
            if (it < 0) it + 360.0 else it
        }

        val horizontal =
            Math.sqrt(
                backX * backX +
                backY * backY
            )

        val altitude = Math.toDegrees(
            Math.atan2(
                backZ,
                horizontal
            )
        )

        eventSink?.success(
            mapOf(
                "backX" to backX,
                "backY" to backY,
                "backZ" to backZ,

                "upX" to upX,
                "upY" to upY,
                "upZ" to upZ,

                "rightX" to rightX,
                "rightY" to rightY,
                "rightZ" to rightZ,

                "azimuth" to azimuth,
                "altitude" to altitude
            )
        )
    }

    private fun getDisplayRotation(): Int {
        val windowManager =
            getSystemService(
                Context.WINDOW_SERVICE
            ) as WindowManager

        return windowManager
            .defaultDisplay
            .rotation
    }

    override fun onAccuracyChanged(
        sensor: Sensor?,
        accuracy: Int
    ) {
    }

    override fun onPause() {
        super.onPause()
        stopSensor()
    }

    override fun onResume() {
        super.onResume()

        if (eventSink != null) {
            startSensor()
        }
    }
}