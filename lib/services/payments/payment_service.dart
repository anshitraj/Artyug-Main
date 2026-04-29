library artyug.payment_service;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';

/// Payment Service — Razorpay (live), Dodo & Stripe (coming soon).
///
/// **Native flow (Android/iOS):**
///   1. Call [initiateRazorpayPayment] → creates order via `create-razorpay-order` Edge Function.
///   2. Opens native Razorpay checkout sheet.
///   3. Resolve/reject via [onPaymentSuccess] / [onPaymentError] callbacks.
///
/// **Web/Desktop:**
///   Falls back to opening the Razorpay hosted checkout URL in a browser tab.

enum PaymentGateway { razorpay, dodo, stripe, demo }

/// User-selectable live checkout rail (subset of [PaymentGateway]).
enum CheckoutPaymentMethod { razorpay, dodo, stripe }

class PaymentResult {
  final bool success;
  final String? orderId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? errorMessage;
  final PaymentGateway gateway;
  final double amount;
  final String currency;
  final String? hostedCheckoutUrl;

  const PaymentResult({
    required this.success,
    this.orderId,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.errorMessage,
    required this.gateway,
    required this.amount,
    required this.currency,
    this.hostedCheckoutUrl,
  });

  bool get isDemo => gateway == PaymentGateway.demo;
  bool get requiresWebRedirect =>
      (gateway == PaymentGateway.razorpay ||
          gateway == PaymentGateway.dodo ||
          gateway == PaymentGateway.stripe) &&
      hostedCheckoutUrl != null;
}

class PaymentService {
  static String defaultPaymentReturnUrl() {
    final base = AppConfig.publicSiteUrl;
    if (base != null && base.isNotEmpty) {
      final u = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
      return '$u/orders';
    }
    if (kIsWeb) {
      final o = Uri.base.origin;
      return '$o/orders';
    }
    return 'https://artyug.app/orders';
  }

  /// Only Razorpay is currently live. Dodo & Stripe are coming soon.
  static List<CheckoutPaymentMethod> availableCheckoutMethods() {
    final out = <CheckoutPaymentMethod>[];
    if (AppConfig.razorpayKeyId != null &&
        AppConfig.razorpayKeyId!.trim().isNotEmpty) {
      out.add(CheckoutPaymentMethod.razorpay);
    }
    // Dodo & Stripe are visible in UI as "Coming Soon" — not added here so
    // they cannot be selected as an active method.
    return out;
  }

  static PaymentGateway gatewayForMethod(CheckoutPaymentMethod m) {
    switch (m) {
      case CheckoutPaymentMethod.razorpay:
        return PaymentGateway.razorpay;
      case CheckoutPaymentMethod.dodo:
        return PaymentGateway.dodo;
      case CheckoutPaymentMethod.stripe:
        return PaymentGateway.stripe;
    }
  }

  static PaymentGateway resolveGateway({
    required bool runtimeLiveMode,
    required String currency,
    CheckoutPaymentMethod? selectedMethod,
  }) {
    if (!runtimeLiveMode) return PaymentGateway.demo;
    if (selectedMethod != null) {
      return gatewayForMethod(selectedMethod);
    }
    if (currency == 'INR' &&
        AppConfig.razorpayKeyId != null &&
        AppConfig.razorpayKeyId!.trim().isNotEmpty) {
      return PaymentGateway.razorpay;
    }
    return PaymentGateway.demo;
  }

  static String formatAmount(double amount, String currency) {
    switch (currency) {
      case 'INR':
        return '₹${amount.toStringAsFixed(0)}';
      case 'USD':
        return '\$${amount.toStringAsFixed(2)}';
      case 'SOL':
        return '${amount.toStringAsFixed(4)} SOL';
      default:
        return '${amount.toStringAsFixed(2)} $currency';
    }
  }

  static int toSmallestUnit(double amount, String currency) {
    switch (currency) {
      case 'INR':
      case 'USD':
        return (amount * 100).round();
      default:
        return amount.round();
    }
  }

  // ── Native Razorpay (Android / iOS) ──────────────────────────────────────

  /// Opens the native Razorpay payment sheet.
  ///
  /// Returns a [Completer] that resolves when the user completes or dismisses
  /// the payment. Callers should await [completer.future].
  ///
  /// Usage:
  /// ```dart
  /// final result = await PaymentService.openNativeRazorpay(
  ///   orderId: 'order_XXXXX',
  ///   amountPaise: 50000,   // ₹500
  ///   artworkTitle: 'My Painting',
  ///   contactEmail: user.email,
  ///   contactPhone: '+919876543210',
  /// );
  /// ```
  static Future<PaymentResult> openNativeRazorpay({
    required String orderId,
    required int amountPaise,
    required String artworkTitle,
    String? contactEmail,
    String? contactPhone,
  }) {
    final completer = Completer<PaymentResult>();
    final razorpay = Razorpay();

    void cleanUp() {
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse resp) {
      cleanUp();
      completer.complete(PaymentResult(
        success: true,
        razorpayOrderId: orderId,
        razorpayPaymentId: resp.paymentId,
        gateway: PaymentGateway.razorpay,
        amount: amountPaise / 100.0,
        currency: 'INR',
      ));
    });

    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse resp) {
      cleanUp();
      completer.complete(PaymentResult(
        success: false,
        razorpayOrderId: orderId,
        errorMessage: resp.message ?? 'Payment failed or cancelled',
        gateway: PaymentGateway.razorpay,
        amount: amountPaise / 100.0,
        currency: 'INR',
      ));
    });

    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (ExternalWalletResponse resp) {
      // External wallet selected — treat as pending (user will complete outside)
      cleanUp();
      completer.complete(PaymentResult(
        success: true,
        razorpayOrderId: orderId,
        errorMessage: 'External wallet: ${resp.walletName}',
        gateway: PaymentGateway.razorpay,
        amount: amountPaise / 100.0,
        currency: 'INR',
      ));
    });

    final options = <String, dynamic>{
      'key': AppConfig.razorpayKeyId,
      'order_id': orderId,
      'amount': amountPaise,
      'name': 'Artyug',
      'description': artworkTitle,
      'currency': 'INR',
      'prefill': <String, dynamic>{
        if (contactEmail != null) 'email': contactEmail,
        if (contactPhone != null) 'contact': contactPhone,
      },
      'theme': {'color': '#1C6EF2'},
      'send_sms_hash': true,
      'retry': {'enabled': true, 'max_count': 2},
    };

    razorpay.open(options);
    return completer.future;
  }

  /// Full Razorpay flow:
  ///   1. Call Edge Function to create order.
  ///   2. On native: open Razorpay sheet and await result.
  ///      On web/desktop: open hosted URL in browser.
  static Future<PaymentResult?> initiateRazorpayPayment({
    required String artworkId,
    required double amountInr,
    required String artworkTitle,
    String? contactEmail,
    String? contactPhone,
    String? receiptId,
  }) async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      if (session == null) return null;

      // Step 1: Create order via Edge Function (uses secret key server-side)
      final response = await client.functions.invoke(
        'create-razorpay-order',
        body: {
          'amount_inr': amountInr,
          'artwork_id': artworkId,
          if (receiptId != null) 'receipt': receiptId,
        },
      );

      if (response.status != 200) {
        final errBody = response.data is Map
            ? (response.data as Map)['error']
            : response.data?.toString();
        debugPrint('[PaymentService] Edge function error: $errBody');
        return null;
      }

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      final razorpayOrderId = data['order_id'] as String?;
      final amountPaise = (data['amount'] as num?)?.toInt() ?? (amountInr * 100).round();
      final keyId = data['key_id'] as String? ?? AppConfig.razorpayKeyId;

      if (razorpayOrderId == null) {
        debugPrint('[PaymentService] No order_id in Edge Function response');
        return null;
      }

      // Step 2: Open checkout
      if (!kIsWeb) {
        // Android / iOS — native Razorpay sheet
        return await openNativeRazorpay(
          orderId: razorpayOrderId,
          amountPaise: amountPaise,
          artworkTitle: artworkTitle,
          contactEmail: contactEmail,
          contactPhone: contactPhone,
        );
      } else {
        // Web / Desktop — open hosted Razorpay checkout URL
        final hostedUrl = data['hosted_url'] as String?;
        if (hostedUrl != null) {
          final uri = Uri.parse(hostedUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
          return PaymentResult(
            success: true,
            razorpayOrderId: razorpayOrderId,
            gateway: PaymentGateway.razorpay,
            amount: amountInr,
            currency: 'INR',
            hostedCheckoutUrl: hostedUrl,
          );
        }

        // Fallback: build Razorpay Standard Checkout URL manually
        final checkoutUri = Uri.https('rzp.io', '/l/${keyId}', {
          'amount': amountPaise.toString(),
          'currency': 'INR',
        });
        if (await canLaunchUrl(checkoutUri)) {
          await launchUrl(checkoutUri, mode: LaunchMode.externalApplication);
        }
        return PaymentResult(
          success: true,
          razorpayOrderId: razorpayOrderId,
          gateway: PaymentGateway.razorpay,
          amount: amountInr,
          currency: 'INR',
          hostedCheckoutUrl: checkoutUri.toString(),
        );
      }
    } catch (e) {
      debugPrint('[PaymentService] initiateRazorpayPayment failed: $e');
      return null;
    }
  }

  // ── Dodo Payments (Coming Soon) ────────────────────────────────────────────

  /// Dodo Payments hosted checkout — not yet live.
  /// UI shows "Coming Soon" badge.
  static Future<PaymentResult?> initiateDodoCheckout({
    required String artworkId,
    required String artworkTitle,
    required double amountInr,
    required Map<String, dynamic> billingAddress,
    String? returnUrl,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return null;

      final response = await client.functions.invoke(
        'create-dodo-checkout',
        body: {
          'artwork_id': artworkId,
          'artwork_title': artworkTitle,
          'amount_inr': amountInr,
          'return_url': returnUrl ?? defaultPaymentReturnUrl(),
          'billing_address': billingAddress,
          if ((AppConfig.dodoPaymentsApiKey ?? '').isNotEmpty)
            'api_key': AppConfig.dodoPaymentsApiKey,
          'metadata': {'artwork_id': artworkId, 'source': 'artyug_flutter'},
        },
      );

      if (response.status != 200) {
        debugPrint('[PaymentService] create-dodo-checkout error: ${response.data}');
        return null;
      }

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      final url = _pickHostedUrl(data);
      if (url == null) return null;

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: url));
      }

      return PaymentResult(
        success: true,
        gateway: PaymentGateway.dodo,
        amount: amountInr,
        currency: 'INR',
        hostedCheckoutUrl: url,
      );
    } catch (e) {
      debugPrint('[PaymentService] initiateDodoCheckout failed: $e');
      return null;
    }
  }

  // ── Stripe Checkout (Coming Soon) ──────────────────────────────────────────

  /// Stripe Checkout Session — not yet live.
  /// UI shows "Coming Soon" badge.
  static Future<PaymentResult?> initiateStripeCheckout({
    required String artworkId,
    required String artworkTitle,
    required double amountInr,
    required Map<String, dynamic> billingAddress,
    String? redirectUrl,
    String? cancelUrl,
  }) async {
    try {
      final client = Supabase.instance.client;
      if (client.auth.currentSession == null) return null;

      final ret = redirectUrl ?? defaultPaymentReturnUrl();
      final response = await client.functions.invoke(
        'create-stripe-checkout',
        body: {
          'artwork_id': artworkId,
          'artwork_title': artworkTitle,
          'amount_inr': amountInr,
          'success_url': ret,
          'cancel_url': cancelUrl ?? ret,
          'metadata': {
            'artwork_id': artworkId,
            'source': 'artyug_flutter',
            ...billingAddress.map((k, v) => MapEntry('addr_$k', v)),
          },
        },
      );

      if (response.status != 200) {
        debugPrint('[PaymentService] create-stripe-checkout: ${response.data}');
        return null;
      }

      final data = response.data is Map
          ? response.data as Map<String, dynamic>
          : jsonDecode(response.data.toString()) as Map<String, dynamic>;

      final url = _pickHostedUrl(data);
      if (url == null) return null;

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: url));
      }

      return PaymentResult(
        success: true,
        gateway: PaymentGateway.stripe,
        amount: amountInr,
        currency: 'INR',
        hostedCheckoutUrl: url,
      );
    } catch (e) {
      debugPrint('[PaymentService] initiateStripeCheckout failed: $e');
      return null;
    }
  }

  static String? _pickHostedUrl(Map<String, dynamic> data) {
    final stripeUrl = data['url'] as String?;
    if (stripeUrl != null && stripeUrl.isNotEmpty) return stripeUrl;
    final direct = data['hosted_url'] as String?;
    if (direct != null && direct.isNotEmpty) return direct;
    final checkoutUrl = data['checkout_url'] as String?;
    if (checkoutUrl != null && checkoutUrl.isNotEmpty) return checkoutUrl;
    final nested = data['data'];
    if (nested is Map) {
      final h = nested['hosted_url'] as String?;
      if (h != null && h.isNotEmpty) return h;
      final u = nested['url'] as String?;
      if (u != null && u.isNotEmpty) return u;
    }
    return null;
  }

  // ── Demo Payment ───────────────────────────────────────────────────────────

  static Future<PaymentResult> demoPayment({
    required String artworkId,
    required double amount,
    required String currency,
  }) async {
    await Future.delayed(const Duration(seconds: 2));
    return PaymentResult(
      success: true,
      orderId:
          'DEMO_${DateTime.now().millisecondsSinceEpoch}_${artworkId.substring(0, artworkId.length > 8 ? 8 : artworkId.length)}',
      gateway: PaymentGateway.demo,
      amount: amount,
      currency: currency,
    );
  }

  // ── Guards ─────────────────────────────────────────────────────────────────

  static String? blockMessageForLiveMode(bool runtimeLiveMode) {
    final reason = AppConfig.livePaymentBlockReasonWhenLive(runtimeLiveMode);
    if (reason == null) return null;
    return 'Live payments are not configured ($reason). Add RAZORPAY_KEY_ID to .env.';
  }

  static String? get razorpayBlockMessage {
    if (AppConfig.razorpayKeyId == null ||
        AppConfig.razorpayKeyId!.trim().isEmpty) {
      return 'RAZORPAY_KEY_ID is not set';
    }
    return null;
  }
}

