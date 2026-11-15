const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (request.method !== "POST") {
    return json({ error: "Method not allowed" }, 405);
  }

  const apiKey = Deno.env.get("GEMINI_API_KEY");
  if (!apiKey) {
    return json({ error: "GEMINI_API_KEY is not configured" }, 500);
  }

  try {
    const body = await request.json();
    const imageBase64 = body?.imageBase64;
    const mimeType = body?.mimeType ?? "image/jpeg";

    if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
      return json({ error: "Image required" }, 400);
    }

    // Use v1 API (not v1beta) with gemini-1.5-flash-001
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1/models/gemini-1.5-flash-001:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [{
            parts: [
              {
                text: `Analyze this food and return JSON only:
{
  "food_name": "food name",
  "subtitle": "description",
  "emoji": "🍎",
  "rating": 85,
  "rating_label": "healthy",
  "confidence": 0.9,
  "serving": "1 serving",
  "calories": 200,
  "protein": 5.0,
  "carbs": 30.0,
  "fat": 8.0,
  "fiber": 3.0,
  "sodium": 100.0,
  "ingredients": ["list"],
  "insight": "tip"
}`
              },
              {
                inlineData: {
                  mimeType: mimeType,
                  data: imageBase64
                }
              }
            ]
          }]
        }),
      }
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("Gemini error:", errorText);
      return json({
        error: "Gemini API error",
        detail: errorText.slice(0, 300)
      }, 502);
    }

    const result = await geminiResponse.json();
    const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;

    if (!text) {
      return json({ error: "No response from Gemini" }, 502);
    }

    const cleanText = text.replace(/```json|```/g, "").trim();
    const data = JSON.parse(cleanText);

    return json(data);

  } catch (error) {
    console.error("Error:", error);
    return json({
      error: "Analysis failed",
      detail: String(error).slice(0, 200)
    }, 500);
  }
});