# ============================================================
# BIOBANQUE CLINIQUE - Génération de données factices réalistes
# Script R : 02_generate_fake_data.R
# ============================================================
# Packages requis : RPostgres, DBI, dplyr, lubridate
# install.packages(c("RPostgres","DBI","dplyr","lubridate","stringr"))

library(DBI)
library(RPostgres)
library(dplyr)
library(lubridate)
library(stringr)

set.seed(42)  # Reproductibilité

# ============================================================
# PARAMÈTRES DE CONNEXION
# Modifier selon votre configuration locale
# ============================================================
DB_CONFIG <- list(
  host     = "localhost",
  port     = 5433,
  dbname   = "biobanque",
  user     = "dutel",
  password = "biobank_pass"
)

# ============================================================
# CONNEXION
# ============================================================
connect_db <- function() {
  dbConnect(
    RPostgres::Postgres(),
    host     = DB_CONFIG$host,
    port     = DB_CONFIG$port,
    dbname   = DB_CONFIG$dbname,
    user     = DB_CONFIG$user,
    password = DB_CONFIG$password
  )
}

# ============================================================
# HELPERS
# ============================================================
rand_date <- function(n, from, to) {
  as.Date(sample(seq(as.Date(from), as.Date(to), by="day"), n, replace=TRUE))
}

rand_id_patient <- function(n) {
  years <- sample(2020:2024, n, replace=TRUE)
  nums  <- str_pad(sample(1:9999, n, replace=FALSE), 4, pad="0")
  paste0("PAT-", years, "-", nums)
}

rand_id_prelev <- function(dates) {
  d   <- format(dates, "%Y%m%d")
  num <- str_pad(seq_along(dates), 4, pad="0")
  paste0("PRE-", d, "-", num)
}


# ============================================================
# 1. PROTOCOLES
# ============================================================
generate_protocoles <- function() {
  data.frame(
    protocole_id  = c("PROTO-ONCO-01","PROTO-DIAB-01","PROTO-CARD-01","PROTO-NEURO-01"),
    nom           = c(
      "Suivi biomarqueurs oncologie colorectale",
      "Cohorte diabète type 2 - biomarqueurs métaboliques",
      "Prévention cardiovasculaire primaire",
      "Biomarqueurs neuro-inflammatoires"
    ),
    description   = c(
      "Étude longitudinale sur marqueurs tumoraux CCR",
      "Suivi HbA1c, insuline, adipokines",
      "Suivi lipidique et inflammatoire",
      "LCR et plasma - marqueurs sclérose en plaques"
    ),
    date_debut    = as.Date(c("2020-01-01","2021-03-01","2019-06-01","2022-01-01")),
    date_fin      = as.Date(c("2026-12-31","2026-12-31","2025-06-30","2027-12-31")),
    responsable   = c("Dr. Martin","Dr. Dubois","Pr. Bernard","Dr. Lefevre"),
    statut        = rep("actif", 4),
    stringsAsFactors = FALSE
  )
}

# ============================================================
# 2. PATIENTS (n = 120)
# ============================================================
generate_patients <- function(n = 120) {
  protocoles <- c("PROTO-ONCO-01","PROTO-DIAB-01","PROTO-CARD-01","PROTO-NEURO-01")
  centres    <- c("CHU-PARIS","CHU-LYON","HOPITAL-NORD","CLINIQUE-SUD","CHU-BORDEAUX")
  ethnies    <- c("européen","africain","asiatique","latino","autre","non_renseigné")
  groupes    <- c("A+","A-","B+","B-","AB+","AB-","O+","O-")
  freq_gp    <- c(.34,.06,.09,.02,.03,.01,.38,.07)

  ages <- round(rnorm(n, mean=55, sd=15))
  ages <- pmax(18, pmin(90, ages))

  date_naiss  <- as.Date("2024-01-01") - years(ages) - days(sample(0:364, n, replace=TRUE))
  date_incl   <- rand_date(n, "2020-01-01", "2024-06-30")

  data.frame(
    patient_id     = rand_id_patient(n),
    date_naissance = date_naiss,
    sexe           = sample(c("M","F"), n, replace=TRUE, prob=c(.48,.52)),
    groupe_sanguin = sample(groupes, n, replace=TRUE, prob=freq_gp),
    ethnie         = sample(ethnies, n, replace=TRUE, prob=c(.55,.15,.12,.08,.05,.05)),
    consentement   = sample(c(TRUE,FALSE), n, replace=TRUE, prob=c(.97,.03)),
    date_inclusion = date_incl,
    protocole_id   = sample(protocoles, n, replace=TRUE),
    centre_id      = sample(centres, n, replace=TRUE),
    statut         = sample(c("actif","perdu_de_vue","décédé","retiré"), n,
                            replace=TRUE, prob=c(.78,.10,.07,.05)),
    notes          = NA_character_,
    stringsAsFactors = FALSE
  )
}

# ============================================================
# 3. PRÉLÈVEMENTS (2 à 6 par patient)
# ============================================================
generate_prelevements <- function(patients_df) {
  types_tube <- list(
    "sang_total" = "EDTA",
    "serum"      = "SST",
    "plasma"     = "Héparine",
    "urine"      = "stérile",
    "LCR"        = "stérile"
  )
  locs <- paste0("Congel-", LETTERS[1:4], "/Rack-", rep(1:5,4), "/Box-", rep(1:10, each=4))
  ops  <- c("Tech.Dupont","Tech.Martin","Tech.Girard","Tech.Moreau","Inf.Bernard")

  compteur <- 0

  prelevements <- lapply(1:nrow(patients_df), function(i) {
    pat  <- patients_df[i,]
    nb   <- sample(2:6, 1)
    d_min <- max(pat$date_inclusion, as.Date("2020-01-01"))
    dates <- sort(rand_date(nb, d_min, "2024-12-31"))
    type  <- sample(names(types_tube), nb, replace=TRUE, prob=c(.40,.25,.20,.10,.05))
    vol   <- round(runif(nb, 0.5, 10), 2)

    ids <- sapply(1:nb, function(j) {
      compteur <<- compteur + 1
      paste0("PRE-", format(dates[j], "%Y%m%d"), "-", str_pad(compteur, 5, pad="0"))
    })

    data.frame(
      prelevement_id       = ids,
      patient_id           = pat$patient_id,
      date_prelevement     = as.POSIXct(dates) + hours(sample(7:17, nb, replace=TRUE)),
      type_prelevement     = type,
      volume_ml            = vol,
      tube_type            = sapply(type, function(t) types_tube[[t]]),
      operateur            = sample(ops, nb, replace=TRUE),
      temperature_stockage = sample(c(-80,-20,-4), nb, replace=TRUE, prob=c(.6,.3,.1)),
      localisation         = sample(locs, nb, replace=TRUE),
      qualite              = sample(c("bonne","acceptable","degradee","rejetee"), nb,
                                   replace=TRUE, prob=c(.75,.15,.07,.03)),
      notes                = NA_character_,
      stringsAsFactors     = FALSE
    )
  })
  do.call(rbind, prelevements)
}

# ============================================================
# 4. BIOMARQUEURS NUMÉRIQUES
# ============================================================
generate_biomarqueurs_num <- function(prelevements_df, patients_df) {

  # Définition des biomarqueurs par type de prélèvement
  bm_config <- list(
    serum = list(
      CRP    = list(m=5,   s=8,   min=0,   max=200, unit="mg/L",  ref_min=0,  ref_max=10),
      IL6    = list(m=8,   s=12,  min=0,   max=500, unit="pg/mL", ref_min=0,  ref_max=7),
      TNFa   = list(m=15,  s=20,  min=0,   max=300, unit="pg/mL", ref_min=0,  ref_max=22),
      Ferritine = list(m=150,s=200, min=5, max=5000, unit="ng/mL", ref_min=12, ref_max=300)
    ),
    plasma = list(
      HbA1c   = list(m=6.5, s=1.5, min=4,  max=14,  unit="%",     ref_min=4,  ref_max=6),
      Insuline = list(m=12, s=8,   min=2,   max=100, unit="µUI/mL",ref_min=3,  ref_max=25),
      Glucose  = list(m=5.8,s=1.8, min=3,  max=25,  unit="mmol/L",ref_min=3.9,ref_max=6.1),
      LDL      = list(m=3.2,s=1.0, min=0.5,max=9,   unit="mmol/L",ref_min=0,  ref_max=3)
    ),
    sang_total = list(
      Hemoglobine = list(m=13,s=2, min=5, max=20, unit="g/dL", ref_min=12, ref_max=17),
      Leucocytes  = list(m=7, s=3, min=1, max=30, unit="G/L",  ref_min=4,  ref_max=10),
      Plaquettes  = list(m=230,s=70,min=50,max=600,unit="G/L", ref_min=150,ref_max=400)
    )
  )

  rows <- list()
  for (i in 1:nrow(prelevements_df)) {
    pr   <- prelevements_df[i,]
    type <- pr$type_prelevement
    if (!type %in% names(bm_config)) next

    bms <- bm_config[[type]]
    for (bm_name in names(bms)) {
      cfg <- bms[[bm_name]]
      val <- max(cfg$min, min(cfg$max, rnorm(1, cfg$m, cfg$s)))
      rows[[length(rows)+1]] <- data.frame(
        prelevement_id  = pr$prelevement_id,
        patient_id      = pr$patient_id,
        date_mesure     = pr$date_prelevement + hours(2),

        biomarqueur     = bm_name,
        valeur          = round(val, 3),
        unite           = cfg$unit,
        methode         = sample(c("ELISA","Luminex","Spectrophotométrie","Automate"), 1),
        appareil        = sample(c("Cobas 8000","XTEND","Luminex 200","Sysmex XN"), 1),
        operateur       = sample(c("Tech.Dupont","Tech.Martin","Tech.Girard"), 1),
        valeur_ref_min  = cfg$ref_min,
        valeur_ref_max  = cfg$ref_max,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

# ============================================================
# 5. BIOMARQUEURS QUALITATIFS
# ============================================================
generate_biomarqueurs_qual <- function(prelevements_df) {
  bm_qual <- list(
    serum = list(
      "Anticorps_ANA"  = c("négatif","positif_faible","positif_fort"),
      "Rheumatoid_factor" = c("négatif","positif")
    ),
    plasma = list(
      "Mutation_BRCA1" = c("non_muté","muté","variant_incertain"),
      "Statut_MSI"     = c("MSS","MSI-L","MSI-H")
    )
  )

  rows <- list()
  for (i in 1:nrow(prelevements_df)) {
    pr   <- prelevements_df[i,]
    type <- pr$type_prelevement
    if (!type %in% names(bm_qual)) next
    for (bm_name in names(bm_qual[[type]])) {
      if (runif(1) > 0.6) next  # Pas tous les prélèvements ont ce test
      vals <- bm_qual[[type]][[bm_name]]
      rows[[length(rows)+1]] <- data.frame(
        prelevement_id = pr$prelevement_id,
        patient_id     = pr$patient_id,
        date_mesure    = pr$date_prelevement + hours(3),
        biomarqueur    = bm_name,
        resultat       = sample(vals, 1, prob=c(.70, rep(.30/max(1,length(vals)-1), length(vals)-1))),
        methode        = sample(c("PCR","NGS","IHC","FISH"), 1),
        operateur      = sample(c("Tech.Dupont","Tech.Martin"), 1),
        notes          = NA_character_,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

# ============================================================
# 6. ÉVÉNEMENTS CLINIQUES
# ============================================================
generate_evenements <- function(patients_df) {
  types_ev   <- c("hospitalisation","consultation","recidive","progression","remission","deces","effet_secondaire")
  severites  <- c("faible","modérée","sévère","critique")

  rows <- lapply(1:nrow(patients_df), function(i) {
    pat <- patients_df[i,]
    nb  <- sample(0:4, 1, prob=c(.3,.35,.2,.10,.05))
    if (nb == 0) return(NULL)
    dates <- rand_date(nb, pat$date_inclusion, "2024-12-31")
    data.frame(
      patient_id     = pat$patient_id,
      date_evenement = dates,
      type_evenement = sample(types_ev, nb, replace=TRUE),
      description    = paste("Événement enregistré le", dates),
      severite       = sample(severites, nb, replace=TRUE, prob=c(.45,.35,.15,.05)),
      stringsAsFactors = FALSE
    )
  })
  rows <- Filter(Negate(is.null), rows)
  do.call(rbind, rows)
}

# ============================================================
# 7. UTILISATEURS
# ============================================================
generate_utilisateurs <- function() {
  data.frame(
    login  = c("admin","dr.martin","dr.dubois","tech.dupont","tech.martin","lecteur1"),
    nom    = c("Administrateur","Dr. Martin Pierre","Dr. Dubois Sophie",
               "Dupont Jean","Martin Aline","Leclerc Paul"),
    role   = c("admin","chercheur","chercheur","technicien","technicien","lecteur"),
    actif  = TRUE,
    stringsAsFactors = FALSE
  )
}

# ============================================================
# CHARGEMENT EN BASE
# ============================================================
load_all <- function() {
  cat("Connexion à la base...\n")
  con <- connect_db()
  on.exit(dbDisconnect(con))

  cat("Génération des données...\n")
  protocoles  <- generate_protocoles()
  patients    <- generate_patients(120)
  prelevements<- generate_prelevements(patients)
  bm_num      <- generate_biomarqueurs_num(prelevements, patients)
  bm_qual     <- generate_biomarqueurs_qual(prelevements)
  evenements  <- generate_evenements(patients)
  utilisateurs<- generate_utilisateurs()

  cat("Insertion des protocoles...\n")
  dbWriteTable(con, "protocoles", protocoles, append=TRUE, row.names=FALSE)

  cat("Insertion des patients...\n")
  dbWriteTable(con, "patients", patients, append=TRUE, row.names=FALSE)

  cat("Insertion des prélèvements...\n")
  dbWriteTable(con, "prelevements", prelevements, append=TRUE, row.names=FALSE)

  cat("Insertion des biomarqueurs numériques...\n")
  dbWriteTable(con, "biomarqueurs_numeriques", bm_num, append=TRUE, row.names=FALSE)

  cat("Insertion des biomarqueurs qualitatifs...\n")
  dbWriteTable(con, "biomarqueurs_qualitatifs", bm_qual, append=TRUE, row.names=FALSE)

  cat("Insertion des événements cliniques...\n")
  dbWriteTable(con, "evenements_cliniques", evenements, append=TRUE, row.names=FALSE)

  cat("Insertion des utilisateurs...\n")
  dbWriteTable(con, "utilisateurs", utilisateurs, append=TRUE, row.names=FALSE)

  cat("\n✓ Données factices chargées avec succès !\n")
  cat("  Patients       :", nrow(patients), "\n")
  cat("  Prélèvements   :", nrow(prelevements), "\n")
  cat("  Biomarqueurs N :", nrow(bm_num), "\n")
  cat("  Biomarqueurs Q :", nrow(bm_qual), "\n")
  cat("  Événements     :", nrow(evenements), "\n")
}

# Lancer le chargement
load_all()
