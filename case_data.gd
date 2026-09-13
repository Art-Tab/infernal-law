extends RefCounted

const CIRCLES = ["CIRCLE_1","CIRCLE_2","CIRCLE_3","CIRCLE_4","CIRCLE_5","CIRCLE_6","CIRCLE_7","CIRCLE_8","CIRCLE_9"]
const RULES = ["RULE_1","RULE_2","RULE_3","RULE_4","RULE_5","RULE_6","RULE_7","RULE_8","RULE_9"]
const CASES = [
  {
    "name": "CASE_MATVEY_NAME",
    "role": "CASE_MATVEY_ROLE",
    "file": "CASE_MATVEY_FILE",
    "intro": "CASE_MATVEY_INTRO",
    "dialogue": [
      {
        "question": "CASE_MATVEY_DIALOGUE_1_QUESTION",
        "answer": "CASE_MATVEY_DIALOGUE_1_ANSWER"
      },
      {
        "question": "CASE_MATVEY_DIALOGUE_2_QUESTION",
        "answer": "CASE_MATVEY_DIALOGUE_2_ANSWER"
      },
      {
        "question": "CASE_MATVEY_DIALOGUE_3_QUESTION",
        "answer": "CASE_MATVEY_DIALOGUE_3_ANSWER"
      }
    ],
    "archive": "CASE_MATVEY_ARCHIVE",
    "facts": [
      "CASE_MATVEY_FACTS_1",
      "CASE_MATVEY_FACTS_2",
      "CASE_MATVEY_FACTS_3"
    ],
    "circle": 3,
    "evidence": 0,
    "explanation": "CASE_MATVEY_EXPLANATION",
    "id": "matvey_grain"
  },
  {
    "name": "CASE_AGATA_NAME",
    "role": "CASE_AGATA_ROLE",
    "file": "CASE_AGATA_FILE",
    "intro": "CASE_AGATA_INTRO",
    "dialogue": [
      {
        "question": "CASE_AGATA_DIALOGUE_1_QUESTION",
        "answer": "CASE_AGATA_DIALOGUE_1_ANSWER"
      },
      {
        "question": "CASE_AGATA_DIALOGUE_2_QUESTION",
        "answer": "CASE_AGATA_DIALOGUE_2_ANSWER"
      },
      {
        "question": "CASE_AGATA_DIALOGUE_3_QUESTION",
        "answer": "CASE_AGATA_DIALOGUE_3_ANSWER"
      }
    ],
    "archive": "CASE_AGATA_ARCHIVE",
    "facts": [
      "CASE_AGATA_FACTS_1",
      "CASE_AGATA_FACTS_2",
      "CASE_AGATA_FACTS_3"
    ],
    "circle": 7,
    "evidence": 1,
    "explanation": "CASE_AGATA_EXPLANATION",
    "id": "agata_water"
  },
  {
    "name": "CASE_SEVERIN_NAME",
    "role": "CASE_SEVERIN_ROLE",
    "file": "CASE_SEVERIN_FILE",
    "intro": "CASE_SEVERIN_INTRO",
    "dialogue": [
      {
        "question": "CASE_SEVERIN_DIALOGUE_1_QUESTION",
        "answer": "CASE_SEVERIN_DIALOGUE_1_ANSWER"
      },
      {
        "question": "CASE_SEVERIN_DIALOGUE_2_QUESTION",
        "answer": "CASE_SEVERIN_DIALOGUE_2_ANSWER"
      },
      {
        "question": "CASE_SEVERIN_DIALOGUE_3_QUESTION",
        "answer": "CASE_SEVERIN_DIALOGUE_3_ANSWER"
      }
    ],
    "archive": "CASE_SEVERIN_ARCHIVE",
    "facts": [
      "CASE_SEVERIN_FACTS_1",
      "CASE_SEVERIN_FACTS_2",
      "CASE_SEVERIN_FACTS_3"
    ],
    "circle": 8,
    "evidence": 2,
    "explanation": "CASE_SEVERIN_EXPLANATION",
    "id": "severin_shelter"
  }
]
