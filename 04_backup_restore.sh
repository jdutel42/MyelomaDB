#!/bin/bash
# ============================================================
# BIOBANQUE CLINIQUE - Sauvegarde & Restauration PostgreSQL
# Script : 04_backup_restore.sh
# ============================================================

# ---- CONFIGURATION ----------------------------------------
DB_NAME="biobanque"
DB_USER="biobank_user"
DB_HOST="localhost"
DB_PORT="5432"
BACKUP_DIR="/opt/biobank/backups"   # Modifier selon votre arbo
RETENTION_DAYS=30                   # Conserver X jours de sauvegardes
DATE_TAG=$(date +"%Y%m%d_%H%M%S")
# -----------------------------------------------------------

export PGPASSWORD="biobank_pass"    # Ou utiliser ~/.pgpass

mkdir -p "$BACKUP_DIR"

# ============================================================
# SAUVEGARDE COMPLÈTE (dump binaire compressé)
# ============================================================
backup_full() {
  BACKUP_FILE="${BACKUP_DIR}/biobanque_full_${DATE_TAG}.dump"
  echo "▶ Sauvegarde complète → $BACKUP_FILE"

  pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -F c \
    -Z 9 \
    -d "$DB_NAME" \
    -f "$BACKUP_FILE"

  if [ $? -eq 0 ]; then
    SIZE=$(du -sh "$BACKUP_FILE" | cut -f1)
    echo "✓ Sauvegarde réussie ($SIZE)"
    # Créer un lien symbolique vers la dernière sauvegarde
    ln -sf "$BACKUP_FILE" "${BACKUP_DIR}/latest.dump"
  else
    echo "✗ Échec de la sauvegarde !"
    exit 1
  fi
}

# ============================================================
# SAUVEGARDE SQL LISIBLE (pour audit / portabilité)
# ============================================================
backup_sql() {
  BACKUP_FILE="${BACKUP_DIR}/biobanque_sql_${DATE_TAG}.sql.gz"
  echo "▶ Sauvegarde SQL → $BACKUP_FILE"

  pg_dump \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -F p \
    -d "$DB_NAME" | gzip > "$BACKUP_FILE"

  echo "✓ SQL compressé : $BACKUP_FILE"
}

# ============================================================
# RESTAURATION depuis un fichier .dump
# ============================================================
restore_full() {
  RESTORE_FILE="${1:-${BACKUP_DIR}/latest.dump}"

  if [ ! -f "$RESTORE_FILE" ]; then
    echo "✗ Fichier introuvable : $RESTORE_FILE"
    exit 1
  fi

  echo "⚠ ATTENTION : Ceci va écraser la base $DB_NAME !"
  echo "  Fichier source : $RESTORE_FILE"
  read -p "  Confirmer ? (oui/non) : " CONFIRM
  [ "$CONFIRM" != "oui" ] && { echo "Annulé."; exit 0; }

  # Sauvegarde de sécurité avant restauration
  backup_full

  echo "▶ Suppression de la base existante..."
  psql -h "$DB_HOST" -p "$DB_PORT" -U postgres -c \
    "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='$DB_NAME';"
  dropdb  -h "$DB_HOST" -p "$DB_PORT" -U postgres "$DB_NAME"
  createdb -h "$DB_HOST" -p "$DB_PORT" -U postgres \
    -O "$DB_USER" "$DB_NAME"

  echo "▶ Restauration en cours..."
  pg_restore \
    -h "$DB_HOST" \
    -p "$DB_PORT" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -v \
    "$RESTORE_FILE"

  echo "✓ Restauration terminée."
}

# ============================================================
# NETTOYAGE des anciennes sauvegardes
# ============================================================
cleanup_old() {
  echo "▶ Suppression des sauvegardes > ${RETENTION_DAYS} jours..."
  find "$BACKUP_DIR" -name "biobanque_*.dump" -mtime +$RETENTION_DAYS -delete
  find "$BACKUP_DIR" -name "biobanque_*.sql.gz" -mtime +$RETENTION_DAYS -delete
  echo "✓ Nettoyage terminé."
}

# ============================================================
# LISTER les sauvegardes disponibles
# ============================================================
list_backups() {
  echo "📁 Sauvegardes disponibles dans $BACKUP_DIR :"
  echo "---------------------------------------------------"
  ls -lh "$BACKUP_DIR"/biobanque_*.dump 2>/dev/null | awk '{print $5, $6, $7, $8, $9}'
  ls -lh "$BACKUP_DIR"/biobanque_*.sql.gz 2>/dev/null | awk '{print $5, $6, $7, $8, $9}'
}

# ============================================================
# VÉRIFICATION d'intégrité du dump
# ============================================================
check_dump() {
  DUMP_FILE="${1:-${BACKUP_DIR}/latest.dump}"
  echo "▶ Vérification : $DUMP_FILE"
  pg_restore --list "$DUMP_FILE" | tail -5
  echo "✓ Dump valide."
}

# ============================================================
# MENU PRINCIPAL
# ============================================================
case "${1:-menu}" in
  backup)   backup_full ; backup_sql ;;
  restore)  restore_full "$2" ;;
  cleanup)  cleanup_old ;;
  list)     list_backups ;;
  check)    check_dump "$2" ;;
  menu)
    echo "Usage : $0 [backup|restore <fichier>|cleanup|list|check <fichier>]"
    echo ""
    echo "  backup           Sauvegarde complète + SQL"
    echo "  restore [file]   Restaurer (latest.dump si aucun fichier)"
    echo "  list             Lister les sauvegardes"
    echo "  cleanup          Supprimer les dumps > ${RETENTION_DAYS} jours"
    echo "  check [file]     Vérifier l'intégrité d'un dump"
    ;;
esac

unset PGPASSWORD
