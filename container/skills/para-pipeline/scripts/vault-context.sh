#!/bin/bash
# para-pipeline/scripts/vault-context.sh
# SessionStart hook — injects vault awareness into every agent session (Express Ambient)
# Registered via container-runner.ts in settings.json hooks.SessionStart
VAULT="${VAULT:-/workspace/extra/vault}"
if [ -d "$VAULT" ]; then
  TOTAL=$(find "$VAULT" -name '*.md' ! -name '_*' | wc -l | tr -d ' ')
  INBOX=$(find "$VAULT/inbox" -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  PARA_DIRS=$(find "$VAULT" -mindepth 1 -maxdepth 2 -type d ! -name '.*' ! -name inbox ! -name _logs | head -20 | sed "s|$VAULT/||" | tr '\n' ', ')
  RECENT_TAGS=$(grep -rh '^tags:' "$VAULT/inbox/" 2>/dev/null | sed 's/tags: *\[//;s/\]//;s/, /\n/g' | sort | uniq -c | sort -rn | head -10 | awk '{print $2}' | tr '\n' ', ')

  cat <<CONTEXT
[Vault Awareness] 이 그룹에 지식 저장소(vault)가 있습니다.
경로: $VAULT
노트 수: ${TOTAL}개 (inbox: ${INBOX}개)
PARA 경로: ${PARA_DIRS%,}
최근 빈출 태그: ${RECENT_TAGS%,}
질문에 답할 때 \`grep -ril "키워드" $VAULT/\`로 관련 노트를 먼저 찾아보세요.
관련 노트가 있으면 인용해서 답변하고, 없으면 일반 지식으로 답변하세요.
vault 결과와 일반 지식을 명확히 구분해서 제시하세요.
CONTEXT
fi
