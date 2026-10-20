import "jsr:@supabase/functions-js/edge-runtime.d.ts";

const SOURCE_URL = "https://www.usdt.com.ve/api/v1/rates/current";
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Content-Type": "application/json; charset=utf-8",
  "Cache-Control": "public, max-age=60",
};

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "GET") {
    return new Response(JSON.stringify({ success: false, error: "Método no permitido" }), {
      status: 405,
      headers: { ...corsHeaders, Allow: "GET, OPTIONS" },
    });
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);

  try {
    const response = await fetch(SOURCE_URL, {
      method: "GET",
      headers: { Accept: "application/json" },
      signal: controller.signal,
    });

    if (!response.ok) throw new Error(`Proveedor respondió HTTP ${response.status}`);

    const payload = await response.json();
    const binance = payload?.data?.binance;
    const buyRate = Number(binance?.buy_rate);
    const sellRate = Number(binance?.sell_rate);
    const capturedAt = payload?.data?.captured_at;

    if (
      payload?.success !== true ||
      !Number.isFinite(buyRate) || buyRate <= 0 ||
      !Number.isFinite(sellRate) || sellRate <= 0 ||
      typeof capturedAt !== "string" || Number.isNaN(Date.parse(capturedAt))
    ) {
      throw new Error("La respuesta de la fuente no tiene una tasa válida");
    }

    return new Response(JSON.stringify({
      success: true,
      rate: buyRate,
      buy_rate: buyRate,
      sell_rate: sellRate,
      currency_pair: "USDT/VES",
      source: "usdt.com.ve (referencia Binance P2P)",
      source_url: "https://www.usdt.com.ve",
      captured_at: capturedAt,
      attribution_required: true,
      note: "Tasa referencial P2P; confirma el valor antes de aplicarlo a un pago.",
    }), { status: 200, headers: corsHeaders });
  } catch (error) {
    return new Response(JSON.stringify({
      success: false,
      error: "No se pudo obtener una tasa USDT actualizada.",
      detail: error instanceof Error ? error.message : "Error desconocido",
      manual_fallback_required: true,
    }), { status: 502, headers: { ...corsHeaders, "Cache-Control": "no-store" } });
  } finally {
    clearTimeout(timeout);
  }
});
