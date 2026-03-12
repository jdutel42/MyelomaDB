# ============================================================
# BIOBANQUE CLINIQUE - Interface R Shiny
# Script : 03_shiny_app/app.R
# ============================================================
# install.packages(c("shiny","shinydashboard","DBI","RPostgres",
#                    "DT","ggplot2","dplyr","plotly","shinyWidgets"))

library(shiny)
library(shinydashboard)
library(DBI)
library(RPostgres)
library(DT)
library(ggplot2)
library(dplyr)
library(plotly)
library(shinyWidgets)

# ============================================================
# CONNEXION DB
# ============================================================
DB <- list(host="localhost", port=5433, dbname="biobanque",
           user="dutel", password="biobank_pass")

get_con <- function() {
  dbConnect(RPostgres::Postgres(),
    host=DB$host, port=DB$port, dbname=DB$dbname,
    user=DB$user, password=DB$password)
}

safe_query <- function(query, params=NULL) {
  con <- get_con()
  on.exit(dbDisconnect(con))
  if (is.null(params)) dbGetQuery(con, query)
  else dbGetQuery(con, query, params=params)
}

# ============================================================
# UI
# ============================================================
ui <- dashboardPage(
  skin = "blue",

  dashboardHeader(title = "🧬 BioBank Manager"),

  dashboardSidebar(
    sidebarMenu(
      menuItem("Tableau de bord",  tabName="dashboard", icon=icon("chart-pie")),
      menuItem("Patients",         tabName="patients",  icon=icon("users")),
      menuItem("Prélèvements",     tabName="prelev",    icon=icon("vial")),
      menuItem("Biomarqueurs",     tabName="biomark",   icon=icon("flask")),
      menuItem("Visualisations",   tabName="visu",      icon=icon("chart-line")),
      menuItem("Ajouter données",  tabName="ajout",     icon=icon("plus-circle"))
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      .info-box { min-height: 80px; }
      .dataTables_wrapper { font-size: 13px; }
      .box-title { font-size: 15px; }
    "))),

    tabItems(

      # ----------------------------------------------------------
      # TABLEAU DE BORD
      # ----------------------------------------------------------
      tabItem(tabName="dashboard",
        fluidRow(
          infoBoxOutput("box_patients", width=3),
          infoBoxOutput("box_prelev",   width=3),
          infoBoxOutput("box_bm_num",   width=3),
          infoBoxOutput("box_bm_qual",  width=3)
        ),
        fluidRow(
          box(title="Répartition par protocole", width=6, status="primary",
              plotlyOutput("plot_proto", height="280px")),
          box(title="Répartition par sexe et statut", width=6, status="info",
              plotlyOutput("plot_sexe_statut", height="280px"))
        ),
        fluidRow(
          box(title="Prélèvements par mois", width=12, status="success",
              plotlyOutput("plot_timeline", height="220px"))
        )
      ),

      # ----------------------------------------------------------
      # PATIENTS
      # ----------------------------------------------------------
      tabItem(tabName="patients",
        fluidRow(
          box(width=12, title="Filtres", status="primary", collapsible=TRUE,
            fluidRow(
              column(3, selectInput("filt_proto", "Protocole",
                choices=c("Tous"=""), multiple=FALSE)),
              column(2, selectInput("filt_sexe", "Sexe",
                choices=c("Tous"="","M"="M","F"="F","A"="A"))),
              column(2, selectInput("filt_statut", "Statut",
                choices=c("Tous"="","actif"="actif","perdu_de_vue"="perdu_de_vue",
                          "décédé"="décédé","retiré"="retiré"))),
              column(2, numericInput("filt_age_min", "Âge min", value=18, min=0, max=120)),
              column(2, numericInput("filt_age_max", "Âge max", value=90, min=0, max=120)),
              column(1, br(), actionButton("btn_filtrer", "Filtrer", class="btn-primary btn-sm"))
            )
          )
        ),
        fluidRow(
          box(width=12, title="Liste des patients", status="success",
            downloadButton("dl_patients", "Télécharger CSV", class="btn-sm btn-info"),
            br(), br(),
            DTOutput("tbl_patients")
          )
        )
      ),

      # ----------------------------------------------------------
      # PRÉLÈVEMENTS
      # ----------------------------------------------------------
      tabItem(tabName="prelev",
        fluidRow(
          box(width=4, title="Filtres", status="primary",
            selectInput("filt_type_prel", "Type de prélèvement",
              choices=c("Tous"="","sang_total","serum","plasma","urine","LCR","biopsie")),
            selectInput("filt_qualite", "Qualité",
              choices=c("Tous"="","bonne","acceptable","degradee","rejetee")),
            dateRangeInput("filt_date_prel", "Période",
              start="2020-01-01", end=Sys.Date())
          ),
          box(width=8, title="Résumé prélèvements", status="info",
            plotlyOutput("plot_prelev_type", height="240px"))
        ),
        fluidRow(
          box(width=12, title="Table prélèvements", status="success",
            DTOutput("tbl_prelev"))
        )
      ),

      # ----------------------------------------------------------
      # BIOMARQUEURS
      # ----------------------------------------------------------
      tabItem(tabName="biomark",
        tabsetPanel(
          tabPanel("Numériques",
            br(),
            fluidRow(
              box(width=4,
                selectInput("bm_select", "Biomarqueur",
                  choices=c("CRP","IL6","TNFa","Ferritine","HbA1c","Insuline",
                            "Glucose","LDL","Hemoglobine","Leucocytes","Plaquettes")),
                checkboxInput("bm_hors_norme", "Hors normes seulement", FALSE)
              ),
              box(width=8, title="Distribution du biomarqueur sélectionné",
                plotlyOutput("plot_bm_dist", height="260px"))
            ),
            fluidRow(
              box(width=12, DTOutput("tbl_bm_num"))
            )
          ),
          tabPanel("Qualitatifs",
            br(),
            fluidRow(
              box(width=12, DTOutput("tbl_bm_qual"))
            )
          )
        )
      ),

      # ----------------------------------------------------------
      # VISUALISATIONS
      # ----------------------------------------------------------
      tabItem(tabName="visu",
        fluidRow(
          box(width=6, title="Évolution temporelle d'un biomarqueur (patient)", status="primary",
            selectInput("visu_bm",  "Biomarqueur", choices=c("CRP","IL6","HbA1c","Glucose","LDL")),
            selectInput("visu_pat", "Patient ID",  choices=NULL),
            plotlyOutput("plot_evolution", height="280px")
          ),
          box(width=6, title="Corrélation entre deux biomarqueurs", status="warning",
            selectInput("corr_bm1", "Biomarqueur X", choices=c("CRP","IL6","HbA1c","Glucose","LDL"), selected="CRP"),
            selectInput("corr_bm2", "Biomarqueur Y", choices=c("CRP","IL6","HbA1c","Glucose","LDL"), selected="IL6"),
            plotlyOutput("plot_corr", height="280px")
          )
        ),
        fluidRow(
          box(width=12, title="Boxplot par groupe (protocole)", status="success",
            selectInput("box_bm", "Biomarqueur", choices=c("CRP","IL6","HbA1c","Glucose","LDL","Hemoglobine")),
            plotlyOutput("plot_boxplot", height="300px"))
        )
      ),

      # ----------------------------------------------------------
      # AJOUT DE DONNÉES
      # ----------------------------------------------------------
      tabItem(tabName="ajout",
        fluidRow(
          box(width=6, title="➕ Ajouter un patient", status="primary",
            textInput("new_pat_id",    "ID Patient (auto si vide)"),
            dateInput("new_dob",       "Date de naissance", value="1970-01-01"),
            selectInput("new_sexe",    "Sexe", choices=c("M","F","A")),
            selectInput("new_groupe",  "Groupe sanguin",
              choices=c("A+","A-","B+","B-","AB+","AB-","O+","O-")),
            selectInput("new_proto",   "Protocole", choices=NULL),
            selectInput("new_statut",  "Statut",
              choices=c("actif","perdu_de_vue","décédé","retiré")),
            textAreaInput("new_notes", "Notes", rows=2),
            actionButton("btn_add_patient", "Enregistrer patient", class="btn-success")
          ),
          box(width=6, title="➕ Ajouter un prélèvement", status="info",
            selectInput("new_prel_pat",  "Patient ID", choices=NULL),
            dateInput("new_prel_date","Date/heure", value=Sys.time()),
            selectInput("new_prel_type", "Type",
              choices=c("sang_total","serum","plasma","urine","LCR","biopsie","autre")),
            numericInput("new_prel_vol", "Volume (mL)", value=5, min=0, max=100),
            selectInput("new_prel_qual", "Qualité",
              choices=c("bonne","acceptable","degradee","rejetee")),
            textInput("new_prel_loc",  "Localisation (congél/rack/box)"),
            actionButton("btn_add_prelev", "Enregistrer prélèvement", class="btn-success")
          )
        ),
        fluidRow(
          box(width=12,
            verbatimTextOutput("msg_ajout")
          )
        )
      )
    )
  )
)

# ============================================================
# SERVER
# ============================================================
server <- function(input, output, session) {

  # -- Données réactives --
  patients_data <- reactive({
    safe_query("SELECT * FROM vue_patients_resume ORDER BY patient_id")
  })

  protocoles_data <- reactive({
    safe_query("SELECT protocole_id, nom FROM protocoles")
  })

  # Mise à jour des listes déroulantes dynamiques
  observe({
    protos <- protocoles_data()
    choices_proto <- setNames(protos$protocole_id, paste(protos$protocole_id, "-", protos$nom))
    updateSelectInput(session, "filt_proto",  choices=c("Tous"="", choices_proto))
    updateSelectInput(session, "new_proto",   choices=choices_proto)

    pats <- patients_data()$patient_id
    updateSelectInput(session, "visu_pat",    choices=head(pats, 30))
    updateSelectInput(session, "new_prel_pat",choices=pats)
  })

  # -- INFOBOXES --
  output$box_patients <- renderInfoBox({
    n <- nrow(patients_data())
    infoBox("Patients", n, icon=icon("users"), color="blue")
  })
  output$box_prelev <- renderInfoBox({
    n <- safe_query("SELECT COUNT(*) AS n FROM prelevements")$n
    infoBox("Prélèvements", n, icon=icon("vial"), color="green")
  })
  output$box_bm_num <- renderInfoBox({
    n <- safe_query("SELECT COUNT(*) AS n FROM biomarqueurs_numeriques")$n
    infoBox("Mesures num.", n, icon=icon("flask"), color="orange")
  })
  output$box_bm_qual <- renderInfoBox({
    n <- safe_query("SELECT COUNT(*) AS n FROM biomarqueurs_qualitatifs")$n
    infoBox("Mesures qual.", n, icon=icon("dna"), color="purple")
  })

  # -- DASHBOARD PLOTS --
  output$plot_proto <- renderPlotly({
    df <- patients_data() %>%
      count(protocole_id) %>% filter(!is.na(protocole_id))
    plot_ly(df, labels=~protocole_id, values=~n, type="pie",
            textinfo="label+percent") %>%
      layout(showlegend=FALSE, margin=list(t=10,b=10))
  })

  output$plot_sexe_statut <- renderPlotly({
    df <- patients_data() %>% count(sexe, statut)
    plot_ly(df, x=~sexe, y=~n, color=~statut, type="bar") %>%
      layout(barmode="stack", xaxis=list(title="Sexe"), yaxis=list(title="N"))
  })

  output$plot_timeline <- renderPlotly({
    df <- safe_query("
      SELECT DATE_TRUNC('month', date_prelevement)::date AS mois,
             type_prelevement, COUNT(*) AS n
      FROM prelevements GROUP BY 1,2 ORDER BY 1")
    plot_ly(df, x=~mois, y=~n, color=~type_prelevement, type="scatter", mode="lines+markers") %>%
      layout(xaxis=list(title=""), yaxis=list(title="Prélèvements / mois"))
  })

  # -- TABLE PATIENTS (avec filtres) --
  patients_filtered <- eventReactive(input$btn_filtrer, {
    df <- patients_data()
    if (nchar(input$filt_proto)  > 0) df <- df %>% filter(protocole_id == input$filt_proto)
    if (nchar(input$filt_sexe)   > 0) df <- df %>% filter(sexe == input$filt_sexe)
    if (nchar(input$filt_statut) > 0) df <- df %>% filter(statut == input$filt_statut)
    df <- df %>% filter(age >= input$filt_age_min, age <= input$filt_age_max)
    df
  }, ignoreNULL=FALSE)

  output$tbl_patients <- renderDT({
    datatable(patients_filtered(),
      options=list(pageLength=20, scrollX=TRUE),
      rownames=FALSE, filter="top",
      selection="single"
    ) %>% formatStyle("statut",
      backgroundColor=styleEqual(
        c("actif","perdu_de_vue","décédé","retiré"),
        c("#d4edda","#fff3cd","#f8d7da","#e2e3e5")))
  })

  output$dl_patients <- downloadHandler(
    filename = paste0("patients_", Sys.Date(), ".csv"),
    content  = function(f) write.csv(patients_filtered(), f, row.names=FALSE)
  )

  # -- PRÉLÈVEMENTS --
  output$tbl_prelev <- renderDT({
    q <- "SELECT prelevement_id, patient_id,
                 date_prelevement::date AS date,
                 type_prelevement, volume_ml,
                 qualite, localisation, operateur
          FROM prelevements WHERE 1=1"
    params <- list()
    if (nchar(input$filt_type_prel) > 0) {
      q <- paste0(q, " AND type_prelevement=$1")
      params <- list(input$filt_type_prel)
    }
    df <- if (length(params)>0) safe_query(q, params) else safe_query(q)
    datatable(df, options=list(pageLength=20, scrollX=TRUE), rownames=FALSE, filter="top")
  })

  output$plot_prelev_type <- renderPlotly({
    df <- safe_query("SELECT type_prelevement, COUNT(*) AS n FROM prelevements GROUP BY 1")
    plot_ly(df, x=~type_prelevement, y=~n, type="bar", color=~type_prelevement) %>%
      layout(showlegend=FALSE, xaxis=list(title=""), yaxis=list(title="N"))
  })

  # -- BIOMARQUEURS NUMÉRIQUES --
  bm_num_data <- reactive({
    q <- paste0("SELECT * FROM biomarqueurs_numeriques WHERE biomarqueur='",
                input$bm_select, "'")
    if (input$bm_hors_norme) q <- paste0(q, " AND hors_norme=TRUE")
    safe_query(q)
  })

  output$tbl_bm_num <- renderDT({
    df <- bm_num_data() %>% select(patient_id, date_mesure, biomarqueur, valeur, unite,
                                    valeur_ref_min, valeur_ref_max, hors_norme, methode)
    datatable(df, options=list(pageLength=15, scrollX=TRUE), rownames=FALSE) %>%
      formatStyle("hors_norme",
        backgroundColor=styleEqual(c(TRUE,FALSE), c("#f8d7da","#d4edda")))
  })

  output$plot_bm_dist <- renderPlotly({
    df <- bm_num_data()
    if (nrow(df)==0) return(plotly_empty())
    fig <- plot_ly(df, x=~valeur, type="histogram", nbinsx=30,
                   marker=list(color="steelblue", line=list(color="white", width=0.5)))
    ref_min <- df$valeur_ref_min[1]; ref_max <- df$valeur_ref_max[1]
    if (!is.na(ref_min)) fig <- fig %>% add_segments(x=ref_min,xend=ref_min,y=0,yend=20,
                                line=list(color="red",dash="dash"), name="ref min")
    if (!is.na(ref_max)) fig <- fig %>% add_segments(x=ref_max,xend=ref_max,y=0,yend=20,
                                line=list(color="red",dash="dash"), name="ref max")
    fig %>% layout(xaxis=list(title=paste(input$bm_select, df$unite[1])),
                   yaxis=list(title="Effectif"))
  })

  output$tbl_bm_qual <- renderDT({
    df <- safe_query("SELECT patient_id, date_mesure, biomarqueur, resultat, methode, operateur
                      FROM biomarqueurs_qualitatifs ORDER BY date_mesure DESC")
    datatable(df, options=list(pageLength=15, scrollX=TRUE), rownames=FALSE, filter="top")
  })

  # -- VISUALISATIONS --
  output$plot_evolution <- renderPlotly({
    req(input$visu_bm, input$visu_pat)
    df <- safe_query(
      "SELECT date_mesure, valeur, unite FROM biomarqueurs_numeriques
       WHERE biomarqueur=$1 AND patient_id=$2 ORDER BY date_mesure",
      params=list(input$visu_bm, input$visu_pat))
    if (nrow(df)==0) return(plotly_empty() %>% layout(title="Pas de données"))
    plot_ly(df, x=~date_mesure, y=~valeur, type="scatter", mode="lines+markers",
            line=list(color="steelblue")) %>%
      layout(xaxis=list(title="Date"), yaxis=list(title=paste(input$visu_bm, df$unite[1])),
             title=paste(input$visu_pat, "-", input$visu_bm))
  })

  output$plot_corr <- renderPlotly({
    df1 <- safe_query(
      "SELECT patient_id, AVG(valeur) AS v1 FROM biomarqueurs_numeriques
       WHERE biomarqueur=$1 GROUP BY patient_id", params=list(input$corr_bm1))
    df2 <- safe_query(
      "SELECT patient_id, AVG(valeur) AS v2 FROM biomarqueurs_numeriques
       WHERE biomarqueur=$1 GROUP BY patient_id", params=list(input$corr_bm2))
    df <- inner_join(df1, df2, by="patient_id")
    if (nrow(df) < 5) return(plotly_empty())
    plot_ly(df, x=~v1, y=~v2, type="scatter", mode="markers",
            text=~patient_id, hoverinfo="text+x+y",
            marker=list(color="coral", size=8)) %>%
      layout(xaxis=list(title=input$corr_bm1), yaxis=list(title=input$corr_bm2))
  })

  output$plot_boxplot <- renderPlotly({
    df <- safe_query(
      "SELECT bn.valeur, p.protocole_id FROM biomarqueurs_numeriques bn
       JOIN patients p ON p.patient_id=bn.patient_id
       WHERE bn.biomarqueur=$1", params=list(input$box_bm))
    if (nrow(df)==0) return(plotly_empty())
    plot_ly(df, y=~valeur, color=~protocole_id, type="box") %>%
      layout(xaxis=list(title="Protocole"), yaxis=list(title=input$box_bm))
  })

  # -- AJOUT PATIENT --
  observeEvent(input$btn_add_patient, {
    tryCatch({
      con <- get_con()
      on.exit(dbDisconnect(con))
      age <- as.numeric(difftime(Sys.Date(), input$new_dob, units="days")) / 365.25
      if (age < 18) { output$msg_ajout <- renderText("Erreur : le patient doit être majeur."); return() }
      pid <- if (nchar(trimws(input$new_pat_id))>0) trimws(input$new_pat_id)
             else paste0("PAT-", format(Sys.Date(),"%Y"), "-", sample(1000:9999,1))
      dbExecute(con,
        "INSERT INTO patients(patient_id,date_naissance,sexe,groupe_sanguin,
                               consentement,date_inclusion,protocole_id,statut,notes)
         VALUES($1,$2,$3,$4,$5,$6,$7,$8,$9)",
        params=list(pid, input$new_dob, input$new_sexe, input$new_groupe,
                    TRUE, Sys.Date(), input$new_proto, input$new_statut,
                    input$new_notes))
      output$msg_ajout <- renderText(paste("✓ Patient", pid, "ajouté avec succès."))
    }, error=function(e) output$msg_ajout <- renderText(paste("Erreur:", e$message)))
  })

  # -- AJOUT PRÉLÈVEMENT --
  observeEvent(input$btn_add_prelev, {
    tryCatch({
      con <- get_con()
      on.exit(dbDisconnect(con))
      prid <- paste0("PRE-", format(Sys.Date(),"%Y%m%d"), "-", sample(1000:9999,1))
      dbExecute(con,
        "INSERT INTO prelevements(prelevement_id,patient_id,date_prelevement,
                                   type_prelevement,volume_ml,qualite,localisation)
         VALUES($1,$2,$3,$4,$5,$6,$7)",
        params=list(prid, input$new_prel_pat, input$new_prel_date,
                    input$new_prel_type, input$new_prel_vol,
                    input$new_prel_qual, input$new_prel_loc))
      output$msg_ajout <- renderText(paste("✓ Prélèvement", prid, "ajouté."))
    }, error=function(e) output$msg_ajout <- renderText(paste("Erreur:", e$message)))
  })
}

# ============================================================
# LANCEMENT
# ============================================================
shinyApp(ui=ui, server=server)
