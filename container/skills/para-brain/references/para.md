# PARA Method Reference

## Vault Structure

```
$VAULT/
├── inbox/              ← new captures (raw/pending_review)
├── projects/           ← goal + deadline (dynamic subfolders)
├── areas/              ← ongoing responsibilities (dynamic subfolders)
├── resources/          ← reference material (dynamic subfolders)
├── archive/            ← completed/inactive — NEVER DELETE
├── _settings.yaml      ← agent config (auto_classify)
└── README.md
```

## PARA Definitions

| Category | Definition | Lifecycle |
|---|---|---|
| Projects | Short-term efforts with a goal and deadline | Done/abandoned → Archive |
| Areas | Ongoing responsibilities with no end date | Inactive → Archive |
| Resources | Reference material for interests/topics | Unneeded → Archive |
| Archive | Cold storage for completed P/A/R | **Cannot be deleted. Always exists.** |

## Decision Tree (for classifying notes)

1. Is it for an active project? → Projects
2. Is it for an ongoing area of responsibility? → Areas
3. Is it reference material? → Resources
4. Is it done or no longer needed? → Archive
