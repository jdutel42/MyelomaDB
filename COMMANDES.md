# 🧬 Biobanque — Aide-mémoire des commandes

---

## 1. Environnement Conda

```bash
# Activer l'environnement
conda activate biobanque

# Désactiver l'environnement
conda deactivate

# Lister les environnements disponibles
conda env list

# Lister les packages installés dans l'environnement actif
conda list
```

> ⚠️ Toujours activer l'environnement **avant** de lancer PostgreSQL ou Shiny.

---

## 2. Serveur PostgreSQL

```bash
# Démarrer le serveur
pg_ctl -D ./pgdata -l ./pgdata/postgres.log -o "-p 5433" start

# Arrêter le serveur
pg_ctl -D ./pgdata stop

# Vérifier si le serveur tourne
pg_ctl -D ./pgdata status

# Voir les logs en cas de problème
cat ./pgdata/postgres.log
```

> ⚠️ Le port **5433** est utilisé à la place du port par défaut 5432,
> car un autre PostgreSQL tourne déjà sur la machine (système INSERM).

---

## 3. Se connecter à la base

```bash
# Ouvrir un shell SQL interactif
psql -p 5433 -U dutel -d biobanque
```

### Commandes utiles dans le shell psql

```sql
\dt                  -- lister toutes les tables
\d nom_table         -- décrire la structure d'une table
\q                   -- quitter psql

-- Compter les lignes d'une table
SELECT COUNT(*) FROM patients;

-- Voir les 5 premières lignes d'une table
SELECT * FROM patients LIMIT 5;

-- Vider une table (sans supprimer sa structure)
TRUNCATE TABLE nom_table;
```

---

## 4. Charger les données factices

```bash
# Générer et insérer les données dans la base
Rscript 02_generate_fake_data.R
```

Si besoin de repartir de zéro (vider toutes les tables) :

```bash
psql -p 5433 -U dutel -d biobanque -c "
TRUNCATE TABLE audit_log, evenements_cliniques,
biomarqueurs_qualitatifs, biomarqueurs_numeriques,
prelevements, patients, protocoles, utilisateurs
RESTART IDENTITY CASCADE;"
```

---

## 5. Lancer l'application Shiny

```bash
# Depuis le dossier du projet
Rscript -e "shiny::runApp('03_shiny_app', port=3838, launch.browser=FALSE)"
```

Puis ouvrir dans le navigateur : **http://localhost:3838**

Pour arrêter l'application : **Ctrl+C** dans le terminal.

---

## 6. Sauvegarder et restaurer la base

```bash
# Sauvegarde complète (crée un fichier .dump)
pg_dump -h localhost -p 5433 -U dutel -F c -Z 9 -d biobanque \
        -f ./backups/biobanque_$(date +%Y%m%d).dump

# Lister les sauvegardes disponibles
ls -lh ./backups/

# Restaurer depuis un fichier .dump
pg_restore -h localhost -p 5433 -U dutel -d biobanque \
           ./backups/biobanque_YYYYMMDD.dump
```

---

## 7. Modifier la structure de la base

```bash
# Ajouter une colonne à une table
psql -p 5433 -U dutel -d biobanque -c \
  "ALTER TABLE patients ADD COLUMN ma_colonne VARCHAR(50);"

# Modifier la taille d'une colonne
psql -p 5433 -U dutel -d biobanque -c \
  "ALTER TABLE patients ALTER COLUMN ma_colonne TYPE VARCHAR(100);"

# Supprimer une colonne
psql -p 5433 -U dutel -d biobanque -c \
  "ALTER TABLE patients DROP COLUMN ma_colonne;"
```

---

## 8. Ordre de démarrage (checklist)

Chaque fois que vous reprenez le travail :

```bash
# 1. Se placer dans le dossier projet
cd /home/jordan.dutel@adn.inserm.fr/Documents/Project/Biobanking/Test

# 2. Activer conda
conda activate biobanque

# 3. Démarrer PostgreSQL
pg_ctl -D ./pgdata -l ./pgdata/postgres.log -o "-p 5433" start

# 4. Lancer Shiny
Rscript -e "shiny::runApp('03_shiny_app', port=3838, launch.browser=FALSE)"
```

Et pour tout arrêter proprement :

```bash
# Arrêter PostgreSQL
pg_ctl -D ./pgdata stop

# Désactiver conda
conda deactivate
```
