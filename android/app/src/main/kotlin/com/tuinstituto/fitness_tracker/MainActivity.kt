package com.tuinstituto.fitness_tracker

import android.os.Bundle
import android.Manifest
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import androidx.core.app.ActivityCompat
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.sqrt
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.EventChannel
import java.util.concurrent.Executor

/**
 * MainActivity: punto de entrada de la aplicación Android
 * - Extiende FlutterFragmentActivity (necesario para BiometricPrompt)
 * - Configura los Platform Channels aquí
 */
class MainActivity: FlutterFragmentActivity() {

    // PASO 1: Definir nombre del canal (DEBE coincidir con Dart)
    private val BIOMETRIC_CHANNEL = "com.tuinstituto.fitness/biometric"

    // PASO 2: Variables para biometría
    private lateinit var executor: Executor
    private lateinit var biometricPrompt: BiometricPrompt
    private var pendingResult: MethodChannel.Result? = null

    /**
     * configureFlutterEngine: se llama al iniciar la app
     * AQUÍ configuramos TODOS los Platform Channels
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Inicializar executor para biometría
        executor = ContextCompat.getMainExecutor(this)

        // CONFIGURAR PLATFORM CHANNEL - BIOMETRÍA

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BIOMETRIC_CHANNEL
        ).setMethodCallHandler { call, result ->
            /**
             * setMethodCallHandler: escucha llamadas desde Flutter
             *
             * Parámetros:
             * - call: contiene el nombre del método y argumentos
             * - result: objeto para enviar respuesta a Flutter
             */

            when (call.method) {
                "checkBiometricSupport" -> {
                    // Flutter llamó a checkBiometricSupport()
                    val canAuth = checkBiometricSupport()
                    result.success(canAuth)  // Enviamos respuesta
                }

                "authenticate" -> {
                    // Guardamos result para responder después (async)
                    pendingResult = result
                    showBiometricPrompt()
                }

                else -> {
                    // Método no reconocido
                    result.notImplemented()
                }
            }
        }

        // Configurar acelerómetro
        setupAccelerometerChannel(flutterEngine)

        // Configurar GPS
        setupGpsChannel(flutterEngine)
    }

    /**
     * Verificar si el dispositivo soporta biometría
     */
    private fun checkBiometricSupport(): Boolean {
        val biometricManager = BiometricManager.from(this)

        return when (biometricManager.canAuthenticate(
            BiometricManager.Authenticators.BIOMETRIC_STRONG
        )) {
            BiometricManager.BIOMETRIC_SUCCESS -> true
            else -> false
        }
    }

    /**
     * Mostrar diálogo de autenticación biométrica
     */
    private fun showBiometricPrompt() {
        // Configurar información del diálogo
        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle("Autenticación Biométrica")
            .setSubtitle("Usa tu huella dactilar")
            .setDescription("Coloca tu dedo en el sensor")
            .setNegativeButtonText("Cancelar")
            .setAllowedAuthenticators(BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .build()

        // Crear BiometricPrompt con callbacks
        biometricPrompt = BiometricPrompt(this, executor,
            object : BiometricPrompt.AuthenticationCallback() {

                override fun onAuthenticationSucceeded(
                    result: BiometricPrompt.AuthenticationResult
                ) {
                    super.onAuthenticationSucceeded(result)
                    // ✅ Autenticación exitosa
                    pendingResult?.success(true)
                    pendingResult = null
                }

                override fun onAuthenticationError(
                    errorCode: Int,
                    errString: CharSequence
                ) {
                    super.onAuthenticationError(errorCode, errString)
                    // ❌ Error en autenticación
                    pendingResult?.success(false)
                    pendingResult = null
                }

                override fun onAuthenticationFailed() {
                    super.onAuthenticationFailed()
                    // Usuario puede reintentar
                }
            }
        )

        // Mostrar el diálogo
        biometricPrompt.authenticate(promptInfo)
    }

    private val ACCELEROMETER_CHANNEL = "com.tuinstituto.fitness/accelerometer"

    private fun setupAccelerometerChannel(flutterEngine: FlutterEngine) {
        val sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
        val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        var stepCount = 0
        var lastMagnitude = 0.0
        var sensorEventListener: SensorEventListener? = null

        // Variables para suavizado
        val magnitudeHistory = mutableListOf<Double>()
        val historySize = 10
        var sampleCount = 0
        var lastActivityType = "stationary"
        var activityConfidence = 0

        // ═══════════════════════════════════════════════════════════
        // CONFIGURAR EVENT CHANNEL
        // ═══════════════════════════════════════════════════════════
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ACCELEROMETER_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sensorEventListener = object : SensorEventListener {

                    override fun onSensorChanged(event: SensorEvent?) {
                        event?.let {
                            // Calcular magnitud del vector
                            val x = it.values[0]
                            val y = it.values[1]
                            val z = it.values[2]
                            val magnitude = sqrt((x * x + y * y + z * z).toDouble())

                            // Promedio móvil para suavizar
                            magnitudeHistory.add(magnitude)
                            if (magnitudeHistory.size > historySize) {
                                magnitudeHistory.removeAt(0)
                            }
                            val avgMagnitude = magnitudeHistory.average()

                            // Detectar paso
                            if (magnitude > 12 && lastMagnitude <= 12) {
                                stepCount++
                            }
                            lastMagnitude = magnitude

                            // Determinar actividad (con promedio)
                            val newActivityType = when {
                                avgMagnitude < 10.5 -> "stationary"
                                avgMagnitude < 13.5 -> "walking"
                                else -> "running"
                            }

                            // Solo cambiar si hay confianza
                            if (newActivityType == lastActivityType) {
                                activityConfidence++
                            } else {
                                activityConfidence = 0
                            }

                            val finalActivityType = if (activityConfidence >= 3) {
                                newActivityType
                            } else {
                                lastActivityType
                            }
                            lastActivityType = newActivityType

                            // Enviar cada 3 muestras
                            sampleCount++
                            if (sampleCount >= 3) {
                                sampleCount = 0

                                // ENVIAR DATOS A FLUTTER
                                val data = mapOf(
                                    "stepCount" to stepCount,
                                    "activityType" to finalActivityType,
                                    "magnitude" to avgMagnitude
                                )

                                // events?.success: envía datos al stream
                                events?.success(data)
                            }
                        }
                    }

                    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
                }

                // Registrar listener del sensor
                sensorManager.registerListener(
                    sensorEventListener,
                    accelerometer,
                    SensorManager.SENSOR_DELAY_GAME
                )
            }

            override fun onCancel(arguments: Any?) {
                sensorEventListener?.let {
                    sensorManager.unregisterListener(it)
                }
                sensorEventListener = null
            }
        })

        // MethodChannel auxiliar para control
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "$ACCELEROMETER_CHANNEL/control"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    stepCount = 0
                    result.success(null)
                }
                "stop" -> {
                    result.success(null)
                }
                "reset" -> {
                    stepCount = 0
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    companion object {
        private const val GPS_CHANNEL = "com.tuinstituto.fitness/gps"
        private const val LOCATION_PERMISSION_REQUEST_CODE = 1001
    }

    private fun setupGpsChannel(flutterEngine: FlutterEngine) {
        val locationManager = getSystemService(LOCATION_SERVICE) as LocationManager
        var locationListener: LocationListener? = null

        // ═══════════════════════════════════════════════════════════
        // METHOD CHANNEL - Operaciones puntuales
        // ═══════════════════════════════════════════════════════════
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            GPS_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGpsEnabled" -> {
                    val isEnabled = locationManager.isProviderEnabled(
                        LocationManager.GPS_PROVIDER
                    )
                    result.success(isEnabled)
                }

                "requestPermissions" -> {
                    if (hasLocationPermission()) {
                        result.success(true)
                    } else {
                        ActivityCompat.requestPermissions(
                            this,
                            arrayOf(
                                Manifest.permission.ACCESS_FINE_LOCATION,
                                Manifest.permission.ACCESS_COARSE_LOCATION
                            ),
                            LOCATION_PERMISSION_REQUEST_CODE
                        )
                        result.success(hasLocationPermission())
                    }
                }

                "getCurrentLocation" -> {
                    if (!hasLocationPermission()) {
                        result.error("PERMISSION_DENIED", "Sin permisos", null)
                        return@setMethodCallHandler
                    }

                    try {
                        val location = locationManager.getLastKnownLocation(
                            LocationManager.GPS_PROVIDER
                        ) ?: locationManager.getLastKnownLocation(
                            LocationManager.NETWORK_PROVIDER
                        )

                        if (location != null) {
                            result.success(locationToMap(location))
                        } else {
                            result.error("NO_LOCATION", "No disponible", null)
                        }
                    } catch (e: SecurityException) {
                        result.error("SECURITY_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }

        // ═══════════════════════════════════════════════════════════
        // EVENT CHANNEL - Stream de ubicaciones
        // ═══════════════════════════════════════════════════════════
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "$GPS_CHANNEL/stream"
        ).setStreamHandler(object : EventChannel.StreamHandler {

            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                if (!hasLocationPermission()) {
                    events?.error("PERMISSION_DENIED", "Sin permisos", null)
                    return
                }

                locationListener = object : LocationListener {
                    override fun onLocationChanged(location: Location) {
                        // Enviar ubicación a Flutter
                        events?.success(locationToMap(location))
                    }

                    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
                    override fun onProviderEnabled(provider: String) {}
                    override fun onProviderDisabled(provider: String) {}
                }

                try {
                    // Solicitar actualizaciones
                    locationManager.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        1000L,      // cada 1 segundo
                        0f,         // cualquier distancia
                        locationListener!!
                    )
                } catch (e: SecurityException) {
                    events?.error("SECURITY_ERROR", e.message, null)
                }
            }

            override fun onCancel(arguments: Any?) {
                locationListener?.let {
                    locationManager.removeUpdates(it)
                }
                locationListener = null
            }
        })
    }

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun locationToMap(location: Location): Map<String, Any> {
        return mapOf(
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "altitude" to location.altitude,
            "speed" to location.speed.toDouble(),
            "accuracy" to location.accuracy.toDouble(),
            "timestamp" to location.time
        )
    }
}
