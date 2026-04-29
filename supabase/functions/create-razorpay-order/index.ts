// supabase/functions/create-razorpay-order/index.ts
// Supabase Edge Function — creates a Razorpay order and returns the order_id.
// Deploy: supabase functions deploy create-razorpay-order --no-verify-jwt
// Secrets: supabase secrets set RAZORPAY_KEY_ID=rzp_live_... RAZORPAY_KEY_SECRET=...

import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // ── Auth guard ─────────────────────────────────────────────────────────
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: "Missing Authorization header" }),
        { status: 401, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Parse body ─────────────────────────────────────────────────────────
    const body = await req.json();
    const amountInr: number = Number(body.amount_inr ?? 0);
    const artworkId: string = String(body.artwork_id ?? "");
    const receipt: string = String(
      body.receipt ?? `artyug_${artworkId.substring(0, 20)}_${Date.now()}`
    );

    if (!amountInr || amountInr <= 0) {
      return new Response(
        JSON.stringify({ error: "amount_inr must be a positive number" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Razorpay credentials ───────────────────────────────────────────────
    const keyId = Deno.env.get("RAZORPAY_KEY_ID");
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET");

    if (!keyId || !keySecret) {
      return new Response(
        JSON.stringify({ error: "RAZORPAY_KEY_ID / RAZORPAY_KEY_SECRET not set in Edge Function secrets" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Create Razorpay order via REST API ─────────────────────────────────
    // Amount must be in paise (INR × 100)
    const amountPaise = Math.round(amountInr * 100);
    const basicAuth = btoa(`${keyId}:${keySecret}`);

    const rzRes = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        Authorization: `Basic ${basicAuth}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        amount: amountPaise,
        currency: "INR",
        receipt: receipt.substring(0, 40), // Razorpay receipt max 40 chars
        notes: {
          artwork_id: artworkId,
          source: "artyug_flutter",
        },
      }),
    });

    const rzData = await rzRes.json();

    if (!rzRes.ok) {
      console.error("[create-razorpay-order] Razorpay API error:", rzData);
      return new Response(
        JSON.stringify({
          error: rzData?.error?.description ?? "Razorpay order creation failed",
          razorpay_code: rzData?.error?.code,
        }),
        { status: 502, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // ── Return order details to Flutter ──────────────────────────────────
    return new Response(
      JSON.stringify({
        order_id: rzData.id,           // e.g. "order_XXXXXXXXXXXX"
        amount: rzData.amount,          // in paise
        amount_inr: amountInr,
        currency: rzData.currency,
        receipt: rzData.receipt,
        key_id: keyId,                  // public key — safe to return to client
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (err) {
    console.error("[create-razorpay-order] Unexpected error:", err);
    return new Response(
      JSON.stringify({ error: "Internal server error", detail: String(err) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
