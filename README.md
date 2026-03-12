# 🧬 Biobanque Clinique - Guide d'installation complet

Prototype fonctionnel PostgreSQL + R Shiny pour protocoles cliniques.  
**Tout repose sur des données factices** — aucune donnée réelle n'est incluse.

---

## 📁 Structure du projet

```
biobank/
├── 01_create_tables.sql       ← Schéma PostgreSQL (tables, index, vues)
├── 02_generate_fake_data.R    ← Génération de 120 patients + biomarqueurs
├── 03_shiny_app/
│   └── app.R                  ← Interface Shiny complète
├── 04_backup_restore.sh       ← Sauvegarde & restauration automatisées
└── README.md                  ← Ce fichier
```

---

## ⚙️ 1. Pré-requis

### PostgreSQL (Linux/macOS)
```bash
# Ubuntu/Debian
sudo apt install postgresql postgresql-contrib

# macOS (Homebrew)
brew install postgresql
brew services start postgresql
```

### PostgreSQL (Windows)
Télécharger l'installeur officiel : https://www.postgresql.org/download/windows/

### R et packages
```r
install.packages(c(
  "shiny", "shinydashboard", "shinyWidgets",
  "DBI", "RPostgres",
  "DT", "ggplot2", "dplyr", "plotly", "lubridate", "stringr"
))
```

---

## 🗄️ 2. Créer la base de données

```bash
# Se connecter en superutilisateur PostgreSQL
sudo -u postgres psql

# Dans le shell psql :
CREATE DATABASE biobanque ENCODING 'UTF8';
CREATE USER biobank_user WITH PASSWORD 'biobank_pass';
GRANT ALL PRIVILEGES ON DATABASE biobanque TO biobank_user;
\q
```

### Créer les tables
```bash
psql -h localhost -U biobank_user -d biobanque -f 01_create_tables.sql
```

Vous devriez voir :
```
Schema biobanque créé avec succès ✓
```

---

## 🧪 3. Charger les données factices

Modifier les paramètres de connexion dans `02_generate_fake_data.R` si nécessaire :
```r
DB_CONFIG <- list(
  host     = "localhost",
  port     = 5432,
  dbname   = "biobanque",
  user     = "biobank_user",
  password = "biobank_pass"
)
```

Puis lancer dans R :
```r
source("02_generate_fake_data.R")
```

Sortie attendue :
```
Connexion à la base...
Génération des données...
Insertion des protocoles...
✓ Données factices chargées avec succès !
  Patients       : 120
  Prélèvements   : ~480
  Biomarqueurs N : ~1200
  Biomarqueurs Q : ~200
  Événements     : ~180
```

---

## 🖥️ 4. Lancer l'application Shiny

```r
setwd("03_shiny_app")
shiny::runApp()
# Ou
shiny::runApp(port=3838, launch.browser=TRUE)
```

### Fonctionnalités de l'interface

| Onglet | Contenu |
|--------|---------|
| **Tableau de bord** | Statistiques globales, graphiques de répartition |
| **Patients** | Table filtrée, export CSV, statut coloré |
| **Prélèvements** | Filtres par type/qualité/date, graphique |
| **Biomarqueurs** | Tables numériques + qualitatifs, distribution |
| **Visualisations** | Évolution temporelle, corrélations, boxplots |
| **Ajouter données** | Formulaires patient + prélèvement |

---

## 💾 5. Sauvegardes automatiques

### Rendre le script exécutable
```bash
chmod +x 04_backup_restore.sh
```

### Commandes manuelles
```bash
# Sauvegarde complète
./04_backup_restore.sh backup

# Lister les sauvegardes disponibles
./04_backup_restore.sh list

# Vérifier l'intégrité d'un dump
./04_backup_restore.sh check

# Restaurer la dernière sauvegarde
./04_backup_restore.sh restore

# Restaurer un fichier spécifique
./04_backup_restore.sh restore /opt/biobank/backups/biobanque_full_20240315_020000.dump

# Nettoyer les dumps de plus de 30 jours
./04_backup_restore.sh cleanup
```

### Sauvegarde automatique quotidienne (cron)
```bash
# Éditer la crontab
crontab -e

# Ajouter cette ligne (sauvegarde à 2h du matin tous les jours)
0 2 * * * /chemin/vers/biobank/04_backup_restore.sh backup >> /var/log/biobank_backup.log 2>&1
```

### Fichier ~/.pgpass (éviter de stocker le mot de passe dans le script)
```bash
echo "localhost:5432:biobanque:biobank_user:biobank_pass" >> ~/.pgpass
chmod 600 ~/.pgpass
# Puis supprimer la ligne "export PGPASSWORD" du script
```

---

## 🔒 6. Gestion multi-utilisateurs

### Créer des rôles PostgreSQL par niveau d'accès
```sql
-- Chercheur : lecture + écriture biomarqueurs
CREATE ROLE chercheur LOGIN PASSWORD 'motdepasse_chercheur';
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO chercheur;

-- Technicien : lecture + saisie prélèvements
CREATE ROLE technicien LOGIN PASSWORD 'motdepasse_tech';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO technicien;
GRANT INSERT, UPDATE ON prelevements, biomarqueurs_numeriques,
      biomarqueurs_qualitatifs TO technicien;

-- Lecteur : consultation seule
CREATE ROLE lecteur LOGIN PASSWORD 'motdepasse_lecteur';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO lecteur;
```

### Authentification dans Shiny (simple)
Ajouter dans `app.R` avant `shinyApp()` :
```r
# Protection par mot de passe simple
credentials <- data.frame(
  user     = c("admin", "chercheur", "technicien"),
  password = c("admin123", "rech456", "tech789"),
  role     = c("admin", "chercheur", "technicien"),
  stringsAsFactors = FALSE
)
# Utiliser le package shinyauthr pour une authentification complète
# install.packages("shinyauthr")
```

---

## 🔍 7. Requêtes SQL utiles

```sql
-- Résumé par patient
SELECT * FROM vue_patients_resume LIMIT 20;

-- Biomarqueurs hors normes
SELECT patient_id, biomarqueur, valeur, valeur_ref_min, valeur_ref_max
FROM biomarqueurs_numeriques
WHERE hors_norme = TRUE
ORDER BY date_mesure DESC;

-- Dernier prélèvement par patient
SELECT DISTINCT ON (patient_id)
  patient_id, prelevement_id, date_prelevement, type_prelevement
FROM prelevements
ORDER BY patient_id, date_prelevement DESC;

-- Évolution CRP pour un patient
SELECT date_mesure::date, valeur
FROM biomarqueurs_numeriques
WHERE biomarqueur = 'CRP' AND patient_id = 'PAT-2022-0001'
ORDER BY date_mesure;

-- Statistiques par protocole
SELECT p.protocole_id,
       COUNT(DISTINCT pat.patient_id) AS patients,
       AVG(bn.valeur) FILTER (WHERE bn.biomarqueur='CRP') AS crp_moyen,
       AVG(bn.valeur) FILTER (WHERE bn.biomarqueur='HbA1c') AS hba1c_moyen
FROM protocoles p
JOIN patients pat ON pat.protocole_id = p.protocole_id
JOIN biomarqueurs_numeriques bn ON bn.patient_id = pat.patient_id
GROUP BY p.protocole_id;
```

---

## 🚀 Prochaines étapes suggérées

- [ ] Ajouter **shinyauthr** pour une vraie gestion des sessions
- [ ] Déployer sur un serveur avec **Shiny Server** ou **shinyapps.io**
- [ ] Activer **SSL** sur PostgreSQL pour les connexions réseau
- [ ] Ajouter des **triggers SQL** pour l'audit automatique (table `audit_log`)
- [ ] Connecter un système de **stockage d'images** (lames histologiques, etc.)
- [ ] Exporter des rapports avec **R Markdown / Quarto**

---

> ⚠️ Ce prototype utilise uniquement des **données fictives**.  
> Avant tout usage avec des données réelles de patients, consulter le DPO de votre institution
> et vérifier la conformité RGPD / HDS.
