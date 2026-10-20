"""Independent keyboard mapping, curated corpus, and recovery boundary cases.

Expected layout results are exploration targets, not a promise that every name
or rare word is suitable for automatic correction. No OS events are generated.
"""
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2]
baseline = json.loads((root / "Tests/StressAudit/cases.json").read_text())
cases = []
seen = set()


def add(kind, value, expected, language, group, suffix=None):
    key = (kind, value, expected, suffix)
    if key in seen:
        return
    seen.add(key)
    cases.append(dict(kind=kind, input=value, expected=expected, language=language,
                      group=group, typedSuffix=suffix))


for case in baseline:
    if case["kind"] != "layout" or case["group"] != "curated":
        continue
    correct, wrong = case["expected"], case["input"]
    if not 3 <= len(correct) <= 64 or len(correct) != len(wrong):
        continue
    if not correct.isalpha() or not wrong.isalpha():
        continue
    if any(not ("a" <= c.lower() <= "z" or "а" <= c.lower() <= "я" or c.lower() == "ё")
           for c in correct + wrong):
        continue
    lang = case["language"]
    for cut in range(1, len(correct)):
        for mixed, suffix in [(wrong[:cut] + correct[cut:], correct[cut:]),
                              (correct[:cut] + wrong[cut:], wrong[cut:])]:
            add("layout", mixed, correct, lang, "mixed-every-cut")
            add("recover-layout", "Предыдущая строка 🙂\n" + mixed,
                "Предыдущая строка 🙂\n" + correct, lang, "recovery-every-cut", suffix)
            if cut == len(correct) // 2:
                for left, right in [("(", ")"), ("«", "!»"), ("\"", ",\"")]:
                    add("layout", left + mixed + right, left + correct + right,
                        lang, "mixed-punctuation")
    for index in range(len(correct)):
        mixed = correct[:index] + wrong[index] + correct[index + 1:]
        add("layout", mixed, correct, lang, "isolated-wrong-letter")

for value in ["https://ktв", "user@ktв", "/tmp/ktв", "foo_ktв", "ktв123",
              "ktв.swift", "myKtв", "ktвxyz", "pаypal", "аррle", "ИT", "aя"]:
    add("keep", value, value, "", "protected-mixed")
    add("recover-layout", value, value, "", "protected-recovery", value[-1])

for value in ["ktв", "Начало ktв", "🙂\nktв"]:
    for suffix in ["", "x", "лев"]:
        add("recover-layout", value, value, "russian", "stale-or-empty-buffer", suffix)
for count in [64, 65, 66, 100, 1000, 10000]:
    value = "k" * count + "в"
    add("recover-layout", value, value, "russian", "long-recovery", "в")

# Characters on punctuation keys are deliberately separate: bracket/comma letters
# can be indistinguishable from genuine punctuation without source history.
for mixed, correct in [("[орошо", "хорошо"), ("хороij", "хорошо"),
                       (",абушка", "бабушка"), ("бабуirf", "бабушка")]:
    add("layout", mixed, correct, "russian", "punctuation-key-exploratory")

destination = root / "build/stress-audit/scenarios.json"
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(cases, ensure_ascii=False, indent=2))
print(f"Scenario corpus: {len(cases)} cases -> {destination}")
