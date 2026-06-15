const {onCall, onRequest, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");

const geminiApiKey = defineSecret("GEMINI_API_KEY");
const openWeatherApiKey = defineSecret("OPENWEATHER_API_KEY");

const region = "asia-northeast1";
const geminiModel = "gemini-2.5-flash";
const geminiBaseUrl = "https://generativelanguage.googleapis.com/v1beta";
const weatherBaseUrl = "https://api.openweathermap.org/data/2.5/weather";

function onPublicCallable(options, handler) {
  return onRequest(
      {
        ...options,
        cors: true,
        invoker: "public",
      },
      async (req, res) => {
        try {
          if (req.method !== "POST") {
            throw new HttpsError(
                "invalid-argument",
                "Callable functions must be called with POST.",
            );
          }

          const result = await handler({
            data: req.body?.data ?? {},
            rawRequest: req,
          });
          res.status(200).json({result});
        } catch (error) {
          const httpsError = error instanceof HttpsError ?
            error :
            new HttpsError(
                "internal",
                error?.message || "Function request failed.",
            );

          res.status(httpsError.httpErrorCode.status).json({
            error: httpsError.toJSON(),
          });
        }
      },
  );
}

function assertSecret(value, name) {
  if (!value) {
    throw new HttpsError(
        "failed-precondition",
        `${name} is not configured in Firebase Functions secrets.`,
    );
  }
}

function assertNumber(value, name) {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    throw new HttpsError("invalid-argument", `${name} must be a finite number.`);
  }
}

function normalizeContents(contents) {
  if (!Array.isArray(contents) || contents.length === 0) {
    throw new HttpsError("invalid-argument", "contents must be a non-empty array.");
  }

  return contents.map((content) => {
    if (!content || !Array.isArray(content.parts) || content.parts.length === 0) {
      throw new HttpsError("invalid-argument", "Each content needs non-empty parts.");
    }

    const normalized = {
      role: content.role === "model" ? "model" : "user",
      parts: content.parts.map((part) => {
        if (typeof part.text === "string") {
          return {text: part.text};
        }

        if (
          part.inlineData &&
          typeof part.inlineData.mimeType === "string" &&
          typeof part.inlineData.data === "string"
        ) {
          return {
            inlineData: {
              mimeType: part.inlineData.mimeType,
              data: part.inlineData.data,
            },
          };
        }

        throw new HttpsError(
            "invalid-argument",
            "Parts must contain text or inlineData.",
        );
      }),
    };

    return normalized;
  });
}

async function callGemini(contents) {
  const apiKey = geminiApiKey.value();
  assertSecret(apiKey, "GEMINI_API_KEY");

  const response = await fetch(
      `${geminiBaseUrl}/models/${geminiModel}:generateContent?key=${apiKey}`,
      {
        method: "POST",
        headers: {"Content-Type": "application/json"},
        body: JSON.stringify({contents}),
      },
  );

  const bodyText = await response.text();
  let body;
  try {
    body = bodyText ? JSON.parse(bodyText) : {};
  } catch (error) {
    throw new HttpsError("internal", "Gemini returned invalid JSON.");
  }

  if (!response.ok) {
    const message = body.error?.message || "Gemini request failed.";
    throw new HttpsError("internal", message);
  }

  const text = (body.candidates || [])
      .flatMap((candidate) => candidate.content?.parts || [])
      .map((part) => part.text || "")
      .join("")
      .trim();

  return {text};
}

async function handleGenerateGeminiContent(request) {
  const contents = normalizeContents(request.data?.contents);
  return callGemini(contents);
}

async function handleGetCurrentWeather(request) {
  const lat = request.data?.lat;
  const lon = request.data?.lon;
  assertNumber(lat, "lat");
  assertNumber(lon, "lon");

  const apiKey = openWeatherApiKey.value();
  assertSecret(apiKey, "OPENWEATHER_API_KEY");

  const url = new URL(weatherBaseUrl);
  url.searchParams.set("lat", String(lat));
  url.searchParams.set("lon", String(lon));
  url.searchParams.set("appid", apiKey);
  url.searchParams.set("units", "metric");
  url.searchParams.set("lang", "ja");

  const response = await fetch(url);
  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    const message = data.message || "OpenWeather request failed.";
    throw new HttpsError("internal", message);
  }

  return data;
}

async function handleValidateOpenWeatherApiKey() {
  const apiKey = openWeatherApiKey.value();
  assertSecret(apiKey, "OPENWEATHER_API_KEY");

  const url = new URL(weatherBaseUrl);
  url.searchParams.set("lat", "35.6762");
  url.searchParams.set("lon", "139.6503");
  url.searchParams.set("appid", apiKey);
  url.searchParams.set("units", "metric");

  const response = await fetch(url);
  const data = await response.json().catch(() => ({}));
  return {
    valid: response.ok,
    status: response.status,
    message: data.message || null,
  };
}

exports.generateGeminiContent = onCall(
    {region, secrets: [geminiApiKey], timeoutSeconds: 120, memory: "1GiB"},
    handleGenerateGeminiContent,
);

exports.getCurrentWeather = onCall(
    {region, secrets: [openWeatherApiKey], timeoutSeconds: 30},
    handleGetCurrentWeather,
);

exports.validateOpenWeatherApiKey = onCall(
    {region, secrets: [openWeatherApiKey], timeoutSeconds: 30},
    handleValidateOpenWeatherApiKey,
);

exports.generateGeminiContentPublic = onPublicCallable(
    {region, secrets: [geminiApiKey], timeoutSeconds: 120, memory: "1GiB"},
    handleGenerateGeminiContent,
);

exports.getCurrentWeatherPublic = onPublicCallable(
    {region, secrets: [openWeatherApiKey], timeoutSeconds: 30},
    handleGetCurrentWeather,
);

exports.validateOpenWeatherApiKeyPublic = onPublicCallable(
    {region, secrets: [openWeatherApiKey], timeoutSeconds: 30},
    handleValidateOpenWeatherApiKey,
);
