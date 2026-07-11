#!/bin/bash
# Elimina las Acciones rápidas de ScreenRec de ~/Library/Services.
set -euo pipefail
SERVICES="$HOME/Library/Services"
rm -rf "$SERVICES/Convertir vídeo con ScreenRec.workflow"
rm -rf "$SERVICES/Convertir a GIF con ScreenRec.workflow"
/System/Library/CoreServices/pbs -flush 2>/dev/null || true
echo "Acciones rápidas de ScreenRec eliminadas."
