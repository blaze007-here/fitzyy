const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const defaultModel = "gemini-2.5-flash";

const responseSchema = {
  type: "OBJECT",
  properties: {
    food_name: { type: "STRING" },
    subtitle: { type: "STRING" },
    emoji: { type: "STRING" },
    rating: { type: "INTEGER" },
    rating_label: { type: "STRING" },
    confidence: { type: "NUMBER" },
    serving: { type: "STRING" },
    calories: { type: "INTEGER" },
    protein: { type: "NUMBER" },
    carbs: { type: "NUMBER" },
    fat: { type: "NUMBER" },
    fiber: { type: "NUMBER" },
    sodium: { type: "NUMBER" },
    ingredients: { type: "ARRAY", items: { type: "STRING" } },
    insight: { type: "STRING" },
  },
  required: [
    "food_name",
    "subtitle",
    "emoji",
    "rating",
    "rating_label",
    "confidence",
    "serving",
    "calories",
    "protein",
    "carbs",
    "fat",
    "fiber",
    "sodium",
    "ingredients",
    "insight",
  ],
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
    return json({ error: "GEMINI_API_KEY is not configured in Supabase." }, 500);
  }

  try {
    const body = await request.json();
    const imageBase64 = body?.imageBase64;
    const mimeType = body?.mimeType ?? "image/jpeg";
    if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
      return json({ error: "A food image is required." }, 400);
    }

    const model = Deno.env.get("GEMINI_MODEL") ?? defaultModel;
    const prompt = `Analyze the food in this photo for a calorie tracking app. Identify the main food or meal, estimate one visible serving, and provide approximate nutrition. Never claim laboratory-level accuracy. Return only JSON matching the supplied schema. Use numbers, not units, for nutrition values. rating is 0-100 and confidence is 0-1. If portions or ingredients are uncertain, say so in insight.`;
    const geminiResponse = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          contents: [
            {
              role: "user",
              parts: [
                { text: prompt },
                {
                  inlineData: {
                    mimeType,
                    data: imageBase64,
                  },
                },
              ],
            },
          ],
          generationConfig: {
            responseMimeType: "application/json",
            responseSchema,
            temperature: 0.2,
          },
        }),
      },
    );

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("Gemini analysis failed", errorText);
      let detail = errorText;
      try {
        const errorBody = JSON.parse(errorText);
        detail = errorBody?.error?.message ?? errorText;
      } catch (_) {
        // Keep the original response when Gemini did not return JSON.
      }
      return json(
        {
          error: "The vision model rejected the request.",
          detail: String(detail).slice(0, 500),
        },
        502,
      );
    }

    const result = await geminiResponse.json();
    const text = result?.candidates?.[0]?.content?.parts?.[0]?.text;
    if (typeof text !== "string") {
      return json({ error: "The vision model returned no analysis." }, 502);
    }

    const normalizedText = text
      .replace(/^```(?:json)?\s*/i, "")
      .replace(/\s*```$/i, "")
      .trim();
    return json(JSON.parse(normalizedText));
  } catch (error) {
    console.error("analyze-food error", error);
    return json({ error: "Could not analyze this image." }, 500);
  }
});
