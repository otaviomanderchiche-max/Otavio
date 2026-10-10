package com.ecomonitor.ecomonitor_app

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.LocationManager
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.net.NetworkRequest
import android.net.wifi.WifiManager
import android.net.wifi.WifiNetworkSpecifier
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val ssidEsperado = "EcoMonitor-ESP32"
    private val wifiSenha = "EcoMonitor2026"
    private val handler = Handler(Looper.getMainLooper())
    private lateinit var wifiManager: WifiManager
    private lateinit var manager: ConnectivityManager
    private lateinit var bridge: MethodChannel
    private var boundNetwork: Network? = null
    private var callback: ConnectivityManager.NetworkCallback? = null
    private var connecting: MethodChannel.Result? = null
    private var permissionResult: MethodChannel.Result? = null
    private var permissionAction: (() -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        wifiManager = applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager
        manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        bridge = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ecomonitor/wifi")
        bridge.setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> withPermissions(result) { status(result) }
                "scanNetworks" -> withPermissions(result) { scan(result) }
                "connect" -> withPermissions(result) { connect(result) }
                "bindExisting" -> withPermissions(result) { bindExisting(result) }
                "disconnect" -> {
                    releaseConnection()
                    result.success(true)
                }
                "openWifiSettings" -> {
                    startActivity(Intent(Settings.ACTION_WIFI_SETTINGS))
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requiredPermissions(): Array<String> {
        val list = mutableListOf(Manifest.permission.ACCESS_FINE_LOCATION)
        if (Build.VERSION.SDK_INT >= 33) list.add(Manifest.permission.NEARBY_WIFI_DEVICES)
        return list.toTypedArray()
    }

    private fun withPermissions(result: MethodChannel.Result, action: () -> Unit) {
        val missing = requiredPermissions().filter {
            checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) { action(); return }
        if (permissionResult != null) {
            result.error("BUSY", "Aguarde a solicitação de permissão.", null)
            return
        }
        permissionResult = result
        permissionAction = action
        requestPermissions(missing.toTypedArray(), 7701)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != 7701) return
        val action = permissionAction
        val result = permissionResult
        permissionAction = null
        permissionResult = null
        if (requiredPermissions().all { checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }) {
            action?.invoke()
        } else {
            result?.error("PERMISSION_DENIED", "Autorize redes próximas e localização.", null)
        }
    }

    private fun locationEnabled(): Boolean {
        val loc = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        return loc.isLocationEnabled
    }

    @SuppressLint("MissingPermission")
    private fun currentSsid(): String {
        return try {
            val raw = wifiManager.connectionInfo?.ssid ?: ""
            if (raw == WifiManager.UNKNOWN_SSID || raw.contains("unknown ssid")) "" else raw.trim('"')
        } catch (_: Exception) { "" }
    }

    @SuppressLint("MissingPermission")
    private fun status(result: MethodChannel.Result) {
        result.success(mapOf(
            "wifiEnabled" to wifiManager.isWifiEnabled,
            "locationEnabled" to locationEnabled(),
            "ssid" to currentSsid(),
            "bound" to (boundNetwork != null)
        ))
    }

    @SuppressLint("MissingPermission")
    private fun scan(result: MethodChannel.Result) {
        if (!wifiManager.isWifiEnabled) {
            result.error("WIFI_OFF", "Ative o Wi-Fi do celular.", null)
            return
        }
        if (!locationEnabled()) {
            result.error("LOCATION_OFF", "Ative a Localização do Android.", null)
            return
        }
        try {
            wifiManager.startScan()
            handler.postDelayed({
                try {
                    val networks = wifiManager.scanResults
                        .filter { it.SSID.isNotBlank() }
                        .groupBy { it.SSID }
                        .map { (ssid, items) ->
                            mapOf<String, Any>(
                                "ssid" to ssid,
                                "rssi" to (items.maxOfOrNull { it.level } ?: -100),
                                "isEcoMonitor" to (ssid == ssidEsperado),
                                "secured" to items.any { it.capabilities.contains("WPA") }
                            )
                        }
                        .sortedWith(compareByDescending<Map<String, Any>> { it["isEcoMonitor"] == true }
                            .thenByDescending { it["rssi"] as Int })
                    result.success(networks)
                } catch (e: Exception) {
                    result.error("SCAN_FAILED", e.message ?: "Falha ao listar redes.", null)
                }
            }, 1600)
        } catch (e: Exception) {
            result.error("SCAN_FAILED", e.message ?: "Falha ao pesquisar redes.", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun connect(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 29) {
            result.error("ANDROID_OLD", "É necessário Android 10 ou posterior.", null)
            return
        }
        if (!wifiManager.isWifiEnabled) {
            result.error("WIFI_OFF", "Ligue o Wi-Fi.", null)
            return
        }
        if (connecting != null) {
            result.error("BUSY", "Conexão em andamento.", null)
            return
        }
        if (boundNetwork != null) { result.success(true); return }
        releaseConnection()
        try {
            val specifier = WifiNetworkSpecifier.Builder()
                .setSsid(ssidEsperado)
                .setWpa2Passphrase(wifiSenha)
                .build()
            val request = NetworkRequest.Builder()
                .addTransportType(NetworkCapabilities.TRANSPORT_WIFI)
                .removeCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
                .setNetworkSpecifier(specifier)
                .build()
            connecting = result
            val cb = object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    manager.bindProcessToNetwork(network)
                    boundNetwork = network
                    handler.post {
                        connecting?.success(true)
                        connecting = null
                    }
                }
                override fun onUnavailable() {
                    handler.post {
                        connecting?.error("CONNECT_FAILED", "Rede indisponível ou não autorizada.", null)
                        connecting = null
                        releaseConnection()
                    }
                }
                override fun onLost(network: Network) {
                    if (boundNetwork == network) {
                        boundNetwork = null
                        manager.bindProcessToNetwork(null)
                        handler.post {
                            connecting?.error("DISCONNECTED", "Conexão perdida.", null)
                            connecting = null
                            bridge.invokeMethod("wifiLost", null)
                        }
                    }
                }
            }
            callback = cb
            manager.requestNetwork(request, cb, 35000)
        } catch (e: Exception) {
            connecting = null
            releaseConnection()
            result.error("CONNECT_FAILED", e.message ?: "Falha ao conectar.", null)
        }
    }

    @SuppressLint("MissingPermission")
    private fun bindExisting(result: MethodChannel.Result) {
        if (boundNetwork != null) { result.success(true); return }
        if (currentSsid() != ssidEsperado) { result.success(false); return }
        try {
            val current = manager.allNetworks.firstOrNull {
                manager.getNetworkCapabilities(it)
                    ?.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) == true
            }
            if (current == null) {
                result.success(false)
            } else {
                manager.bindProcessToNetwork(current)
                boundNetwork = current
                result.success(true)
            }
        } catch (_: Exception) { result.success(false) }
    }

    private fun releaseConnection() {
        try { manager.bindProcessToNetwork(null) } catch (_: Exception) {}
        try { callback?.let { manager.unregisterNetworkCallback(it) } } catch (_: Exception) {}
        callback = null
        boundNetwork = null
        connecting = null
    }

    override fun onDestroy() {
        releaseConnection()
        super.onDestroy()
    }
}
