package com.example.flutter_application_1

import android.annotation.SuppressLint
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.content.Context
import android.os.Build
import android.telephony.CellInfo
import android.telephony.CellInfoCdma
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoTdscdma
import android.telephony.CellInfoWcdma
import android.telephony.CellSignalStrength
import android.telephony.CellSignalStrengthCdma
import android.telephony.CellSignalStrengthGsm
import android.telephony.CellSignalStrengthLte
import android.telephony.CellSignalStrengthTdscdma
import android.telephony.CellSignalStrengthWcdma
import android.telephony.SignalStrength
import android.telephony.ServiceState
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	companion object {
		private const val CHANNEL = "com.sigaptel/network_metrics"
	}

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"getSignalMetrics" -> getSignalMetrics(result)
					else -> result.notImplemented()
				}
			}
	}

	@SuppressLint("MissingPermission")
	private fun getSignalMetrics(result: MethodChannel.Result) {
		val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
		val connectivityManager = getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
		if (telephonyManager == null) {
			result.success(emptyMetrics())
			return
		}

		try {
			// On dual-SIM devices, use the TelephonyManager scoped to the
			// default DATA subscription so we read the SIM with active internet.
			val dataTm = getDataSimTelephonyManager(telephonyManager)
			val hasActiveSim = hasActiveSim(dataTm)

			val serviceState = dataTm.serviceState
			val inService = serviceState?.state == ServiceState.STATE_IN_SERVICE
			val dataConnected = dataTm.dataState == TelephonyManager.DATA_CONNECTED
			val validatedCellularInternet = isValidatedCellularInternet(connectivityManager)
			val providerName = resolveProviderName(dataTm)

			if (!hasActiveSim || !inService) {
				result.success(
					emptyMetrics(
						inService = inService,
						dataConnected = dataConnected,
						validatedCellularInternet = validatedCellularInternet,
						providerName = providerName,
						networkType = null,
					)
				)
				return
			}

			val dataNetworkType = resolveDataNetworkType(dataTm)
			val allCells = dataTm.allCellInfo
			val fromCellInfo = extractSignalMetricsFromCellInfo(allCells)
			val fromSignalStrength = extractSignalMetricsFromSignalStrength(
				signalStrength = dataTm.signalStrength,
				fallbackNetworkType = dataNetworkType,
			)
			val signalMetrics = chooseBetterSignalMetrics(fromCellInfo, fromSignalStrength)

			if (signalMetrics.rsrp == null && signalMetrics.rsrq == null && signalMetrics.sinr == null && signalMetrics.rssi == null) {
				result.success(
					emptyMetrics(
						inService = inService,
						dataConnected = dataConnected,
						validatedCellularInternet = validatedCellularInternet,
						providerName = providerName,
						networkType = signalMetrics.networkType,
					)
				)
				return
			}

			result.success(
				mapOf(
					"rsrp" to signalMetrics.rsrp,
					"rsrq" to signalMetrics.rsrq,
					"rssi" to signalMetrics.rssi,
					"sinr" to signalMetrics.sinr,
					"inService" to inService,
					"dataConnected" to dataConnected,
					"validatedCellularInternet" to validatedCellularInternet,
					"providerName" to providerName,
					"networkType" to signalMetrics.networkType,
				)
			)
		} catch (_: SecurityException) {
			result.success(emptyMetrics())
		} catch (e: Exception) {
			result.error("SIGNAL_READ_ERROR", e.message, null)
		}
	}

	private data class SignalMetricsResult(
		val rsrp: Int?,
		val rsrq: Int?,
		val sinr: Int?,
		val rssi: Int?,
		val networkType: String?,
	)

	private data class Candidate(
		val priority: Int,
		val score: Int,
		val metrics: SignalMetricsResult,
	)

	private fun extractSignalMetricsFromCellInfo(allCells: List<CellInfo>?): SignalMetricsResult {
		if (allCells.isNullOrEmpty()) {
			return SignalMetricsResult(null, null, null, null, null)
		}

		var bestRegistered: Candidate? = null
		var bestAny: Candidate? = null

		for (cell in allCells) {
			val candidate = toCandidate(cell) ?: continue

			if (cell.isRegistered) {
				if (bestRegistered == null || candidate.score > bestRegistered.score) {
					bestRegistered = candidate
				}
			} else {
				if (bestAny == null || candidate.score > bestAny.score) {
					bestAny = candidate
				}
			}
		}

		return bestRegistered?.metrics
			?: bestAny?.metrics
			?: SignalMetricsResult(null, null, null, null, null)
	}

	private fun extractSignalMetricsFromSignalStrength(
		signalStrength: SignalStrength?,
		fallbackNetworkType: String?,
	): SignalMetricsResult {
		if (signalStrength == null) {
			return SignalMetricsResult(null, null, null, null, fallbackNetworkType)
		}

		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
			val candidates = signalStrength.cellSignalStrengths
				.mapNotNull { toCandidate(it, false) }
			if (candidates.isNotEmpty()) {
				val best = candidates.maxByOrNull { it.score }
				if (best != null) {
					return best.metrics
				}
			}
		}

		val dbm = sanitizeRssi(readSignalStrengthDbmCompat(signalStrength))
		return SignalMetricsResult(
			rsrp = dbm,
			rsrq = null,
			sinr = null,
			rssi = dbm,
			networkType = fallbackNetworkType,
		)
	}

	private fun chooseBetterSignalMetrics(
		first: SignalMetricsResult,
		second: SignalMetricsResult,
	): SignalMetricsResult {
		val firstScore = metricsScore(first)
		val secondScore = metricsScore(second)
		return if (firstScore >= secondScore) first else second
	}

	private fun toCandidate(cell: CellInfo): Candidate? {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && cell is CellInfoNr) {
			val s = cell.cellSignalStrength
			val metrics = SignalMetricsResult(
				rsrp = sanitizeRsrp(readNrMetricCompat(s, "getSsRsrp")),
				rsrq = sanitizeRsrq(readNrMetricCompat(s, "getSsRsrq")),
				sinr = sanitizeSinr(readNrMetricCompat(s, "getSsSinr")),
				rssi = sanitizeRssi(s.dbm),
				networkType = "NR/5G",
			)
			return Candidate(
				priority = 60,
				score = candidateScore(metrics, isRegistered = cell.isRegistered, priority = 60),
				metrics = metrics,
			)
		}

		if (cell is CellInfoLte) {
			val s: CellSignalStrengthLte = cell.cellSignalStrength
			val metrics = SignalMetricsResult(
				rsrp = sanitizeRsrp(s.rsrp),
				rsrq = sanitizeRsrq(s.rsrq),
				sinr = sanitizeSinr(s.rssnr),
				rssi = sanitizeRssi(s.rssi),
				networkType = "LTE",
			)
			return Candidate(
				priority = 50,
				score = candidateScore(metrics, isRegistered = cell.isRegistered, priority = 50),
				metrics = metrics,
			)
		}

		if (cell is CellInfoWcdma) {
			val dbm = sanitizeRssi(cell.cellSignalStrength.dbm)
			val metrics = SignalMetricsResult(
				rsrp = dbm,
				rsrq = null,
				sinr = null,
				rssi = dbm,
				networkType = "WCDMA/UMTS",
			)
			return Candidate(
				priority = 40,
				score = candidateScore(metrics, isRegistered = cell.isRegistered, priority = 40),
				metrics = metrics,
			)
		}

		if (cell is CellInfoTdscdma) {
			val dbm = sanitizeRssi(cell.cellSignalStrength.dbm)
			val metrics = SignalMetricsResult(
				rsrp = dbm,
				rsrq = null,
				sinr = null,
				rssi = dbm,
				networkType = "TDSCDMA",
			)
			return Candidate(
				priority = 35,
				score = candidateScore(metrics, isRegistered = cell.isRegistered, priority = 35),
				metrics = metrics,
			)
		}

		if (cell is CellInfoGsm) {
			val dbm = sanitizeRssi(cell.cellSignalStrength.dbm)
			val metrics = SignalMetricsResult(
				rsrp = dbm,
				rsrq = null,
				sinr = null,
				rssi = dbm,
				networkType = "GSM/EDGE",
			)
			return Candidate(
				priority = 30,
				score = candidateScore(metrics, isRegistered = cell.isRegistered, priority = 30),
				metrics = metrics,
			)
		}

		if (cell is CellInfoCdma) {
			val s: CellSignalStrengthCdma = cell.cellSignalStrength
			val cdmaDbm = sanitizeRssi(s.cdmaDbm)
			val evdoDbm = sanitizeRssi(s.evdoDbm)
			val bestDbm = bestDbm(cdmaDbm, evdoDbm)
			val metrics = SignalMetricsResult(
				rsrp = bestDbm,
				rsrq = null,
				sinr = null,
				rssi = bestDbm,
				networkType = "CDMA/EVDO",
			)
			return Candidate(
				priority = 20,
				score = candidateScore(metrics, isRegistered = cell.isRegistered, priority = 20),
				metrics = metrics,
			)
		}

		return null
	}

	private fun toCandidate(signal: CellSignalStrength, isRegistered: Boolean): Candidate? {
		if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && signal is android.telephony.CellSignalStrengthNr) {
			val metrics = SignalMetricsResult(
				rsrp = sanitizeRsrp(readNrMetricCompat(signal, "getSsRsrp")),
				rsrq = sanitizeRsrq(readNrMetricCompat(signal, "getSsRsrq")),
				sinr = sanitizeSinr(readNrMetricCompat(signal, "getSsSinr")),
				rssi = sanitizeRssi(signal.dbm),
				networkType = "NR/5G",
			)
			return Candidate(
				priority = 60,
				score = candidateScore(metrics, isRegistered = isRegistered, priority = 60),
				metrics = metrics,
			)
		}

		if (signal is CellSignalStrengthLte) {
			val metrics = SignalMetricsResult(
				rsrp = sanitizeRsrp(signal.rsrp),
				rsrq = sanitizeRsrq(signal.rsrq),
				sinr = sanitizeSinr(signal.rssnr),
				rssi = sanitizeRssi(signal.rssi),
				networkType = "LTE",
			)
			return Candidate(
				priority = 50,
				score = candidateScore(metrics, isRegistered = isRegistered, priority = 50),
				metrics = metrics,
			)
		}

		if (signal is CellSignalStrengthWcdma) {
			val dbm = sanitizeRssi(signal.dbm)
			val metrics = SignalMetricsResult(dbm, null, null, dbm, "WCDMA/UMTS")
			return Candidate(
				priority = 40,
				score = candidateScore(metrics, isRegistered = isRegistered, priority = 40),
				metrics = metrics,
			)
		}

		if (signal is CellSignalStrengthTdscdma) {
			val dbm = sanitizeRssi(signal.dbm)
			val metrics = SignalMetricsResult(dbm, null, null, dbm, "TDSCDMA")
			return Candidate(
				priority = 35,
				score = candidateScore(metrics, isRegistered = isRegistered, priority = 35),
				metrics = metrics,
			)
		}

		if (signal is CellSignalStrengthGsm) {
			val dbm = sanitizeRssi(signal.dbm)
			val metrics = SignalMetricsResult(dbm, null, null, dbm, "GSM/EDGE")
			return Candidate(
				priority = 30,
				score = candidateScore(metrics, isRegistered = isRegistered, priority = 30),
				metrics = metrics,
			)
		}

		if (signal is CellSignalStrengthCdma) {
			val cdmaDbm = sanitizeRssi(signal.cdmaDbm)
			val evdoDbm = sanitizeRssi(signal.evdoDbm)
			val dbm = bestDbm(cdmaDbm, evdoDbm)
			val metrics = SignalMetricsResult(dbm, null, null, dbm, "CDMA/EVDO")
			return Candidate(
				priority = 20,
				score = candidateScore(metrics, isRegistered = isRegistered, priority = 20),
				metrics = metrics,
			)
		}

		return null
	}

	private fun resolveDataNetworkType(telephonyManager: TelephonyManager): String? {
		return when (telephonyManager.dataNetworkType) {
			TelephonyManager.NETWORK_TYPE_NR -> "NR/5G"
			TelephonyManager.NETWORK_TYPE_LTE -> "LTE"
			TelephonyManager.NETWORK_TYPE_HSPAP,
			TelephonyManager.NETWORK_TYPE_HSDPA,
			TelephonyManager.NETWORK_TYPE_HSUPA,
			TelephonyManager.NETWORK_TYPE_UMTS -> "WCDMA/UMTS"
			TelephonyManager.NETWORK_TYPE_TD_SCDMA -> "TDSCDMA"
			TelephonyManager.NETWORK_TYPE_GSM,
			TelephonyManager.NETWORK_TYPE_GPRS,
			TelephonyManager.NETWORK_TYPE_EDGE -> "GSM/EDGE"
			TelephonyManager.NETWORK_TYPE_CDMA,
			TelephonyManager.NETWORK_TYPE_EVDO_0,
			TelephonyManager.NETWORK_TYPE_EVDO_A,
			TelephonyManager.NETWORK_TYPE_EVDO_B,
			TelephonyManager.NETWORK_TYPE_1xRTT,
			TelephonyManager.NETWORK_TYPE_EHRPD -> "CDMA/EVDO"
			else -> null
		}
	}

	private fun bestDbm(a: Int?, b: Int?): Int? {
		if (a == null) {
			return b
		}
		if (b == null) {
			return a
		}
		return if (a > b) a else b
	}

	private fun readNrMetricCompat(signal: Any, getterName: String): Int {
		return try {
			val method = signal.javaClass.getMethod(getterName)
			(method.invoke(signal) as? Int) ?: Int.MAX_VALUE
		} catch (_: Exception) {
			Int.MAX_VALUE
		}
	}

	private fun readSignalStrengthDbmCompat(signalStrength: SignalStrength): Int {
		return try {
			val method = signalStrength.javaClass.getMethod("getDbm")
			(method.invoke(signalStrength) as? Int) ?: Int.MAX_VALUE
		} catch (_: Exception) {
			Int.MAX_VALUE
		}
	}

	@SuppressLint("MissingPermission")
	private fun getDataSimTelephonyManager(telephonyManager: TelephonyManager): TelephonyManager {
		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) {
			return telephonyManager
		}
		return try {
			val dataSubId = SubscriptionManager.getDefaultDataSubscriptionId()
			if (dataSubId == SubscriptionManager.INVALID_SUBSCRIPTION_ID) {
				telephonyManager
			} else {
				telephonyManager.createForSubscriptionId(dataSubId)
			}
		} catch (_: Exception) {
			telephonyManager
		}
	}

	@SuppressLint("MissingPermission")
	private fun hasActiveSim(telephonyManager: TelephonyManager): Boolean {
		val simState = telephonyManager.simState
		if (simState == TelephonyManager.SIM_STATE_ABSENT || simState == TelephonyManager.SIM_STATE_UNKNOWN) {
			return false
		}

		if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP_MR1) {
			return true
		}

		return try {
			val subscriptionManager = getSystemService(Context.TELEPHONY_SUBSCRIPTION_SERVICE) as? SubscriptionManager
			val activeSubscriptions = subscriptionManager?.activeSubscriptionInfoList
			!activeSubscriptions.isNullOrEmpty()
		} catch (_: Exception) {
			true
		}
	}

	private fun resolveProviderName(telephonyManager: TelephonyManager): String? {
		val networkName = telephonyManager.networkOperatorName?.trim()
		if (!networkName.isNullOrEmpty()) {
			return networkName
		}

		val simName = telephonyManager.simOperatorName?.trim()
		return if (simName.isNullOrEmpty()) null else simName
	}

	private fun isValidatedCellularInternet(connectivityManager: ConnectivityManager?): Boolean {
		if (connectivityManager == null) {
			return false
		}

		val network = connectivityManager.activeNetwork ?: return false
		val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false

		return capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) &&
			capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET) &&
			capabilities.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED)
	}

	private fun sanitizeRsrp(value: Int): Int? {
		if (value == Int.MAX_VALUE) {
			return null
		}
		if (value == 0) {
			return null
		}
		if (value < -180 || value > -40) {
			return null
		}
		return value
	}

	private fun sanitizeRsrq(value: Int): Int? {
		if (value == Int.MAX_VALUE || value == 0) {
			return null
		}
		if (value < -50 || value > -1) {
			return null
		}
		return value
	}

	private fun sanitizeSinr(value: Int): Int? {
		if (value == Int.MAX_VALUE) {
			return null
		}
		if (value < -300 || value > 400) {
			return null
		}
		return value
	}

	private fun sanitizeRssi(value: Int): Int? {
		if (value == Int.MAX_VALUE || value == 0) {
			return null
		}
		if (value < -140 || value > -20) {
			return null
		}
		return value
	}

	private fun metricsScore(metrics: SignalMetricsResult): Int {
		var score = 0
		if (metrics.rsrp != null) score += 40
		if (metrics.rsrq != null) score += 25
		if (metrics.sinr != null) score += 15
		if (metrics.rssi != null) score += 10
		score += when (metrics.networkType) {
			"NR/5G" -> 25
			"LTE" -> 20
			"WCDMA/UMTS" -> 12
			"TDSCDMA" -> 10
			"GSM/EDGE" -> 8
			"CDMA/EVDO" -> 6
			else -> 0
		}
		val anchor = metrics.rsrp ?: metrics.rssi
		if (anchor != null) {
			score += (anchor + 140).coerceIn(0, 70)
		}
		return score
	}

	private fun candidateScore(metrics: SignalMetricsResult, isRegistered: Boolean, priority: Int): Int {
		val registeredBonus = if (isRegistered) 120 else 0
		return metricsScore(metrics) + registeredBonus + priority
	}

	private fun emptyMetrics(
		inService: Boolean = false,
		dataConnected: Boolean = false,
		validatedCellularInternet: Boolean = false,
		providerName: String? = null,
		networkType: String? = null,
	): Map<String, Any?> {
		return mapOf(
			"rsrp" to null,
			"rsrq" to null,
			"rssi" to null,
			"sinr" to null,
			"inService" to inService,
			"dataConnected" to dataConnected,
			"validatedCellularInternet" to validatedCellularInternet,
			"providerName" to providerName,
			"networkType" to networkType,
		)
	}
}
