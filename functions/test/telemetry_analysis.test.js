const test = require("node:test");
const assert = require("node:assert/strict");

process.env.NODE_ENV = "test";
const {__test} = require("../index");

function report() {
  return {
    filename: "private.csv",
    evidence: [
      {id: "lap-1-throttle", metric: "fullThrottleRatio", value: 0.4},
    ],
    laps: [{lap: 1, lapTime: 31.2}],
    waveform: Array.from({length: 100}, (_, index) => ({t: index, st: 20})),
    apiKey: "must-not-be-forwarded",
  };
}

test("normalizes telemetry request and removes sensitive fields", () => {
  const input = report();
  input.selectedLaps = [{
    lap: 1,
    waveform: Array.from({length: 120}, (_, index) => ({t: index, st: 20})),
  }];
  input.raw_csv = "must-not-be-forwarded";
  input.API_KEY = "must-not-be-forwarded";
  const normalized = __test.normalizeTelemetryRequest({locale: "ja", report: input});
  assert.equal(normalized.locale, "ja");
  assert.equal(normalized.report.filename, undefined);
  assert.equal(normalized.report.apiKey, undefined);
  assert.equal(normalized.report.raw_csv, undefined);
  assert.equal(normalized.report.API_KEY, undefined);
  assert.equal(normalized.report.waveform.length, 96);
  assert.equal(normalized.report.selectedLaps[0].waveform.length, 96);
});

test("shrinks oversized telemetry report without truncating JSON", () => {
  const oversized = report();
  oversized.waveform = Array.from({length: 150}, () => ({text: "x".repeat(1000)}));
  const normalized = __test.normalizeTelemetryRequest({report: oversized});
  assert.ok(JSON.stringify(normalized).length <= 45000);
  assert.ok(normalized.report.waveform.length <= 64);
});

test("filters unknown evidence IDs from structured AI output", () => {
  const normalized = __test.normalizeTelemetryAnalysis({
    summary: "操作の傾向を確認できます。",
    confidence: "high",
    strengthEvidenceIds: ["lap-1-throttle", "unknown"],
    focusAreas: [{
      title: "再加速",
      evidenceIds: ["unknown", "lap-1-throttle"],
      inference: "再加速のタイミングを比較できます。",
      coachingTip: "同じラインで早めの再加速を試します。",
      verification: "次の周回で全開到達位置を確認します。",
    }],
    limitations: ["速度センサーはありません。"],
  }, report());
  assert.deepEqual(normalized.strengthEvidenceIds, ["lap-1-throttle"]);
  assert.deepEqual(normalized.focusAreas[0].evidenceIds, ["lap-1-throttle"]);
});

test("rejects an empty telemetry analysis response", () => {
  assert.throws(() => __test.normalizeTelemetryAnalysis({
    summary: "",
    confidence: "medium",
    strengthEvidenceIds: [],
    focusAreas: [],
    limitations: [],
  }, report()), (error) => error?.code === "internal");
});

test("telemetry instruction prohibits setup changes and treats data as untrusted", () => {
  const instruction = __test.telemetrySystemInstruction("ja");
  assert.match(instruction, /untrusted data/);
  assert.match(instruction, /setup changes/);
  assert.match(instruction, /vehicle behavior/);
});
