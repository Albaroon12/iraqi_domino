package com.albaron.iraqi_domino

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothServerSocket
import android.bluetooth.BluetoothSocket
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.net.wifi.p2p.WifiP2pManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStream
import java.util.UUID
import java.util.concurrent.ConcurrentHashMap
import kotlin.concurrent.thread

/**
 * First-party native Android bridge powering:
 * 1. Bluetooth RFCOMM low-latency multiplayer (`BluetoothServerSocket` / `BluetoothSocket`)
 * 2. Wi-Fi Direct (`WifiP2pManager`) autonomous P2P group creation for Offline Wi-Fi
 */
class NearbyP2pBridge(private val activity: Activity) :
    MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    companion object {
        private const val METHOD_CHANNEL = "com.albaron.iraqi_domino/nearby_p2p"
        private const val EVENT_CHANNEL = "com.albaron.iraqi_domino/nearby_p2p_events"
        private const val SERVICE_NAME = "IraqiDominoP2P"
        private val SERVICE_UUID: UUID = UUID.fromString("8e400001-b5a3-f393-e0a9-e50e24dcca9e")
        const val PERMISSION_REQ_CODE = 4912

        fun register(activity: Activity, messenger: BinaryMessenger): NearbyP2pBridge {
            val bridge = NearbyP2pBridge(activity)
            MethodChannel(messenger, METHOD_CHANNEL).setMethodCallHandler(bridge)
            EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(bridge)
            return bridge
        }
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermResult: MethodChannel.Result? = null

    private var serverSocket: BluetoothServerSocket? = null
    private val hostPeers = ConcurrentHashMap<String, OutputStream>()
    private val hostPeerSockets = ConcurrentHashMap<String, BluetoothSocket>()

    private var clientSocket: BluetoothSocket? = null
    private var clientOut: OutputStream? = null
    private var discoveryReceiver: BroadcastReceiver? = null

    private var wifiP2pManager: WifiP2pManager? = null
    private var wifiP2pChannel: WifiP2pManager.Channel? = null

    private fun btAdapter(): BluetoothAdapter? {
        val mgr = activity.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return mgr?.adapter
    }

    private fun emit(event: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(event) }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != PERMISSION_REQ_CODE) return
        val res = pendingPermResult ?: return
        pendingPermResult = null
        val allGranted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        res.success(allGranted)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermissions" -> handleRequestPermissions(call, result)
            "ensureWifiDirectGroup" -> {
                ensureWifiDirectGroup()
                result.success(emptyMap<String, Any?>())
            }
            "discoverWifiDirectPeers" -> {
                discoverWifiDirectPeers()
                result.success(emptyMap<String, Any?>())
            }
            "removeWifiDirectGroup" -> {
                removeWifiDirectGroup()
                result.success(emptyMap<String, Any?>())
            }
            "startBluetoothHost" -> startBluetoothHost(call, result)
            "updateBluetoothAdvertisement" -> result.success(emptyMap<String, Any?>())
            "sendToPeer" -> {
                val peerId = call.argument<String>("peerId") ?: ""
                val payload = call.argument<String>("payload") ?: ""
                thread {
                    try {
                        hostPeers[peerId]?.let { out ->
                            synchronized(out) {
                                out.write((payload + "\n").toByteArray(Charsets.UTF_8))
                                out.flush()
                            }
                        }
                    } catch (_: Exception) {
                        dropHostPeer(peerId)
                    }
                }
                result.success(emptyMap<String, Any?>())
            }
            "broadcast" -> {
                val payload = call.argument<String>("payload") ?: ""
                val bytes = (payload + "\n").toByteArray(Charsets.UTF_8)
                thread {
                    for ((peerId, out) in hostPeers.entries.toList()) {
                        try {
                            synchronized(out) {
                                out.write(bytes)
                                out.flush()
                            }
                        } catch (_: Exception) {
                            dropHostPeer(peerId)
                        }
                    }
                }
                result.success(emptyMap<String, Any?>())
            }
            "stopBluetoothHost" -> {
                stopBluetoothHost()
                result.success(emptyMap<String, Any?>())
            }
            "startBluetoothDiscovery" -> startBluetoothDiscovery(result)
            "stopBluetoothDiscovery" -> {
                stopBluetoothDiscovery()
                result.success(emptyMap<String, Any?>())
            }
            "connectBluetoothHost" -> connectBluetoothHost(call, result)
            "clientSend" -> {
                val payload = call.argument<String>("payload") ?: ""
                thread {
                    try {
                        clientOut?.let { out ->
                            synchronized(out) {
                                out.write((payload + "\n").toByteArray(Charsets.UTF_8))
                                out.flush()
                            }
                        }
                    } catch (_: Exception) {
                        disconnectClientInternal()
                    }
                }
                result.success(emptyMap<String, Any?>())
            }
            "disconnectBluetoothClient" -> {
                disconnectClientInternal()
                result.success(emptyMap<String, Any?>())
            }
            else -> result.notImplemented()
        }
    }

    private fun handleRequestPermissions(call: MethodCall, result: MethodChannel.Result) {
        val channel = call.argument<String>("channel") ?: "bluetooth"
        val needed = mutableListOf<String>()

        if (channel == "bluetooth") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                needed.add(Manifest.permission.BLUETOOTH_SCAN)
                needed.add(Manifest.permission.BLUETOOTH_CONNECT)
                needed.add(Manifest.permission.BLUETOOTH_ADVERTISE)
            } else {
                needed.add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        } else if (channel == "wifi_offline") {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                needed.add(Manifest.permission.NEARBY_WIFI_DEVICES)
            } else {
                needed.add(Manifest.permission.ACCESS_FINE_LOCATION)
            }
        }

        val missing = needed.filter {
            ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }
        if (missing.isEmpty()) {
            result.success(true)
            return
        }
        pendingPermResult = result
        ActivityCompat.requestPermissions(activity, missing.toTypedArray(), PERMISSION_REQ_CODE)
    }

    @SuppressLint("MissingPermission")
    private fun ensureWifiDirectGroup() {
        try {
            if (wifiP2pManager == null) {
                wifiP2pManager = activity.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
                wifiP2pChannel = wifiP2pManager?.initialize(activity, Looper.getMainLooper(), null)
            }
            val ch = wifiP2pChannel ?: return
            wifiP2pManager?.createGroup(ch, null)
        } catch (_: Exception) {}
    }

    @SuppressLint("MissingPermission")
    private fun discoverWifiDirectPeers() {
        try {
            if (wifiP2pManager == null) {
                wifiP2pManager = activity.getSystemService(Context.WIFI_P2P_SERVICE) as? WifiP2pManager
                wifiP2pChannel = wifiP2pManager?.initialize(activity, Looper.getMainLooper(), null)
            }
            val ch = wifiP2pChannel ?: return
            wifiP2pManager?.discoverPeers(ch, null)
        } catch (_: Exception) {}
    }

    @SuppressLint("MissingPermission")
    private fun removeWifiDirectGroup() {
        try {
            val ch = wifiP2pChannel ?: return
            wifiP2pManager?.removeGroup(ch, null)
        } catch (_: Exception) {}
    }

    @SuppressLint("MissingPermission")
    private fun startBluetoothHost(call: MethodCall, result: MethodChannel.Result) {
        stopBluetoothHost()
        val adapter = btAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("BT_OFF", "البلوتوث غير مفعل على الجهاز", null)
            return
        }
        try {
            val srv = adapter.listenUsingInsecureRfcommWithServiceRecord(SERVICE_NAME, SERVICE_UUID)
            serverSocket = srv
            val devName = try { adapter.name ?: "Android" } catch (_: Exception) { "Android" }

            thread(name = "DominoBtAccept") {
                var seq = 1
                while (serverSocket === srv) {
                    try {
                        val sock = srv.accept() ?: break
                        val peerId = "bt_${seq++}_${sock.remoteDevice?.address ?: ""}"
                        hostPeerSockets[peerId] = sock
                        hostPeers[peerId] = sock.outputStream
                        emit(mapOf("role" to "host", "type" to "peerConnected", "peerId" to peerId))
                        listenHostPeer(peerId, sock)
                    } catch (_: Exception) {
                        break
                    }
                }
            }

            result.success(
                mapOf(
                    "roomCode" to devName,
                    "deviceName" to devName
                )
            )
        } catch (e: Exception) {
            result.error("BT_HOST_ERR", e.message, null)
        }
    }

    private fun listenHostPeer(peerId: String, sock: BluetoothSocket) {
        thread(name = "DominoBtPeer-$peerId") {
            try {
                val reader = BufferedReader(InputStreamReader(sock.inputStream, Charsets.UTF_8))
                while (sock.isConnected) {
                    val line = reader.readLine() ?: break
                    if (line.isNotEmpty()) {
                        emit(
                            mapOf(
                                "role" to "host",
                                "type" to "frame",
                                "peerId" to peerId,
                                "payload" to line
                            )
                        )
                    }
                }
            } catch (_: Exception) {
            } finally {
                dropHostPeer(peerId)
            }
        }
    }

    private fun dropHostPeer(peerId: String) {
        hostPeers.remove(peerId)
        val sock = hostPeerSockets.remove(peerId)
        if (sock != null) {
            try { sock.close() } catch (_: Exception) {}
            emit(mapOf("role" to "host", "type" to "peerDisconnected", "peerId" to peerId))
        }
    }

    private fun stopBluetoothHost() {
        try { serverSocket?.close() } catch (_: Exception) {}
        serverSocket = null
        for (peerId in hostPeerSockets.keys.toList()) {
            try { hostPeerSockets[peerId]?.close() } catch (_: Exception) {}
        }
        hostPeerSockets.clear()
        hostPeers.clear()
    }

    @SuppressLint("MissingPermission")
    private fun startBluetoothDiscovery(result: MethodChannel.Result) {
        stopBluetoothDiscovery()
        val adapter = btAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("BT_OFF", "البلوتوث غير مفعل على الجهاز", null)
            return
        }

        // Immediately surface bonded/paired phones so connecting is instant!
        try {
            adapter.bondedDevices?.forEach { dev ->
                val addr = dev.address ?: return@forEach
                val name = dev.name ?: addr
                emit(
                    mapOf(
                        "role" to "client",
                        "type" to "deviceFound",
                        "endpoint" to addr,
                        "roomCode" to name,
                        "hostName" to name
                    )
                )
            }
        } catch (_: Exception) {}

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action != BluetoothDevice.ACTION_FOUND) return
                val dev: BluetoothDevice? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE, BluetoothDevice::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(BluetoothDevice.EXTRA_DEVICE)
                }
                val addr = dev?.address ?: return
                val name = try { dev.name ?: addr } catch (_: Exception) { addr }
                emit(
                    mapOf(
                        "role" to "client",
                        "type" to "deviceFound",
                        "endpoint" to addr,
                        "roomCode" to name,
                        "hostName" to name
                    )
                )
            }
        }
        discoveryReceiver = receiver
        activity.registerReceiver(receiver, IntentFilter(BluetoothDevice.ACTION_FOUND))
        try { adapter.startDiscovery() } catch (_: Exception) {}
        result.success(emptyMap<String, Any?>())
    }

    @SuppressLint("MissingPermission")
    private fun stopBluetoothDiscovery() {
        try { btAdapter()?.cancelDiscovery() } catch (_: Exception) {}
        discoveryReceiver?.let {
            try { activity.unregisterReceiver(it) } catch (_: Exception) {}
        }
        discoveryReceiver = null
    }

    @SuppressLint("MissingPermission")
    private fun connectBluetoothHost(call: MethodCall, result: MethodChannel.Result) {
        stopBluetoothDiscovery()
        disconnectClientInternal()
        val address = call.argument<String>("endpoint") ?: ""
        val adapter = btAdapter()
        if (adapter == null || !adapter.isEnabled) {
            result.error("BT_OFF", "البلوتوث غير مفعل على الجهاز", null)
            return
        }

        thread(name = "DominoBtConnect") {
            try {
                val device = adapter.getRemoteDevice(address)
                val sock = device.createInsecureRfcommSocketToServiceRecord(SERVICE_UUID)
                sock.connect()
                clientSocket = sock
                clientOut = sock.outputStream

                mainHandler.post { result.success(emptyMap<String, Any?>()) }

                val reader = BufferedReader(InputStreamReader(sock.inputStream, Charsets.UTF_8))
                while (sock.isConnected) {
                    val line = reader.readLine() ?: break
                    if (line.isNotEmpty()) {
                        emit(mapOf("role" to "client", "type" to "frame", "payload" to line))
                    }
                }
            } catch (e: Exception) {
                if (clientSocket == null) {
                    mainHandler.post { result.error("BT_CONN_ERR", e.message, null) }
                }
            } finally {
                disconnectClientInternal()
            }
        }
    }

    private fun disconnectClientInternal() {
        clientOut = null
        val sock = clientSocket
        clientSocket = null
        if (sock != null) {
            try { sock.close() } catch (_: Exception) {}
            emit(mapOf("role" to "client", "type" to "disconnected"))
        }
    }
}
