#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]
set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

DRY_RUN=0
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=1
fi

# Проверка 4: наличие site/index.html
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Ошибка: отсутствует site/index.html" >&2
    exit 1
fi

# Проверка 5: нет незафиксированных изменений
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Ошибка: есть незафиксированные изменения" >&2
    exit 1
fi

# Формируем команду rsync
RSYNC_CMD=(rsync -avz --delete --chmod=D755,F644 -e "ssh -o BatchMode=yes -o ConnectTimeout=5")
if [[ $DRY_RUN -eq 1 ]]; then
    RSYNC_CMD+=(--dry-run)
fi
RSYNC_CMD+=("${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/")

# Синхронизация
"${RSYNC_CMD[@]}"

# При --dry-run завершаем без проверки доступности
if [[ $DRY_RUN -eq 1 ]]; then
    exit 0
fi

# Проверка доступности ресурса
if ! curl -fsS --cacert "${CA_CERT}" -o /dev/null "${SITE_URL}"; then
    echo "Ошибка: ресурс ${SITE_URL} недоступен" >&2
    exit 1
fi

# Вывод короткого хеша коммита
echo "Успешно доставлен коммит: $(git rev-parse --short HEAD)"
