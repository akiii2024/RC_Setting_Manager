const test = require("node:test");
const assert = require("node:assert/strict");

process.env.NODE_ENV = "test";
const {__test} = require("../index");

function requestData() {
  return {
    carId: "tamiya/trf421",
    carName: "TRF421",
    profileId: "trf421",
    catalog: [
      {
        key: "frontWheelHub",
        label: "Front wheel hub",
        type: "select",
        category: "front",
        options: ["4mm", "4mm narrow"],
      },
      {
        key: "rearMountGrid",
        label: "Rear mount grid",
        type: "grid",
        category: "rear",
        constraints: {rows: 5, cols: 5, multiple: true},
      },
      {
        key: "toeAngle",
        label: "Toe angle",
        type: "number",
        category: "top",
        constraints: {min: -5, max: 5, step: 0.5},
      },
    ],
    image: {
      mimeType: "image/jpeg",
      data: Buffer.alloc(12).toString("base64"),
    },
  };
}

test("normalizes setting-sheet request and catalog", () => {
  const normalized = __test.normalizeSettingSheetRequest(requestData());
  assert.equal(normalized.profileId, "trf421");
  assert.deepEqual(normalized.catalog[0].options, ["4mm", "4mm narrow"]);
  assert.equal(normalized.catalog[1].constraints.cols, 5);
  assert.equal(normalized.catalog[2].constraints.min, -5);
});

test("rejects invalid profile and oversized image", () => {
  const invalidProfile = requestData();
  invalidProfile.profileId = "unknown";
  assert.throws(() => __test.normalizeSettingSheetRequest(invalidProfile));

  const oversized = requestData();
  oversized.image.data = Buffer.alloc(8 * 1024 * 1024 + 1).toString("base64");
  assert.throws(() => __test.normalizeSettingSheetRequest(oversized));

  const invalidMime = requestData();
  invalidMime.image.mimeType = "image/gif";
  assert.throws(() => __test.normalizeSettingSheetRequest(invalidMime));
});

test("system instruction treats image content as untrusted data", () => {
  const instruction = __test.settingSheetSystemInstruction();
  assert.match(instruction, /untrusted data/);
  assert.match(instruction, /Never infer/);
  assert.match(instruction, /zero-based/);
  assert.match(instruction, /Front and Rear/);
  assert.match(__test.settingSheetProfileInstruction("trf420"), /5x5 shaft grids/);
});

test("normalizes candidates, points, units, unknown keys, and conflicts", () => {
  const request = __test.normalizeSettingSheetRequest(requestData());
  const result = __test.normalizeSettingSheetResponse({
    detectedModel: " TRF421 ",
    candidates: [
      {
        key: "frontWheelHub",
        rawValue: " ４ mm  ",
        points: [{row: 3, col: 2}, {row: 0, col: 1}, {row: 3, col: 2}],
        confidence: "high",
        evidence: "marked X",
      },
      {
        key: "rearMountGrid",
        rawValue: "",
        points: [{row: 2, col: 1}, {row: 0, col: 0}, {row: 2, col: 1}],
        confidence: "medium",
        evidence: "filled dot",
      },
      {key: "notInCatalog", rawValue: "bad", points: [], confidence: "high"},
      {key: "frontWheelHub", rawValue: "5mm", points: [], confidence: "high"},
    ],
    warnings: [" blank field "],
  }, request);

  assert.equal(result.detectedModel, "TRF421");
  assert.equal(result.candidates.length, 3);
  assert.equal(result.candidates[0].rawValue, "4 mm");
  assert.deepEqual(result.candidates.find((candidate) =>
    candidate.key === "rearMountGrid").points, [
    {row: 0, col: 0}, {row: 2, col: 1},
  ]);
  assert.ok(result.warnings.some((warning) => warning.includes("Unknown OCR key")));
  assert.equal(result.candidates[1].rawValue, "5mm");
  assert.ok(result.warnings.some((warning) => warning.includes("Conflicting OCR values")));
});

test("keeps multiple detected points for local single-grid rejection", () => {
  const data = requestData();
  data.catalog[1].constraints.multiple = false;
  const request = __test.normalizeSettingSheetRequest(data);
  const result = __test.normalizeSettingSheetResponse({
    detectedModel: "TRF421",
    candidates: [{
      key: "rearMountGrid",
      rawValue: "",
      points: [{row: 0, col: 0}, {row: 1, col: 1}],
      confidence: "high",
      evidence: "two marks",
    }],
    warnings: [],
  }, request);
  assert.deepEqual(result.candidates[0].points, [
    {row: 0, col: 0}, {row: 1, col: 1},
  ]);
});

test("schema restricts candidate keys to catalog keys", () => {
  const schema = __test.settingSheetSchema(__test.normalizeSettingSheetRequest(requestData()).catalog);
  assert.deepEqual(schema.properties.candidates.items.properties.key.enum, [
    "frontWheelHub", "rearMountGrid", "toeAngle",
  ]);
  assert.equal(schema.properties.candidates.items.properties.rawValue.type, "string");
});

test("retries are limited to OCR protocol failures", async () => {
  const {HttpsError} = require("firebase-functions/v2/https");
  assert.equal(__test.isSettingSheetProtocolFailure(
      new HttpsError("internal", "The AI OCR response was invalid JSON.")), true);
  assert.equal(__test.isSettingSheetProtocolFailure(
      new HttpsError("unavailable", "The AI service request failed.")), false);
  assert.equal(__test.isSettingSheetProtocolFailure(new Error("network")), false);

  let calls = 0;
  const extracted = await __test.callSettingSheetExtraction({}, async () => {
    calls++;
    if (calls === 1) {
      throw new HttpsError("internal", "The AI OCR response was invalid JSON.");
    }
    return {result: {candidates: []}};
  });
  assert.equal(calls, 2);
  assert.deepEqual(extracted, {result: {candidates: []}});

  calls = 0;
  await __test.callSettingSheetExtraction({}, async () => {
    calls++;
    return {result: {candidates: [{confidence: "low"}]}};
  });
  assert.equal(calls, 1);
});
