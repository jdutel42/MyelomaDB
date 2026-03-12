#!/bin/bash
# ============================================================
# BIOBANQUE - Setup & lancement dans Conda
# ============================================================

ENV_NAME="biobanque"

# ---- 1. Créer l'environnement conda -------------------------
setup_env() {
  echo "▶ Création de l'environnement conda '$ENV_NAME'..."
  conda env create -f environment.yml
  echo "✓ Environnement créé."
}

# ---- 2. Initialiser la base PostgreSQL ----------------------
init_db() {
  echo "▶ Initialisation PostgreSQL..."

  # Dossier de données local au projet
  export PGDATA="$(pwd)/pgdata"
  export PGPORT=5433   # Port non-standard pour éviter conflits

  mkdir -p "$PGDATA"
  initdb -D "$PGDATA" --encoding=UTF8 --locale=fr_FR.UTF-8

  # Démarrer le serveur
  pg_ctl -D "$PGDATA" -l "$(pwd)/postgres.log" start
  sleep 2

  # Créer user et base
  createuser -p $PGPORT biobank_user
  psql -p $PGPORT postgres -c "ALTER USER biobank_user WITH PASSWORD 'biobank_pass';"
  createdb  -p $PGPORT -O biobank_user biobanque

  echo "✓ PostgreSQL initialisé sur le port $PGPORT."
}

# ---- 3. Créer les tables ------------------------------------
create_tables() {
  export PGPORT=5433
  echo "▶ Création des tables..."
  psql -h localhost -p $PGPORT -U biobank_user -d biobanque \
       -f 01_create_tables.sql
  echo "✓ Tables créées."
}

# ---- 4. Charger les données factices ------------------------
load_data() {
  echo "▶ Chargement des données factices..."
  Rscript 02_generate_fake_data.R
  echo "✓ Données chargées."
}

# ---- 5. Lancer Shiny ----------------------------------------
run_shiny() {
  echo "▶ Lancement de l'application Shiny..."
  Rscript -e "shiny::runApp('app.R', port=3838, launch.browser=TRUE)"
}

# ---- 6. Démarrer PostgreSQL (si déjà initialisé) ------------
start_db() {
  export PGDATA="$(pwd)/pgdata"
  pg_ctl -D "$PGDATA" -l "$(pwd)/postgres.log" start
  echo "✓ PostgreSQL démarré."
}

# ---- 7. Arrêter PostgreSQL ----------------------------------
stop_db() {
  export PGDATA="$(pwd)/pgdata"
  pg_ctl -D "$PGDATA" stop
  echo "✓ PostgreSQL arrêté."
}

# ---- MENU --------------------------------------------------
case "${1:-help}" in
  setup)   setup_env ;;
  init-db) init_db ;;
  tables)  create_tables ;;
  data)    load_data ;;
  shiny)   run_shiny ;;
  start)   start_db ;;
  stop)    stop_db ;;
  all)
    init_db
    create_tables
    load_data
    run_shiny
    ;;
  help|*)
    echo "Usage : conda run -n $ENV_NAME bash $(basename $0) <commande>"
    echo ""
    echo "Commandes disponibles :"
    echo "  setup     Créer l'environnement conda depuis environment.yml"
    echo "  all       init-db + tables + data + shiny (premier démarrage)"
    echo "  start     Démarrer PostgreSQL"
    echo "  stop      Arrêter PostgreSQL"
    echo "  shiny     Lancer l'application Shiny"
    echo ""
    echo "Exemple premier démarrage :"
    echo "  conda env create -f environment.yml"
    echo "  conda activate $ENV_NAME"
    echo "  bash biobank.sh all"
    ;;
esac
