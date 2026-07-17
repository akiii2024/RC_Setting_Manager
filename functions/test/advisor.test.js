const test = require("node:test");
const assert = require("node:assert/strict");

process.env.NODE_ENV = "test";
const {__test} = require("../index");

function requestData() {
  return {
    phase: "final",
    locale: "ja",
    context: {
      vehicle: {
        id: "car-1",
        name: "Test car",
        manufacturer: "Test",
        category: "touring",
      },
      settingName: "Base",
      definitionVerified: true,
      settings: [
        {
          key: "frontCamber",
          label: "フロント キャンバー",
          value: -1,
          source: "confirmed",
        },
      ],
      settingCatalog: [
        {
          key: "frontCamber",
          label: "フロント キャンバー",
          type: "number",
          min: -5,
          max: 5,
          step: 0.5,
          autoApplicable: true,
        },
      ],
      relatedRuns: [],
    },
    intake: {
      symptoms: ["push"],
      phases: ["corner_entry"],
      severity: "medium",
      trackGrip: "high",
      goal: "rotation",
    },
    messages: [],
  };
}

test("normalizes a bounded advisor request", () => {
  const normalized = __test.normalizeAdvisorRequest(requestData());
  assert.equal(normalized.phase, "final");
  assert.equal(normalized.context.relatedRuns.length, 0);
  assert.deepEqual(normalized.intake.symptoms, ["push"]);
});

test("rejects more than five related run logs", () => {
  const data = requestData();
  data.context.relatedRuns = Array.from({length: 6}, () => ({runAt: "now"}));
  assert.throws(() => __test.normalizeAdvisorRequest(data));
});

test("keeps only a valid one-step applicable change", () => {
  const data = requestData();
  const response = __test.normalizeAdvisorFinalResponse({
    summary: "進入時の旋回不足です。",
    confidence: "medium",
    evidence: ["進入で曲がらない"],
    missingInformation: [],
    changes: [
      {
        settingKey: "frontCamber",
        settingLabel: "ignored",
        currentValue: "ignored",
        proposedValue: "-1.5",
        reason: "接地の変化を確認します。",
        expectedEffect: "旋回特性の変化を確認できます。",
        tradeoff: "直進安定性とのバランスを確認してください。",
        priority: 1,
      },
      {
        settingKey: "unknownSetting",
        settingLabel: "Unknown",
        currentValue: "0",
        proposedValue: "1",
        reason: "invalid",
        expectedEffect: "invalid",
        tradeoff: "invalid",
        priority: 2,
      },
    ],
    manualTips: [],
    testPlan: "同じタイヤで5周比較します。",
    drivingTips: "一定の操作で比較します。",
  }, data.context);

  assert.equal(response.changes.length, 1);
  assert.equal(response.changes[0].settingKey, "frontCamber");
  assert.equal(response.changes[0].settingLabel, "フロント キャンバー");
  assert.equal(response.changes[0].proposedValue, "-1.5");
});

test("system instruction treats supplied context as untrusted data", () => {
  const instruction = __test.advisorSystemInstruction("ja");
  assert.match(instruction, /untrusted data/);
  assert.match(instruction, /autoApplicable/);
  assert.match(instruction, /one declared step/);
});

test("advisor content always ends with the current user task", () => {
  const request = __test.normalizeAdvisorRequest(requestData());
  request.messages = [
    {role: "model", text: "Previous answer"},
  ];
  const contents = __test.advisorContents(request);
  assert.equal(contents.at(-1).role, "user");
  assert.match(contents.at(-1).parts[0].text, /CURRENT_TASK/);
});
