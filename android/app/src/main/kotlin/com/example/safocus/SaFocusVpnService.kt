package com.example.safocus

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetAddress
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.ConcurrentLinkedDeque
import java.util.concurrent.atomic.AtomicBoolean
import kotlinx.coroutines.*

/**
 * SaFocusVpnService — Production-quality DNS-only local VPN.
 *
 * Design (modeled after Blokada / Adguard DNS local VPN):
 *
 *  1. A TUN interface is created with a FAKE DNS server IP (10.33.33.2).
 *     Only that single /32 IP is routed through the TUN. Zero real internet
 *     traffic is affected — HTTP, HTTPS, QUIC, WebSocket, etc. all use the
 *     normal network interface and never touch the VPN.
 *
 *  2. Android's DNS resolver sends UDP queries to 10.33.33.2:53.
 *     These arrive in the TUN file descriptor as raw IPv4 packets.
 *
 *  3. Each DNS query is dispatched to a coroutine on [Dispatchers.IO]:
 *     - If the domain is in the block list -> immediate NXDOMAIN response.
 *     - If the domain is in the local cache and not expired -> cached response.
 *     - Otherwise -> forward to upstream DNS (1.1.1.1, fallback 8.8.8.8)
 *       via a protect()-ed socket (bypasses the TUN), cache the result.
 *
 *  4. The DNS response is wrapped in a proper IPv4/UDP packet with a
 *     correctly computed IP header checksum and written back to the TUN.
 *
 * CRITICAL: Previous implementations had a missing IP header checksum bug —
 * the kernel silently drops any packet written to TUN with an invalid
 * checksum, causing 100% DNS failure. This version computes it correctly.
 */
class SaFocusVpnService : VpnService() {

    companion object {
        private const val TAG = "SaFocusVPN"

        const val ACTION_START = "SAFOCUS_VPN_START"
        const val ACTION_STOP  = "SAFOCUS_VPN_STOP"
        const val EXTRA_DOMAINS = "blocked_domains"
        const val NOTIF_CHANNEL = "safocus_vpn"
        const val NOTIF_ID = 9001

        // Fake TUN subnet — no real server exists at these IPs.
        private const val TUN_ADDR    = "10.33.33.1"
        private const val FAKE_DNS_IP = "10.33.33.2"

        // Upstream resolvers (tried in order)
        private const val UPSTREAM_1 = "1.1.1.1"
        private const val UPSTREAM_2 = "8.8.8.8"
        private const val DNS_TIMEOUT_MS = 3_000

        // Cache limits
        private const val CACHE_MAX = 500
        private const val DEFAULT_TTL = 60
        private const val MIN_TTL = 10
        private const val MAX_TTL = 86_400

        // Shared state (read by MainActivity)
        var pendingDomains: List<String> = emptyList()
        var blockedDomains: Set<String> = emptySet()
            private set

        // Blocked attempt accumulator — drained by MainActivity on request
        // Each entry: Pair(timestampMs, domain)
        private val _blockedAttempts = ConcurrentLinkedDeque<Pair<Long, String>>()
        private const val MAX_ATTEMPTS = 1000

        /** Returns all accumulated blocked attempts and clears the queue. */
        fun getAndClearBlockedAttempts(): List<Pair<Long, String>> {
            val result = mutableListOf<Pair<Long, String>>()
            while (true) {
                val entry = _blockedAttempts.pollFirst() ?: break
                result.add(entry)
            }
            return result
        }

        private fun recordBlockedAttempt(domain: String) {
            if (_blockedAttempts.size >= MAX_ATTEMPTS) {
                _blockedAttempts.pollFirst() // drop oldest
            }
            _blockedAttempts.addLast(Pair(System.currentTimeMillis(), domain))
        }
    }

    // ── Instance state ───────────────────────────────────────────────────

    private val running = AtomicBoolean(false)
    private var vpnFd: ParcelFileDescriptor? = null

    // Structured concurrency — all coroutines cancelled on stopVpn()
    private var serviceScope: CoroutineScope? = null

    // domain -> (dns response bytes, expiry epoch ms)
    private val dnsCache = ConcurrentHashMap<String, DnsCacheEntry>()
    private data class DnsCacheEntry(val payload: ByteArray, val expiresAt: Long)

    // ══════════════════════════════════════════════════════════════════════
    //  SERVICE LIFECYCLE
    // ══════════════════════════════════════════════════════════════════════

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopVpn()
                return START_NOT_STICKY
            }
            ACTION_START -> {
                blockedDomains = intent
                    .getStringArrayListExtra(EXTRA_DOMAINS)
                    ?.toSet() ?: emptySet()
                startVpn()
            }
        }
        return START_STICKY
    }

    override fun onRevoke() { stopVpn(); super.onRevoke() }
    override fun onDestroy() { stopVpn(); super.onDestroy() }

    // ══════════════════════════════════════════════════════════════════════
    //  START / STOP VPN
    // ══════════════════════════════════════════════════════════════════════

    private fun startVpn() {
        if (running.getAndSet(true)) return

        createNotificationChannel()
        startForeground(NOTIF_ID, buildNotification())

        val builder = Builder()
            .setSession("SaFocus DNS")
            .addAddress(TUN_ADDR, 32)
            // Only this single fake IP is routed through TUN.
            // NO real internet traffic ever enters the tunnel.
            .addRoute(FAKE_DNS_IP, 32)
            // Android sends all DNS queries to this fake server.
            .addDnsServer(FAKE_DNS_IP)
            .setMtu(1500)
            .setBlocking(true)

        vpnFd = try {
            builder.establish()
        } catch (e: Exception) {
            Log.e(TAG, "establish() failed", e)
            running.set(false)
            return
        }

        val pfd = vpnFd ?: run {
            Log.e(TAG, "establish() returned null")
            running.set(false)
            return
        }

        serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        serviceScope?.launch { packetLoop(pfd) }
    }

    private fun stopVpn() {
        if (!running.getAndSet(false)) return
        serviceScope?.cancel()
        serviceScope = null
        dnsCache.clear()
        try { vpnFd?.close() } catch (_: Exception) {}
        vpnFd = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    // ══════════════════════════════════════════════════════════════════════
    //  PACKET LOOP (runs on Dispatchers.IO)
    // ══════════════════════════════════════════════════════════════════════

    private suspend fun packetLoop(pfd: ParcelFileDescriptor) = withContext(Dispatchers.IO) {
        val input  = FileInputStream(pfd.fileDescriptor)
        val output = FileOutputStream(pfd.fileDescriptor)
        val buf = ByteArray(32_767)

        while (running.get() && isActive) {
            // Blocking read — wakes up when a packet arrives or fd is closed.
            val len = try { input.read(buf) } catch (_: Exception) { break }
            if (len < 28) continue                          // too short for IPv4 + UDP

            val ipHdrLen = (buf[0].toInt() and 0x0F) * 4   // variable-length IP header
            if (len < ipHdrLen + 8) continue                // incomplete UDP header

            val proto = buf[9].toInt() and 0xFF
            if (proto != 17) continue                       // not UDP -> discard

            // UDP dest port (bytes 2-3 of UDP header)
            val dstPort = ((buf[ipHdrLen + 2].toInt() and 0xFF) shl 8) or
                           (buf[ipHdrLen + 3].toInt() and 0xFF)
            if (dstPort != 53) continue                     // not DNS -> discard

            // Process each DNS query in its own coroutine
            val packet = buf.copyOf(len)
            launch {
                try {
                    val response = processDns(packet)
                    if (response != null) {
                        synchronized(output) { output.write(response) }
                    }
                } catch (e: Exception) {
                    Log.w(TAG, "DNS error: ${e.message}")
                }
            }
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  DNS PROCESSING
    // ══════════════════════════════════════════════════════════════════════

    private fun processDns(ipPacket: ByteArray): ByteArray? {
        val ipHdrLen = (ipPacket[0].toInt() and 0x0F) * 4
        val dnsOffset = ipHdrLen + 8
        if (ipPacket.size <= dnsOffset) return null
        val dnsQuery = ipPacket.copyOfRange(dnsOffset, ipPacket.size)
        if (dnsQuery.size < 12) return null

        val domain = parseDomainName(dnsQuery)
            ?: return forwardAndCache(ipPacket, dnsQuery, null)

        // 1. Blocked?
        val blocked = blockedDomains.any { bd ->
            domain == bd || domain.endsWith(".$bd")
        }
        if (blocked) {
            Log.d(TAG, "BLOCKED: $domain")
            recordBlockedAttempt(domain)
            return buildNxdomain(ipPacket, dnsQuery)
        }

        // 2. Cached?
        val cached = dnsCache[domain]
        if (cached != null && cached.expiresAt > System.currentTimeMillis()) {
            val resp = cached.payload.copyOf()
            resp[0] = dnsQuery[0]   // patch transaction ID
            resp[1] = dnsQuery[1]
            return wrapDnsResponse(ipPacket, resp)
        }

        // 3. Forward to upstream
        return forwardAndCache(ipPacket, dnsQuery, domain)
    }

    private fun forwardAndCache(
        origIp: ByteArray,
        dnsQuery: ByteArray,
        domain: String?
    ): ByteArray? {
        val dnsResp = queryUpstream(UPSTREAM_1, dnsQuery)
            ?: queryUpstream(UPSTREAM_2, dnsQuery)
            ?: return null

        if (domain != null) {
            val ttl = extractMinTtl(dnsResp)
            if (dnsCache.size > CACHE_MAX) dnsCache.clear()
            dnsCache[domain] = DnsCacheEntry(
                payload   = dnsResp.copyOf(),
                expiresAt = System.currentTimeMillis() + ttl * 1000L
            )
        }

        return wrapDnsResponse(origIp, dnsResp)
    }

    private fun queryUpstream(server: String, query: ByteArray): ByteArray? {
        var sock: DatagramSocket? = null
        return try {
            sock = DatagramSocket()
            protect(sock)                     // CRITICAL: bypass TUN
            sock.soTimeout = DNS_TIMEOUT_MS
            val addr = InetAddress.getByName(server)
            sock.send(DatagramPacket(query, query.size, addr, 53))
            val buf = ByteArray(4096)
            val pkt = DatagramPacket(buf, buf.size)
            sock.receive(pkt)
            buf.copyOf(pkt.length)
        } catch (_: Exception) {
            null
        } finally {
            try { sock?.close() } catch (_: Exception) {}
        }
    }

    // ══════════════════════════════════════════════════════════════════════
    //  IPv4/UDP PACKET CONSTRUCTION  (with correct checksums!)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Wraps [dnsPayload] in a valid IPv4/UDP packet suitable for writing
     * to the TUN fd. Uses [origIpPacket] as a template (swapping IPs and
     * ports, fixing lengths, computing the IP header checksum).
     */
    private fun wrapDnsResponse(origIpPacket: ByteArray, dnsPayload: ByteArray): ByteArray {
        val ihl = (origIpPacket[0].toInt() and 0x0F) * 4
        val totalLen = ihl + 8 + dnsPayload.size
        val pkt = ByteArray(totalLen)

        // ── Copy & fix IP header ─────────────────────────────────────────
        System.arraycopy(origIpPacket, 0, pkt, 0, ihl)

        // Swap src <-> dst IP addresses
        System.arraycopy(origIpPacket, 16, pkt, 12, 4)   // orig dst -> new src
        System.arraycopy(origIpPacket, 12, pkt, 16, 4)   // orig src -> new dst

        // Total length
        pkt[2] = (totalLen ushr 8).toByte()
        pkt[3] = (totalLen and 0xFF).toByte()

        // TTL = 64
        pkt[8] = 64.toByte()

        // ── Compute IP header checksum ───────────────────────────────────
        // MUST be correct — the kernel validates it and silently drops
        // packets with wrong checksums written to TUN.
        pkt[10] = 0
        pkt[11] = 0
        val cksum = ipChecksum(pkt, 0, ihl)
        pkt[10] = (cksum ushr 8).toByte()
        pkt[11] = (cksum and 0xFF).toByte()

        // ── UDP header ───────────────────────────────────────────────────
        // Swap src <-> dst ports
        pkt[ihl]     = origIpPacket[ihl + 2]
        pkt[ihl + 1] = origIpPacket[ihl + 3]
        pkt[ihl + 2] = origIpPacket[ihl]
        pkt[ihl + 3] = origIpPacket[ihl + 1]

        // UDP length
        val udpLen = 8 + dnsPayload.size
        pkt[ihl + 4] = (udpLen ushr 8).toByte()
        pkt[ihl + 5] = (udpLen and 0xFF).toByte()

        // UDP checksum = 0 (optional for IPv4, RFC 768)
        pkt[ihl + 6] = 0
        pkt[ihl + 7] = 0

        // ── DNS payload ──────────────────────────────────────────────────
        System.arraycopy(dnsPayload, 0, pkt, ihl + 8, dnsPayload.size)

        return pkt
    }

    /** NXDOMAIN response for a blocked domain. */
    private fun buildNxdomain(origIpPacket: ByteArray, dnsQuery: ByteArray): ByteArray {
        val resp = dnsQuery.copyOf()
        resp[2] = (resp[2].toInt() or 0x80).toByte()                   // QR = 1 (response)
        resp[3] = (resp[3].toInt() and 0xF0 or 0x03).toByte()          // RCODE = NXDOMAIN
        return wrapDnsResponse(origIpPacket, resp)
    }

    // ══════════════════════════════════════════════════════════════════════
    //  IP CHECKSUM  (RFC 1071)
    // ══════════════════════════════════════════════════════════════════════

    /**
     * Standard Internet checksum: one's-complement of the one's-complement
     * sum of all 16-bit words. The checksum field itself must be zeroed
     * before calling this.
     */
    private fun ipChecksum(buf: ByteArray, off: Int, len: Int): Int {
        var sum = 0L
        var i = off
        val end = off + len
        while (i < end - 1) {
            sum += ((buf[i].toInt() and 0xFF) shl 8) or
                    (buf[i + 1].toInt() and 0xFF)
            i += 2
        }
        if (i < end) {
            sum += (buf[i].toInt() and 0xFF) shl 8
        }
        while (sum ushr 16 != 0L) {
            sum = (sum and 0xFFFF) + (sum ushr 16)
        }
        return sum.toInt().inv() and 0xFFFF
    }

    // ══════════════════════════════════════════════════════════════════════
    //  DNS PARSING
    // ══════════════════════════════════════════════════════════════════════

    /** Extracts the queried domain name from a raw DNS query payload. */
    private fun parseDomainName(dns: ByteArray): String? {
        if (dns.size < 13) return null
        val sb = StringBuilder()
        var i = 12    // skip DNS header (12 bytes)
        while (i < dns.size) {
            val labelLen = dns[i].toInt() and 0xFF
            if (labelLen == 0) break
            if (i + 1 + labelLen > dns.size) return null
            if (sb.isNotEmpty()) sb.append('.')
            sb.append(String(dns, i + 1, labelLen))
            i += 1 + labelLen
        }
        return if (sb.isNotEmpty()) sb.toString().lowercase() else null
    }

    /**
     * Extracts the minimum TTL from all resource records in a DNS response.
     * Returns [DEFAULT_TTL] if no records found. Clamps to [MIN_TTL]..[MAX_TTL].
     */
    private fun extractMinTtl(dns: ByteArray): Int {
        if (dns.size < 12) return DEFAULT_TTL

        val qdCount = dns.readU16(4)
        val anCount = dns.readU16(6)
        if (anCount == 0) return DEFAULT_TTL

        // Skip question section
        var i = 12
        repeat(qdCount) {
            i = skipName(dns, i)
            i += 4     // QTYPE (2) + QCLASS (2)
            if (i >= dns.size) return DEFAULT_TTL
        }

        // Read answer RR TTLs
        var minTtl = Int.MAX_VALUE
        repeat(anCount) {
            if (i >= dns.size) return@repeat
            i = skipName(dns, i)
            if (i + 10 > dns.size) return@repeat
            val ttl = ((dns[i + 4].toInt() and 0xFF) shl 24) or
                      ((dns[i + 5].toInt() and 0xFF) shl 16) or
                      ((dns[i + 6].toInt() and 0xFF) shl 8) or
                       (dns[i + 7].toInt() and 0xFF)
            val rdLen = dns.readU16(i + 8)
            if (ttl in 1 until minTtl) minTtl = ttl
            i += 10 + rdLen
        }

        return if (minTtl == Int.MAX_VALUE) DEFAULT_TTL
               else minTtl.coerceIn(MIN_TTL, MAX_TTL)
    }

    /** Skips a DNS name (handling label compression pointers). */
    private fun skipName(dns: ByteArray, start: Int): Int {
        var i = start
        while (i < dns.size) {
            val b = dns[i].toInt() and 0xFF
            if (b == 0) return i + 1                          // end-of-name
            if (b and 0xC0 == 0xC0) return i + 2              // compression pointer
            i += 1 + b
        }
        return dns.size
    }

    /** Read unsigned 16-bit value at [offset]. */
    private fun ByteArray.readU16(offset: Int): Int =
        ((this[offset].toInt() and 0xFF) shl 8) or
         (this[offset + 1].toInt() and 0xFF)

    // ══════════════════════════════════════════════════════════════════════
    //  FOREGROUND NOTIFICATION
    // ══════════════════════════════════════════════════════════════════════

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIF_CHANNEL,
                "SaFocus VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Escudo activo bloqueando sitios distractores"
            }
            getSystemService(NotificationManager::class.java)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): Notification {
        val openIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, NOTIF_CHANNEL)
            .setContentTitle("SaFocus — Escudo Activo")
            .setContentText("Bloqueando sitios distractores")
            .setSmallIcon(android.R.drawable.ic_lock_idle_lock)
            .setContentIntent(openIntent)
            .setOngoing(true)
            .build()
    }
}
