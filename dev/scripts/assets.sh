#!/usr/bin/env bash
# Descarga/actualiza los assets de terceros a public/assets.
# Versiones fijadas: edita las de abajo para actualizarlas.
set -euo pipefail

JQUERY_VERSION="3.7.1"
BOOTSTRAP_VERSION="5.3.8"
DATATABLES_VERSION="3.1.4"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JS="$ROOT/public/assets/js"
CSS="$ROOT/public/assets/css"

mkdir -p "$JS" "$CSS"

download() {
    echo "  -> $(basename "$1")"
    curl -fsSL -o "$2" "$1"
}

echo "jQuery $JQUERY_VERSION"
download "https://code.jquery.com/jquery-${JQUERY_VERSION}.min.js" "$JS/jquery.min.js"

echo "Bootstrap $BOOTSTRAP_VERSION"
download "https://cdn.jsdelivr.net/npm/bootstrap@${BOOTSTRAP_VERSION}/dist/css/bootstrap.min.css" "$CSS/bootstrap.min.css"
download "https://cdn.jsdelivr.net/npm/bootstrap@${BOOTSTRAP_VERSION}/dist/js/bootstrap.bundle.min.js" "$JS/bootstrap.bundle.min.js"

echo "DataTables $DATATABLES_VERSION"
download "https://cdn.datatables.net/${DATATABLES_VERSION}/js/dataTables.min.js" "$JS/dataTables.min.js"
download "https://cdn.datatables.net/${DATATABLES_VERSION}/js/dataTables.bootstrap5.min.js" "$JS/dataTables.bootstrap5.min.js"
download "https://cdn.datatables.net/${DATATABLES_VERSION}/css/dataTables.dataTables.min.css" "$CSS/dataTables.dataTables.min.css"

echo "Listo."
