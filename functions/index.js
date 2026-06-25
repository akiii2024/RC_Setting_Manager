const {initializeApp} = require("firebase-admin/app");
const {getFirestore, Timestamp} = require("firebase-admin/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {defineSecret} = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

initializeApp();

const db = getFirestore();
const geminiApiKey = defineSecret("GEMINI_API_KEY");
const openWeatherApiKey = defineSecret("OPENWEATHER_API_KEY");

const region = "asia-northeast1";
const geminiModel = "gemini-2.5-flash";
const geminiBaseUrl = "https://generativelanguage.googleapis.com/v1beta";
const weatherBaseUrl = "https://api.openweathermap.org/data/2.5/weather";

const allowedImageMimeTypes = new Set([
  "image/jpeg",
  "image/png",
  "image/webp",
]);
const maxContents = 20;
const maxParts = 50;
const maxTextCharacters = 50000;
const maxInlineBytes = 8 * 1024 * 1024;
const maxTotalInlineBytes = 10 * 1024 * 1024;
const tenMinutesMs = 10 * 60 * 1000;
const oneHourMs = 60 * 60 * 1000;
const oneDayMs = 24 * oneHourMs;
const japanTimeOffsetMs = 9 * oneHourMs;
const geminiBurstLimit = 10;
const geminiDailyLimit = 20;

function assertSecret(value, name) {
  if (!value) {
    logger.error("A required Functions secret is not configured.", {name});
    throw new HttpsError(
        "failed-precondition",
        "The server is not configured for this operation.",
    );
  }
}

function requireAuthenticated(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }
  return uid;
}

function buildRateLimitStates(uid, limits, now) {
  return limits.map((limitConfig) => {
    const offsetMs = limitConfig.windowOffsetMs || 0;
    const windowId = Math.floor((now + offsetMs) / limitConfig.windowMs);
    const windowStartedAtMs =
      windowId * limitConfig.windowMs - offsetMs;
    const documentId = `${uid}_${limitConfig.action}_${windowId}`;

    return {
      ...limitConfig,
      reference: db.collection("_function_rate_limits").doc(documentId),
      windowStartedAtMs,
    };
  });
}

function geminiRateLimits() {
  return [
    {
      action: "gemini-burst",
      limit: geminiBurstLimit,
      windowMs: tenMinutesMs,
      message:
        "Gemini can be used up to 10 times every 10 minutes. " +
        "Please try again later.",
    },
    {
      action: "gemini-daily-jst",
      limit: geminiDailyLimit,
      windowMs: oneDayMs,
      windowOffsetMs: japanTimeOffsetMs,
      message:
        "The daily Gemini limit of 20 requests has been reached. " +
        "The limit resets at midnight Japan time.",
    },
  ];
}

function toRateLimitUsage(rateLimit, count, now) {
  const normalizedCount = typeof count === "number" ? count : 0;
  const resetAtMs = rateLimit.windowStartedAtMs + rateLimit.windowMs;

  return {
    action: rateLimit.action,
    limit: rateLimit.limit,
    used: normalizedCount,
    remaining: Math.max(0, rateLimit.limit - normalizedCount),
    resetAt: resetAtMs,
    retryAfterSeconds: Math.max(
        0,
        Math.ceil((resetAtMs - now) / 1000),
    ),
  };
}

function formatGeminiUsage(usages) {
  const burst = usages.find((usage) => usage.action === "gemini-burst");
  const daily = usages.find(
      (usage) => usage.action === "gemini-daily-jst",
  );

  return {
    burst,
    daily,
  };
}

async function getRateLimitUsages(request, limits) {
  const uid = requireAuthenticated(request);
  const now = Date.now();
  const rateLimits = buildRateLimitStates(uid, limits, now);
  const snapshots = await db.getAll(
      ...rateLimits.map((rateLimit) => rateLimit.reference),
  );

  return rateLimits.map((rateLimit, index) => {
    const snapshot = snapshots[index];
    const count = snapshot.exists ? snapshot.get("count") : 0;
    return toRateLimitUsage(rateLimit, count, now);
  });
}

async function enforceRateLimits(request, limits) {
  const uid = requireAuthenticated(request);
  const now = Date.now();
  const rateLimits = buildRateLimitStates(uid, limits, now);

  return db.runTransaction(async (transaction) => {
    const snapshots = await transaction.getAll(
        ...rateLimits.map((rateLimit) => rateLimit.reference),
    );

    for (let index = 0; index < rateLimits.length; index += 1) {
      const rateLimit = rateLimits[index];
      const snapshot = snapshots[index];
      const count = snapshot.exists ? snapshot.get("count") : 0;

      if (typeof count === "number" && count >= rateLimit.limit) {
        const usage = toRateLimitUsage(rateLimit, count, now);

        throw new HttpsError(
            "resource-exhausted",
            rateLimit.message ||
              "Too many requests. Please try again later.",
            {
              limit: rateLimit.limit,
              limitType: rateLimit.action,
              retryAfterSeconds: Math.max(1, usage.retryAfterSeconds),
            },
        );
      }
    }

    for (let index = 0; index < rateLimits.length; index += 1) {
      const rateLimit = rateLimits[index];
      const snapshot = snapshots[index];
      const count = snapshot.exists ? snapshot.get("count") : 0;

      transaction.set(rateLimit.reference, {
        uid,
        action: rateLimit.action,
        count: (typeof count === "number" ? count : 0) + 1,
        limit: rateLimit.limit,
        windowStartedAt: Timestamp.fromMillis(rateLimit.windowStartedAtMs),
        expiresAt: Timestamp.fromMillis(
            rateLimit.windowStartedAtMs + rateLimit.windowMs * 2,
        ),
      });
    }

    return rateLimits.map((rateLimit, index) => {
      const snapshot = snapshots[index];
      const count = snapshot.exists ? snapshot.get("count") : 0;
      return toRateLimitUsage(
          rateLimit,
          (typeof count === "number" ? count : 0) + 1,
          now,
      );
    });
  });
}

async function enforceRateLimit(request, action, limit, windowMs) {
  return enforceRateLimits(request, [
    {
      action,
      limit,
      windowMs,
    },
  ]);
}

function assertNumber(value, name, min, max) {
  if (
    typeof value !== "number" ||
    !Number.isFinite(value) ||
    value < min ||
    value > max
  ) {
    throw new HttpsError(
        "invalid-argument",
        `${name} must be between ${min} and ${max}.`,
    );
  }
}

function estimateBase64Bytes(value) {
  if (!/^[A-Za-z0-9+/]*={0,2}$/.test(value) || value.length % 4 !== 0) {
    throw new HttpsError("invalid-argument", "inlineData must be valid base64.");
  }

  const padding = value.endsWith("==") ? 2 : value.endsWith("=") ? 1 : 0;
  return (value.length * 3) / 4 - padding;
}

function normalizeContents(contents) {
  if (
    !Array.isArray(contents) ||
    contents.length === 0 ||
    contents.length > maxContents
  ) {
    throw new HttpsError(
        "invalid-argument",
        `contents must contain between 1 and ${maxContents} items.`,
    );
  }

  let partCount = 0;
  let textCharacters = 0;
  let totalInlineBytes = 0;

  return contents.map((content) => {
    if (
      !content ||
      !Array.isArray(content.parts) ||
      content.parts.length === 0
    ) {
      throw new HttpsError(
          "invalid-argument",
          "Each content item needs non-empty parts.",
      );
    }

    partCount += content.parts.length;
    if (partCount > maxParts) {
      throw new HttpsError(
          "invalid-argument",
          `A request may contain at most ${maxParts} parts.`,
      );
    }

    return {
      role: content.role === "model" ? "model" : "user",
      parts: content.parts.map((part) => {
        if (typeof part?.text === "string") {
          textCharacters += part.text.length;
          if (textCharacters > maxTextCharacters) {
            throw new HttpsError(
                "invalid-argument",
                `Text may contain at most ${maxTextCharacters} characters.`,
            );
          }
          return {text: part.text};
        }

        const mimeType = part?.inlineData?.mimeType;
        const data = part?.inlineData?.data;
        if (typeof mimeType === "string" && typeof data === "string") {
          if (!allowedImageMimeTypes.has(mimeType)) {
            throw new HttpsError(
                "invalid-argument",
                "Only JPEG, PNG, and WebP images are accepted.",
            );
          }

          const inlineBytes = estimateBase64Bytes(data);
          if (inlineBytes > maxInlineBytes) {
            throw new HttpsError(
                "invalid-argument",
                "An image may not exceed 8 MiB.",
            );
          }

          totalInlineBytes += inlineBytes;
          if (totalInlineBytes > maxTotalInlineBytes) {
            throw new HttpsError(
                "invalid-argument",
                "The total image payload may not exceed 10 MiB.",
            );
          }

          return {inlineData: {mimeType, data}};
        }

        throw new HttpsError(
            "invalid-argument",
            "Parts must contain text or inlineData.",
        );
      }),
    };
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
        signal: AbortSignal.timeout(110000),
      },
  );

  const bodyText = await response.text();
  let body;
  try {
    body = bodyText ? JSON.parse(bodyText) : {};
  } catch (_) {
    logger.error("Gemini returned invalid JSON.", {status: response.status});
    throw new HttpsError("internal", "The AI service returned invalid data.");
  }

  if (!response.ok) {
    logger.error("Gemini request failed.", {status: response.status});
    throw new HttpsError("internal", "The AI service request failed.");
  }

  const text = (body.candidates || [])
      .flatMap((candidate) => candidate.content?.parts || [])
      .map((part) => part.text || "")
      .join("")
      .trim();

  return {text};
}

async function handleGenerateGeminiContent(request) {
  const usages = await enforceRateLimits(request, geminiRateLimits());
  const contents = normalizeContents(request.data?.contents);
  const result = await callGemini(contents);
  return {
    ...result,
    usage: formatGeminiUsage(usages),
  };
}

async function handleGetGeminiUsage(request) {
  const usages = await getRateLimitUsages(request, geminiRateLimits());
  return {
    usage: formatGeminiUsage(usages),
  };
}

async function handleGetCurrentWeather(request) {
  await enforceRateLimit(request, "weather", 60, tenMinutesMs);
  const lat = request.data?.lat;
  const lon = request.data?.lon;
  assertNumber(lat, "lat", -90, 90);
  assertNumber(lon, "lon", -180, 180);

  const apiKey = openWeatherApiKey.value();
  assertSecret(apiKey, "OPENWEATHER_API_KEY");

  const url = new URL(weatherBaseUrl);
  url.searchParams.set("lat", String(lat));
  url.searchParams.set("lon", String(lon));
  url.searchParams.set("appid", apiKey);
  url.searchParams.set("units", "metric");
  url.searchParams.set("lang", "ja");

  const response = await fetch(url, {signal: AbortSignal.timeout(20000)});
  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    logger.error("OpenWeather request failed.", {status: response.status});
    throw new HttpsError("internal", "The weather service request failed.");
  }

  return data;
}

async function handleValidateOpenWeatherApiKey(request) {
  await enforceRateLimit(request, "weather-validation", 2, 60 * 60 * 1000);
  const apiKey = openWeatherApiKey.value();
  assertSecret(apiKey, "OPENWEATHER_API_KEY");

  const url = new URL(weatherBaseUrl);
  url.searchParams.set("lat", "35.6762");
  url.searchParams.set("lon", "139.6503");
  url.searchParams.set("appid", apiKey);
  url.searchParams.set("units", "metric");

  const response = await fetch(url, {signal: AbortSignal.timeout(20000)});
  return {valid: response.ok};
}

exports.generateGeminiContent = onCall(
    {
      region,
      secrets: [geminiApiKey],
      invoker: "public",
      enforceAppCheck: true,
      timeoutSeconds: 120,
      memory: "1GiB",
      maxInstances: 5,
    },
    handleGenerateGeminiContent,
);

exports.getGeminiUsage = onCall(
    {
      region,
      invoker: "public",
      enforceAppCheck: true,
      timeoutSeconds: 15,
      maxInstances: 5,
    },
    handleGetGeminiUsage,
);

exports.getCurrentWeather = onCall(
    {
      region,
      secrets: [openWeatherApiKey],
      invoker: "public",
      enforceAppCheck: true,
      timeoutSeconds: 30,
      maxInstances: 10,
    },
    handleGetCurrentWeather,
);

exports.validateOpenWeatherApiKey = onCall(
    {
      region,
      secrets: [openWeatherApiKey],
      invoker: "public",
      enforceAppCheck: true,
      timeoutSeconds: 30,
      maxInstances: 3,
    },
    handleValidateOpenWeatherApiKey,
);
