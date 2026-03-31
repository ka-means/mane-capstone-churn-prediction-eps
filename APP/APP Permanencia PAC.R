# app.R

library(shiny)
library(shinydashboard)
library(DT)
library(dplyr)
library(recipes)
library(ranger)
library(data.table)
library(lubridate)
library(ggplot2)
library(plotly)
library(stringr)
library(scales)
library(survival)
library(arrow)


perm_activos <- arrow::read_parquet("Permanencia_Activos.parquet") |> 
  as.data.frame() |>
  mutate(AFILIADO_ID_EPS = as.character(AFILIADO_ID_EPS)) |>
  distinct(AFILIADO_ID_EPS, .keep_all = TRUE)



ALL_OPT <- "TODOS"
LEVELS_0_1_2_5_6P <- c("0","1","2 a 5","6+")


pal <- list(
  blue_primary   = "#1775b1",
  green_primary  = "#74bf66",
  blue_soft      = "#82adc9",
  green_soft     = "#abd4a5",
  green_dark     = "#125e04",
  black          = "#000000",
  blue_alt       = "#1976b2",
  navy           = "#2a2e3a",
  link_blue      = "#3779e3",
  green_alt      = "#449864",
  orange         = "#e99842",
  gray           = "#809da6",
  bg             = "#f6f8fb",
  white          = "#ffffff"
)


custom_js <- "
function formatIntThousands(raw) {
  raw = (raw || '').toString();
  // dejar solo dígitos
  raw = raw.replace(/[^0-9]/g, '');
  // quitar ceros líderes
  raw = raw.replace(/^0+(?=\\d)/, '');
  if (raw.length === 0) raw = '0';
  // miles con coma
  return raw.replace(/\\B(?=(\\d{3})+(?!\\d))/g, ',');
}

function bindIntThousands(id) {
  var el = document.getElementById(id);
  if (!el) return;

  // formatear valor inicial
  el.value = formatIntThousands(el.value);

  // sugerir teclado numérico (mobile)
  el.setAttribute('inputmode', 'numeric');
  el.setAttribute('autocomplete', 'off');

  el.addEventListener('input', function() {
    var old = el.value || '';
    var pos = el.selectionStart || 0;

    // cuántos dígitos había a la izquierda del cursor (ignorando comas)
    var leftDigits = old.slice(0, pos).replace(/[^0-9]/g, '').length;

    var formatted = formatIntThousands(old);
    el.value = formatted;

    // reubicar cursor basado en cantidad de dígitos
    var i = 0, digits = 0;
    while (i < formatted.length && digits < leftDigits) {
      if (/\\d/.test(formatted.charAt(i))) digits++;
      i++;
    }
    try { el.setSelectionRange(i, i); } catch(e) {}

    // avisar a Shiny
    el.dispatchEvent(new Event('change', { bubbles: true }));
  });

  el.addEventListener('blur', function() {
    el.value = formatIntThousands(el.value || '');
    el.dispatchEvent(new Event('change', { bubbles: true }));
  });
}

function bindAllMoney() {
  ['LTV_CLIENTE','COSTO_LLAMADA','COSTO_INCENTIVO','PRESUPUESTO_N'].forEach(bindIntThousands);
}

document.addEventListener('DOMContentLoaded', function() {
  bindAllMoney();
  // por si Shiny demora en pintar o re-renderiza
  setTimeout(bindAllMoney, 300);
  setTimeout(bindAllMoney, 1200);
});

// si está Shiny, reintenta al conectar
if (window.jQuery) {
  jQuery(document).on('shiny:connected', function() {
    bindAllMoney();
    setTimeout(bindAllMoney, 300);
  });
}
"


custom_css <- sprintf("
@import url('https://fonts.googleapis.com/css2?family=Barlow:wght@300;400;500;600;700&display=swap');

body, label, input, button, select, textarea { font-family: 'Barlow', sans-serif !important; }

.content-wrapper, .right-side { background: %s !important; }
.wrapper { background: %s !important; }

.skin-blue .main-header .navbar { background-color: %s !important; border-bottom: 0 !important; }
.skin-blue .main-header .logo { background-color: %s !important; color: %s !important; border-bottom: 0 !important; }
.skin-blue .main-header .logo:hover { background-color: %s !important; }

.app-title { display: flex; align-items: center; gap: 30px; }
.app-title img { height: 28px; }
.app-title span{ font-weight: 600; letter-spacing: 0.2px; }

.skin-blue .main-sidebar, .skin-blue .left-side{
  background-color: #1775b1 !important;
  border-right: none !important;
}
.skin-blue .sidebar a,
.skin-blue .sidebar-menu > li > a{
  color: #ffffff !important;
  font-weight: 500;
}
.skin-blue .sidebar-menu > li.active > a,
.skin-blue .sidebar-menu > li.active:hover > a{
  background: #74bf66 !important;
  color: #ffffff !important;
  border-left: 4px solid #74bf66 !important;
}
.skin-blue .sidebar-menu > li:hover > a{
  background: #82adc9 !important;
  color: #2a2e3a !important;
  border-left: 4px solid #74bf66 !important;
}
.sidebar-footer{
  position: absolute;
  bottom: 10px;
  left: 0;
  right: 0;
  padding: 10px 15px;
  color: rgba(255,255,255,0.85) !important;
  font-size: 12px;
  border-top: 1px solid rgba(255,255,255,0.18) !important;
  text-align: center;
}

.box {
  border-top: 0 !important;
  border-radius: 12px !important;
  box-shadow: 0 6px 18px rgba(0,0,0,0.06) !important;
}
.box .box-header {
  border-top-left-radius: 12px !important;
  border-top-right-radius: 12px !important;
}
.box.box-primary > .box-header { background: %s !important; color: %s !important; }
.box.box-success > .box-header { background: %s !important; color: %s !important; }
.box.box-warning > .box-header { background: %s !important; color: %s !important; }

.btn-primary { background: %s !important; border-color: %s !important; }
.btn-primary:hover { background: %s !important; border-color: %s !important; }
.btn-success { background: %s !important; border-color: %s !important; }

.btn-white-text, .btn-white-text:hover, .btn-white-text:focus {
      color: #FFFFFF !important;
    }

.logo-chip{
  background: #ffffff;
  border-radius: 10px;
  padding: 4px 8px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  box-shadow: 0 2px 6px rgba(0,0,0,0.10);
}
.logo-chip img{ height: 26px; width: auto; display: block; }

.metric-card{
  background: #ffffff;
  border-radius: 12px;
  padding: 14px 16px;
  box-shadow: 0 6px 18px rgba(0,0,0,0.06);
  border-left: 5px solid #74bf66;
  min-height: 78px;
}
.metric-title{ font-size: 12px; color: #809da6; font-weight: 600; margin-bottom: 6px; }
.metric-value{ font-size: 22px; font-weight: 700; color: #2a2e3a; line-height: 1.1; }
.metric-sub{ font-size: 12px; color: #809da6; margin-top: 4px; }

.icons-row{
  display:flex; gap:12px; flex-wrap:wrap; align-items:center; justify-content:center;
  padding: 6px 0 2px 0;
}
.cluster-icon{
  width: 64px; height: 64px; border-radius: 12px; cursor: pointer;
  box-shadow: 0 4px 10px rgba(0,0,0,0.10);
  background: #fff;
}
.cluster-icon:hover{ transform: translateY(-1px); }
.icon-label{ text-align:center; font-size:12px; color:#809da6; margin-top:4px; font-weight:600; }
.icon-wrap{ display:flex; flex-direction:column; align-items:center; }


.cluster-head{
  display:flex;
  align-items:center;
  gap:14px;
}
.cluster-head img{
  width:64px;
  height:64px;
  border-radius:14px;
  background:#fff;
    box-shadow: 0 4px 10px rgba(0,0,0,0.10);
  object-fit: cover;
}
.cluster-head .cluster-title{
  font-size:16px;
  font-weight:700;
}
.cluster-head .cluster-sub{
  font-size:12px;
  color:#ffffffcc;
    font-weight:500;
  margin-top:2px;
}
.cluster-body ul{ margin: 0 0 0 18px; }

.icons-side{
  display:grid;
  grid-template-columns: repeat(2, 1fr); /* 2 columnas => 3x2 si hay 6 */
  gap: 12px;
  padding-top: 10px;
}

.icon-card{
  display:flex;
  flex-direction:column;
  align-items:center;
  gap:6px;
  padding:10px 8px;
  border-radius:14px;
  background:#ffffff;
  box-shadow: 0 6px 18px rgba(0,0,0,0.06);
  cursor:pointer;
}

.icon-card:hover{ transform: translateY(-1px); }

.icon-card img{
  width: 70px;     /* un poco más pequeño */
  height: 70px;
  border-radius: 14px;
  object-fit: cover;
  background:#fff;
}

.icon-name{
  font-size: 11px;
  font-weight: 700;
  color:#2a2e3a;
  text-align:center;
  line-height: 1.1;
}

.icon-pct{
  font-size: 11px;
  font-weight: 600;
  color:#809da6;
}


/* SOLO tabla tbl_fuga_activos */
#tbl_fuga_activos_dt tbody td,
#tbl_fuga_activos_dt thead th {
  padding: 4px 6px !important;
  line-height: 1.1 !important;
  font-size: 12px !important;
}

#tbl_fuga_activos_dt thead th {
  padding-top: 5px !important;
  padding-bottom: 5px !important;
}



",
pal$bg, pal$bg,
pal$blue_primary, pal$blue_primary, pal$white, pal$blue_alt,
pal$blue_primary, pal$white,
pal$green_primary, pal$white,
pal$orange, pal$navy,
pal$blue_primary, pal$blue_primary, pal$blue_alt, pal$blue_alt,
pal$green_alt, pal$green_alt
)



detect_sep <- function(path){
  x <- readLines(path, n = 1, warn = FALSE, encoding = "UTF-8")
  c_comma <- str_count(x, ",")
  c_semi  <- str_count(x, ";")
  c_tab   <- str_count(x, "\t")
  if (c_semi >= c_comma && c_semi >= c_tab) return(";")
  if (c_tab  >= c_comma && c_tab  >= c_semi) return("\t")
  return(",")
}

parse_date_any <- function(x){
  out <- suppressWarnings(dmy(x))
  out2 <- suppressWarnings(ymd(x))
  as.Date(ifelse(is.na(out), out2, out), origin = "1970-01-01")
}

safe_num <- function(x){
  suppressWarnings(as.numeric(gsub(",", ".", as.character(x), fixed = FALSE)))
}


read_pac_local <- function(path = "Base_Final_Modelos_PAC.csv"){
  if (!file.exists(path)) stop("No encuentro el archivo local: ", path)
  sep <- detect_sep(path)
  
  dt <- data.table::fread(
    path, sep = sep, encoding = "UTF-8",
    na.strings = c("", "NA", "NaN", "NULL", "null"),
    showProgress = FALSE
  )
  setnames(dt, names(dt), str_trim(names(dt)))
  df <- as.data.frame(dt)
  
  if ("FECHA_INICIO" %in% names(df)) df$FECHA_INICIO <- parse_date_any(df$FECHA_INICIO)
  if ("FECHA_FIN"    %in% names(df)) df$FECHA_FIN    <- parse_date_any(df$FECHA_FIN)
  
  num_cols <- intersect(
    c("EDAD_FECHA_FIN",
      "Prestaciones_PAC","Prestaciones_PBS","Prestaciones_PAC_FIN","Prestaciones_PBS_FIN",
      "Inquietud_PAC","Inquietud_PBS","Inquietud_PAC_FIN","Inquietud_PBS_FIN",
      "Peticion_PAC","Peticion_PBS","Peticion_PAC_FIN","Peticion_PBS_FIN",
      "Queja_PAC","Queja_PBS","Queja_PAC_FIN","Queja_PBS_FIN",
      "Sugerencia_PAC","Sugerencia_PBS","Sugerencia_PAC_FIN","Sugerencia_PBS_FIN"),
    names(df)
  )
  for (cc in num_cols) df[[cc]] <- safe_num(df[[cc]])
  
  cat_cols <- intersect(
    c("FALLA","TIPO_AFILIADO","Regional_Agrupadora","CONDICION_SALUD","Sexo_Cd","POLIZA","NIVEL_INGRESO",
      "GRUPO_CAUSA_CANCELACION","Compania","PLAN","TIPO_IPS","SEGMENTO_EDAD"),
    names(df)
  )
  for (cc in cat_cols) df[[cc]] <- as.character(df[[cc]])
  
  df
}

last_spell_by_affiliate <- function(df){
  if (!("AFILIADO_ID_EPS" %in% names(df))) return(df)
  if (!("FECHA_FIN" %in% names(df))) return(df)
  
  df %>%
    arrange(AFILIADO_ID_EPS, FECHA_FIN) %>%
    group_by(AFILIADO_ID_EPS) %>%
    slice_tail(n = 1) %>%
    ungroup()
}


add_metrics <- function(df){
  
  # ESTADO / is_cancel
  if ("FALLA" %in% names(df)) {
    df$ESTADO <- ifelse(df$FALLA == "CANCELADOS", "CANCELADOS", "ACTIVOS")
  } else if ("ESTADO" %in% names(df)) {
    df$ESTADO <- as.character(df$ESTADO)
  } else {
    df$ESTADO <- NA_character_
  }
  df$is_cancel <- as.integer(df$ESTADO == "CANCELADOS")
  
  
  if (all(c("Prestaciones_PAC","Prestaciones_PBS") %in% names(df))) {
    df$consumos_total <- dplyr::coalesce(df$Prestaciones_PAC, 0) + dplyr::coalesce(df$Prestaciones_PBS, 0)
  } else if (all(c("Prestaciones_PAC_FIN","Prestaciones_PBS_FIN") %in% names(df))) {
    df$consumos_total <- dplyr::coalesce(df$Prestaciones_PAC_FIN, 0) + dplyr::coalesce(df$Prestaciones_PBS_FIN, 0)
  } else {
    df$consumos_total <- 0
    if ("Prestaciones_PAC" %in% names(df))     df$consumos_total <- df$consumos_total + dplyr::coalesce(df$Prestaciones_PAC, 0)
    if ("Prestaciones_PBS" %in% names(df))     df$consumos_total <- df$consumos_total + dplyr::coalesce(df$Prestaciones_PBS, 0)
    if ("Prestaciones_PAC_FIN" %in% names(df)) df$consumos_total <- df$consumos_total + dplyr::coalesce(df$Prestaciones_PAC_FIN, 0)
    if ("Prestaciones_PBS_FIN" %in% names(df)) df$consumos_total <- df$consumos_total + dplyr::coalesce(df$Prestaciones_PBS_FIN, 0)
  }
  
  
  pqrs_cols_total <- intersect(
    c("Inquietud_PAC","Inquietud_PBS","Peticion_PAC","Peticion_PBS","Queja_PAC","Queja_PBS","Sugerencia_PAC","Sugerencia_PBS"),
    names(df)
  )
  pqrs_cols_fin <- intersect(
    c("Inquietud_PAC_FIN","Inquietud_PBS_FIN","Peticion_PAC_FIN","Peticion_PBS_FIN",
      "Queja_PAC_FIN","Queja_PBS_FIN","Sugerencia_PAC_FIN","Sugerencia_PBS_FIN"),
    names(df)
  )
  
  if (length(pqrs_cols_total) > 0) {
    df$pqrs_total <- rowSums(as.data.frame(lapply(df[pqrs_cols_total], function(x) dplyr::coalesce(x, 0))), na.rm = TRUE)
  } else if (length(pqrs_cols_fin) > 0) {
    df$pqrs_total <- rowSums(as.data.frame(lapply(df[pqrs_cols_fin], function(x) dplyr::coalesce(x, 0))), na.rm = TRUE)
  } else {
    df$pqrs_total <- NA_real_
  }
  
  
  cut_0_1_2_5_6p <- function(x){
    x <- dplyr::coalesce(as.numeric(x), 0)
    out <- dplyr::case_when(
      x <= 0 ~ "0",
      x == 1 ~ "1",
      x >= 2 & x <= 5 ~ "2 a 5",
      x >= 6 ~ "6+",
      TRUE ~ NA_character_
    )
    factor(out, levels = LEVELS_0_1_2_5_6P, ordered = TRUE)
  }
  
  df$consumos_cat <- cut_0_1_2_5_6p(df$consumos_total)
  df$pqrs_cat     <- cut_0_1_2_5_6p(df$pqrs_total)
  
  df
}


plotly_style <- function(p){
  p %>% layout(
    font = list(family = "Barlow", color = pal$navy),
    paper_bgcolor = pal$white,
    plot_bgcolor  = pal$white
  ) %>% config(displayModeBar = FALSE)
}

center_title <- function(p, title_text){
  p %>% layout(
    title = list(
      text = paste0("<b>", title_text, "</b>"),
      x = 0.5, xanchor = "center"
    )
  )
}


plot_bar_metric <- function(df, var, metric = c("count","rate"), title = NULL){
  metric <- match.arg(metric)
  if (!(var %in% names(df))) {
    return(plotly_style(center_title(plotly_empty(type="bar"), paste("No existe", var))))
  }
  
  dd <- df %>%
    mutate(vv = as.character(.data[[var]])) %>%
    filter(!is.na(vv), vv != "") %>%
    group_by(vv) %>%
    summarise(
      afiliados = n(),
      tasa_cancel = mean(is_cancel, na.rm = TRUE),
      .groups = "drop"
    )
  
  if (nrow(dd) == 0) {
    return(plotly_style(center_title(plotly_empty(type="bar"), "Sin datos con filtros actuales")))
  }
  
  if (metric == "count") {
    dd <- dd %>% arrange(desc(afiliados))
    xvals <- dd$afiliados
    xlab <- "Afiliados"
    barcolor <- pal$blue_primary
    hover <- "Afiliados: %{x}<extra></extra>"
  } else {
    dd <- dd %>% arrange(desc(tasa_cancel))
    xvals <- dd$tasa_cancel
    xlab <- "Tasa de cancelación"
    barcolor <- pal$orange
    hover <- "Tasa cancelación: %{x:.1%}<extra></extra>"
  }
  
  dd$vv <- factor(dd$vv, levels = rev(dd$vv), ordered = TRUE)
  
  p <- plot_ly(
    dd,
    x = xvals,
    y = ~vv,
    type = "bar",
    orientation = "h",
    marker = list(color = barcolor, opacity = 0.92),
    hovertemplate = paste0(var, ": %{y}<br>", hover)
  ) %>%
    layout(
      xaxis = list(title = xlab, gridcolor = "rgba(0,0,0,0.06)", zeroline = FALSE),
      yaxis = list(title = "", gridcolor = "rgba(0,0,0,0.00)"),
      margin = list(l = 170, r = 20, t = 65, b = 45)
    )
  
  plotly_style(center_title(p, title %||% var))
}

plot_piramide <- function(df, metric = c("count","rate")){
  metric <- match.arg(metric)
  
  if (!all(c("EDAD_FECHA_FIN","Sexo_Cd") %in% names(df))) {
    return(plotly_style(center_title(plotly_empty(type="bar"), "Faltan EDAD_FECHA_FIN / Sexo_Cd")))
  }
  
  dd <- df %>%
    filter(is.finite(EDAD_FECHA_FIN), !is.na(Sexo_Cd), Sexo_Cd != "") %>%
    mutate(
      edad_bin = cut(EDAD_FECHA_FIN, breaks = seq(0, 100, by = 5), right = FALSE, include.lowest = TRUE),
      Sexo_Cd = toupper(Sexo_Cd)
    ) %>%
    group_by(edad_bin, Sexo_Cd) %>%
    summarise(
      n = n(),
      tasa_cancel = mean(is_cancel, na.rm = TRUE),
      .groups = "drop"
    )
  
  if (nrow(dd) == 0) {
    return(plotly_style(center_title(plotly_empty(type="bar"), "Sin datos para pirámide")))
  }
  
  dd_w <- tidyr::pivot_wider(dd, names_from = Sexo_Cd, values_from = c(n, tasa_cancel), values_fill = 0)
  
  if (!("n_M" %in% names(dd_w))) dd_w$n_M <- 0
  if (!("n_F" %in% names(dd_w))) dd_w$n_F <- 0
  if (!("tasa_cancel_M" %in% names(dd_w))) dd_w$tasa_cancel_M <- 0
  if (!("tasa_cancel_F" %in% names(dd_w))) dd_w$tasa_cancel_F <- 0
  
  dd_w <- dd_w %>% arrange(edad_bin)
  
  if (metric == "count") {
    dd_w$M_left  <- -dd_w$n_M
    dd_w$F_right <-  dd_w$n_F
    xlab <- "Afiliados"
    maxv <- max(dd_w$n_M, dd_w$n_F, na.rm = TRUE)
    tickformat <- NULL
    title_txt <- "Pirámide poblacional (Total de afiliados)"
    hoverM <- "Sexo: M<br>Edad: %{y}<br>Afiliados: %{customdata}<extra></extra>"
    hoverF <- "Sexo: F<br>Edad: %{y}<br>Afiliados: %{x}<extra></extra>"
    customM <- dd_w$n_M
  } else {
    dd_w$M_left  <- -dd_w$tasa_cancel_M
    dd_w$F_right <-  dd_w$tasa_cancel_F
    xlab <- "Tasa de cancelación"
    maxv <- max(dd_w$tasa_cancel_M, dd_w$tasa_cancel_F, na.rm = TRUE)
    maxv <- max(maxv, 0.01)
    tickformat <- ".0%"
    title_txt <- "Pirámide poblacional (Tasa de cancelación)"
    hoverM <- "Sexo: M<br>Edad: %{y}<br>Tasa cancelación: %{customdata:.1%}<extra></extra>"
    hoverF <- "Sexo: F<br>Edad: %{y}<br>Tasa cancelación: %{x:.1%}<extra></extra>"
    customM <- dd_w$tasa_cancel_M
  }
  
  p <- plot_ly(dd_w, y = ~edad_bin) %>%
    add_bars(
      x = ~M_left, name = "M", orientation = "h",
      marker = list(color = pal$blue_soft, opacity = 0.90),
      customdata = customM,
      hovertemplate = hoverM
    ) %>%
    add_bars(
      x = ~F_right, name = "F", orientation = "h",
      marker = list(color = pal$green_soft, opacity = 0.90),
      hovertemplate = hoverF
    ) %>%
    layout(
      barmode = "overlay",
      xaxis = list(
        title = xlab,
        range = c(-maxv * 1.15, maxv * 1.15),
        tickformat = tickformat,
        gridcolor = "rgba(0,0,0,0.06)",
        zeroline = TRUE, zerolinecolor = "rgba(0,0,0,0.15)"
      ),
      yaxis = list(title = "", gridcolor = "rgba(0,0,0,0.00)"),
      legend = list(orientation = "h", x = 0.5, xanchor = "center", y = 1.08),
      margin = list(l = 130, r = 20, t = 75, b = 45)
    )
  
  plotly_style(center_title(p, title_txt))
}


build_new_raw <- function(input, expected_cols) {
  `%||%` <- function(a,b) if (!is.null(a) && !is.na(a) && a != "") a else b
  
  
  x <- setNames(as.list(rep(0, length(expected_cols))), expected_cols)
  
  
  if ("CONDICION_SALUD" %in% names(x)) x[["CONDICION_SALUD"]] <- NA_character_
  if ("NIVEL_INGRESO"   %in% names(x)) x[["NIVEL_INGRESO"]]   <- NA_character_
  if ("PLAN"            %in% names(x)) x[["PLAN"]]            <- NA_character_
  
  if ("POLIZA_BIN" %in% names(x)) x[["POLIZA_BIN"]] <- NA_real_
  
  new_raw <- as.data.frame(x, stringsAsFactors = FALSE)
  
  
  if ("CONDICION_SALUD" %in% names(new_raw))
    new_raw$CONDICION_SALUD <- input$CONDICION_SALUD %||% "unknown"
  
  if ("NIVEL_INGRESO" %in% names(new_raw))
    new_raw$NIVEL_INGRESO <- input$NIVEL_INGRESO %||% "unknown"
  
  if ("PLAN" %in% names(new_raw))
    new_raw$PLAN <- input$PLAN %||% "unknown"
  
  if ("Sexo_Cd_BIN" %in% names(new_raw))
    new_raw$Sexo_Cd_BIN <- suppressWarnings(as.integer(input$Sexo_Cd_BIN))
  
  
  if ("POLIZA_BIN" %in% names(new_raw)) {
    v <- toupper(trimws(as.character(input$POLIZA_BIN)))
    
    new_raw$POLIZA_BIN <- dplyr::case_when(
      v %in% c("SI", "SÍ", "YES", "Y", "1") ~ 1,
      v %in% c("NO", "N", "0")              ~ 0,
      TRUE                                  ~ NA_real_
    )
  }
  
  
  if ("RAMO_FAMILIAR" %in% names(new_raw))
    new_raw$RAMO_FAMILIAR <- suppressWarnings(as.integer(input$RAMO_FAMILIAR))
  
  set_dummy <- function(prefix, val) {
    nm <- paste0(prefix, val)
    if (nm %in% names(new_raw)) new_raw[[nm]] <- 1L
  }
  
  set_dummy("SEGMENTO_EDAD_",       input$SEGMENTO_EDAD)
  set_dummy("TIPO_AFILIADO_",       input$TIPO_AFILIADO)
  set_dummy("Regional_Agrupadora_", input$Regional_Agrupadora)
  set_dummy("Compania_",            input$Compania)
  set_dummy("TIPO_IPS_",            input$TIPO_IPS)
  
  
  if ("CONDICION_SALUD" %in% names(new_raw)) {
    new_raw$CONDICION_SALUD <- factor(new_raw$CONDICION_SALUD,
                                      levels = c("BAJA","MEDIA","ALTA","unknown","new"))
  }
  if ("NIVEL_INGRESO" %in% names(new_raw)) {
    new_raw$NIVEL_INGRESO <- factor(new_raw$NIVEL_INGRESO,
                                    levels = c("A","B","C","unknown","new"))
  }
  if ("PLAN" %in% names(new_raw)) {
    new_raw$PLAN <- factor(new_raw$PLAN,
                           levels = c("BRONCE","PLATA","ORO","DIAMANTE","unknown","new"))
  }
  
  new_raw
}




build_raw_from_df <- function(df, expected_raw_cols) {
  n <- nrow(df)
  nr <- as.data.frame(matrix(NA, nrow = n, ncol = length(expected_raw_cols)))
  names(nr) <- expected_raw_cols
  
  get_int <- function(x) suppressWarnings(as.integer(as.character(x)))
  
  if ("CONDICION_SALUD" %in% expected_raw_cols && "CONDICION_SALUD" %in% names(df)) nr$CONDICION_SALUD <- get_int(df$CONDICION_SALUD)
  if ("NIVEL_INGRESO"   %in% expected_raw_cols && "NIVEL_INGRESO"   %in% names(df)) nr$NIVEL_INGRESO   <- get_int(df$NIVEL_INGRESO)
  if ("PLAN"            %in% expected_raw_cols && "PLAN"            %in% names(df)) nr$PLAN            <- get_int(df$PLAN)
  
  
  if ("Sexo_Cd_BIN" %in% expected_raw_cols) {
    if ("Sexo_Cd_BIN" %in% names(df)) {
      nr$Sexo_Cd_BIN <- get_int(df$Sexo_Cd_BIN)
    } else if ("Sexo_Cd" %in% names(df)) {
      s <- toupper(trimws(as.character(df$Sexo_Cd)))
      nr$Sexo_Cd_BIN <- ifelse(s == "M", 1L, ifelse(s == "F", 0L, NA_integer_))
    }
  }
  
  if ("POLIZA_BIN" %in% expected_raw_cols) {
    if ("POLIZA_BIN" %in% names(df)) {
      nr$POLIZA_BIN <- get_int(df$POLIZA_BIN)
    } else if ("POLIZA" %in% names(df)) {
      s <- toupper(trimws(as.character(df$POLIZA)))
      nr$POLIZA_BIN <- ifelse(s %in% c("SI","SÍ","YES","1","TRUE"), 1L,
                              ifelse(s %in% c("NO","0","FALSE"), 0L, NA_integer_))
    }
  }
  
  if ("RAMO_FAMILIAR" %in% expected_raw_cols) {
    if ("RAMO_FAMILIAR" %in% names(df)) {
      nr$RAMO_FAMILIAR <- get_int(df$RAMO_FAMILIAR)
    } else if ("RAMO_FAMILIAR_BIN" %in% names(df)) {
      nr$RAMO_FAMILIAR <- get_int(df$RAMO_FAMILIAR_BIN)
    }
  }
  
  set_one_hot_df <- function(prefix, src_col) {
    cols <- grep(paste0("^", prefix), expected_raw_cols, value = TRUE)
    if (length(cols) == 0) return(invisible(NULL))
    
    nr[cols] <- 0L
    if (!(src_col %in% names(df))) return(invisible(NULL))
    
    vals <- as.character(df[[src_col]])
    sel_cols <- paste0(prefix, vals)
    idx <- match(sel_cols, cols)
    ok <- which(!is.na(idx))
    if (length(ok) > 0) {
      col_pos <- match(cols, names(nr))
      nr[cbind(ok, col_pos[idx[ok]])] <- 1L
    }
    invisible(NULL)
  }
  
  set_one_hot_df("SEGMENTO_EDAD_",        "SEGMENTO_EDAD")
  set_one_hot_df("TIPO_AFILIADO_",        "TIPO_AFILIADO")
  set_one_hot_df("Regional_Agrupadora_",  "Regional_Agrupadora")
  set_one_hot_df("Compania_",             "Compania")
  set_one_hot_df("TIPO_IPS_",             "TIPO_IPS")
  
  nr
}



predict_rsf_profile <- function(art, new_raw, horizons = c(1,3,6,12,18,24)) {
  
  X_new <- bake(art$recipe, new_data = new_raw)
  pr <- predict(art$model, data = X_new)
  
  times <- art$model$unique.death.times
  if (is.null(times)) times <- pr$unique.death.times
  times <- as.numeric(times)
  
  surv_obj <- pr$survival
  surv <- if (is.matrix(surv_obj)) as.numeric(surv_obj[1, ]) else as.numeric(surv_obj)
  
  df_curve <- data.frame(t = times, S_t = surv) |>
    dplyr::arrange(t) |>
    dplyr::mutate(risk_t = 1 - S_t)
  
  get_S_at <- function(h) {
    idx <- which(df_curve$t <= h)
    if (length(idx) == 0) return(1)
    df_curve$S_t[max(idx)]
  }
  
  risk_by_h <- sapply(horizons, function(h) 1 - get_S_at(h))
  names(risk_by_h) <- paste0("risk_", horizons, "m")
  
  list(curve = df_curve, risk = risk_by_h)
}

clean_cluster <- function(x){
  x0 <- trimws(as.character(x))
  
  x0[x0 %in% c("-1", "999")] <- "999"
  
  
  out <- suppressWarnings(as.integer(stringr::str_extract(x0, "-?\\d+")))
  out
}

`%||%` <- function(a, b) if (!is.null(a)) a else b



pretty_feature_name <- function(x) {
  x <- as.character(x)
  x <- gsub("_", " ", x, fixed = TRUE)
  x <- gsub("\\s+", " ", x)
  x <- trimws(x)
  
  x <- sapply(strsplit(tolower(x), " "), function(w) {
    paste0(toupper(substring(w, 1, 1)), substring(w, 2), collapse = " ")
  })
  unname(x)
}

sample_by_group <- function(df, group_col = "feature", max_n = 1500, seed = 123) {
  group_col <- rlang::ensym(group_col)
  set.seed(seed)
  
  df %>%
    dplyr::group_by(!!group_col) %>%
    dplyr::mutate(.n_grp = dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::group_by(!!group_col) %>%
    dplyr::slice_sample(
      n = dplyr::first(pmin(.n_grp, max_n)),
      replace = FALSE
    ) %>%
    dplyr::ungroup() %>%
    dplyr::select(-.n_grp)
}

# =========================
# UI
# =========================

ui <- dashboardPage(
  skin = "blue",
  title = "Análisis de Fuga PAC",
  
  dashboardHeader(
    titleWidth = 190,
    title = tags$div(
      class = "app-title",
      tags$div(class = "logo-chip", tags$img(src = "LOGO.png", alt = "EPS ABC")),
      tags$span(class = "app-title-text", "PAC")
    )
  ),
  
  dashboardSidebar(
    width = 220,
    sidebarMenu(
      id = "tabs",
      menuItem("Introducción", tabName = "intro", icon = icon("info-circle")),
      menuItem("Análisis Descriptivo", tabName = "datos", icon = icon("database")),
      menuItem("Perfiles", tabName = "km", icon = icon("sliders-h")),
      menuItem("Cancelación", tabName = "cancel", icon = icon("chart-line")),
      menuItem("Impacto Financiero", tabName = "impacto", icon = icon("calculator"))
    ),
    div(class = "sidebar-footer", "EPS ABC - MANE UC CHILE")
  ),
  
  dashboardBody(
    tags$head(
      tags$link(rel = "icon", type = "image/png", href = "favicon.png"),
      tags$style(HTML(custom_css)),
      tags$script(HTML(custom_js))
    ),
    
    
    
    tabItems(
      tabItem(
        tabName = "intro",
        fluidRow(
          column(
            width = 10, offset = 1,
            box(
              
              width = 12, status = "primary", solidHeader = TRUE,
              title = "Gestión Estratégica de Permanencia en el PAC",
              
              
              tags$div(
                style = "font-size:18px; line-height:1.6;",
                
                
                tags$div(
                  style = "text-align:center; margin-bottom:12px;",
                  tags$img(
                    src = "logos.png",
                    style = "max-width:520px; width:100%; height:auto;"
                  )
                ),
                br(),
                
                tags$p(
                  "Esta app permite realizar un análisis integral y accionable de la fuga de afiliados del Plan Complementario de la EPS ABC. ",
                  "A través de visualizaciones ejecutivas e interactivas, integra en un solo lugar la segmentación de afiliados, la estimación del riesgo de cancelación ",
                  "y la explicabilidad de los factores que impulsan la fuga o sostienen la permanencia. ",
                  "De esta manera se pueden identificar con claridad los principales focos de fricción, priorizar iniciativas de retención con mejor costo–beneficio ",
                  "y monitorear señales tempranas relacionadas con uso del plan, costos, red prestadora y experiencia del afiliado."
                ),
                
                tags$hr(),
                
                tags$h4("Índice de navegación", style = "font-size:18px; margin-top:8px;"),
                tags$ul(
                  tags$li(tags$b("Análisis descriptivo de la cartera: "), 
                          "Caracterización de afiliados activos y patrones asociados a quienes ya cancelaron."),
                  tags$li(tags$b("Perfiles de afiliados: "),
                          "Segmentos operativos para diseñar acciones específicas por perfil."),
                  tags$li(tags$b("Cancelación:"),
                          "Causas y señales de fuga, probabilidad de cancelación en activos y curva de permanencia para nuevos."),
                  tags$li(tags$b("Escenarios financieros: "),
                          "Impacto económico, beneficios de reducir fuga y soporte para priorización e inversión.")
                )
              )
            )
          )
        )
        
      ),
      
      
      tabItem(
        tabName = "datos",
        
        fluidRow(
          box(
            width = 12, status = "success", solidHeader = TRUE,
            title = "Filtros",
            uiOutput("filters_grid")
          )
        ),
        
        fluidRow(
          box(
            width = 12, status = "primary", solidHeader = TRUE,
            title = "Análisis de variables",
            fluidRow(
              column(
                12,
                radioButtons(
                  "bar_metric",
                  label = NULL,
                  choices = c("Total de afiliados" = "count", "Tasa de cancelación" = "rate"),
                  selected = "count",
                  inline = TRUE
                )
              )
            ),
            br(),
            
            
            fluidRow(
              column(6, plotlyOutput("plt_tipo", height = 320)),
              column(6, plotlyOutput("plt_regional", height = 320))
            ),
            br(),
            fluidRow(
              column(6, plotlyOutput("plt_salud", height = 320)),
              column(6, plotlyOutput("plt_plan", height = 320))
            ),
            br(),
            fluidRow(
              column(6, plotlyOutput("plt_ingreso", height = 320)),
              column(6, plotlyOutput("plt_ips", height = 320))
            ),
            br(),
            fluidRow(
              column(6, plotlyOutput("plt_seg_edad", height = 320)),
              column(6, plotlyOutput("plt_poliza", height = 320))
            ),
            br(),
            fluidRow(
              column(6, plotlyOutput("plt_causa", height = 320)),
              column(6, plotlyOutput("plt_compania", height = 320))
            ),
            br(),
            fluidRow(
              column(6, plotlyOutput("plt_consumos_cat", height = 320)),
              column(6, plotlyOutput("plt_pqrs_cat", height = 320))
            ),
            br(),
            plotlyOutput("plt_piramide", height = 520)
          )
        )
      ),
      
      tabItem(
        tabName = "km",
        
        fluidRow(
          tabBox(
            width = 12,
            
            
            
            tabPanel(
              "Información",
              
              box(
                width = 12,
                status = "primary",
                solidHeader = TRUE,
                title = "Ficha técnica y guía de uso",
                tags$div(
                  style = "font-size:16px; line-height:1.6;",
                  
                  tags$p(
                    "En esta sección la app agrupa a los afiliados que ya cancelaron en 4 perfiles claros, para entender por qué se van y, sobre todo, qué se puede hacer para evitar que se repita en los afiliados que hoy siguen activos.",
                  ),
                  
                  tags$p(
                    "Además del resumen de cada perfil, la app permite comparar cómo se comporta cada perfil por variables clave, mostrando qué características dominan en cada uno y qué tanto pesa cada perfil dentro de cada variable. Esto habilita decisiones accionables, por ejemplo en el Plan identificar planes que concentran perfiles desconectados del valor y requieren ajuste de comunicación.",
                    
                  ),
                  
                  
                  hr(),
                  tags$h4(style="margin-top:14px; font-weight:700;", "Metodología de construcción de perfiles"),
                  tags$p(
                    "Para construir los perfiles se usó una combinación moderna y altamente robusta: UMAP + HDBSCAN.",
                    
                  ),
                  
                  tags$ul(
                    tags$li(tags$b("UMAP:"), " sintetiza múltiples variables en una representación compacta manteniendo la estructura de similitud entre afiliados."),
                    tags$li(tags$b("HDBSCAN:"), " detecta grupos reales sin forzar asignaciones y separa casos atípicos como “ruido”.")
                  ),
                  
                  
                  tags$h4(style="margin-top:14px; font-weight:700;", "Por qué estos perfiles son confiables"),
                  tags$ul(
                    tags$li(tags$b("Alta seguridad de clasificación:"), " 98.31% de los afiliados quedan clasificados con alta confianza (p_high ≥ 0.7)."),
                    tags$li(tags$b("Buena separación de grupos:"), " los perfiles están bien diferenciados evitando mezcla (Silhouette 0.6618)."),
                    tags$li(tags$b("Poco ruido:"), " solo 1.70% quedan como atípicos, lo que indica perfiles consistentes.")
                  ),
                  
                  
                  tags$h4(style="margin-top:14px; font-weight:700;", "Cómo usar esta sección para decisiones"),
                  tags$ol(
                    tags$li("Enfócate primero en perfiles con mayor volumen y mayor fuga para maximizar impacto."),
                    tags$li("Cruza el perfil con Regional, IPS, Canal y Plan para ubicar focos concretos de intervención."),
                    tags$li("Traduce el hallazgo en acción: ajustes de comunicación, mejoras de experiencia, gestión de red o priorización operativa.")
                  ),
                  
                )
              )
              
            ),
            
            
            tabPanel(
              "Análisis de perfiles",
              
              fluidRow(
                box(
                  width = 12,
                  status = "primary",
                  solidHeader = TRUE,
                  title = "Perfiles",
                  
                  
                  tabBox(
                    width = 12,
                    id = "perfiles_subtabs",
                    
                    #        tabPanel(
                    #          "Cancelados",
                    fluidRow(
                      column(8, plotlyOutput("pie_cancelados", height = 420)),
                      column(4, uiOutput("icons_cancelados_side"))
                    ),
                    #        ),
                    
                    #       tabPanel(
                    #          "Activos",
                    #          fluidRow(
                    #            column(8, plotlyOutput("pie_activos", height = 420)),
                    #            column(4, uiOutput("icons_activos_side"))
                    #          )
                    #        )
                  )
                )
              ),
              
              
              fluidRow(
                box(
                  width = 12,
                  status = "info",
                  solidHeader = TRUE,
                  title = "Comportamiento de cada variable por Perfil",
                  
                  fluidRow(
                    column(
                      4,
                      selectInput(
                        "var_cluster_dist",
                        "Variable para analizar con Perfil",
                        choices = c(
                          "Plan"               = "PLAN",
                          "Regional"           = "Regional_Agrupadora",
                          "Canal de ingreso"   = "Compania",
                          "Tipo afiliado"      = "TIPO_AFILIADO",
                          "Tipo IPS"           = "TIPO_IPS",
                          "Condición de salud" = "CONDICION_SALUD",
                          "Nivel de ingreso"   = "NIVEL_INGRESO",
                          "Segmento de edad"   = "SEGMENTO_EDAD"
                        ),
                        selected = "PLAN"
                      )
                    ),
                    column(
                      4,
                      radioButtons(
                        "metric_cluster_dist",
                        "Métrica",
                        choices = c("Conteo" = "count", "% Participación" = "pct_cluster"),
                        selected = "pct_cluster",
                        inline = TRUE
                      )
                    ),
                    column(
                      4,
                      radioButtons(
                        "barmode_cluster_dist",
                        "Tipo de barras",
                        choices = c("Apiladas" = "stack", "Agrupadas" = "group"),
                        selected = "group",
                        inline = TRUE
                      )
                    )
                  ),
                  
                  br(),
                  plotlyOutput("plt_cluster_dist", height = 420)
                )
              )
            )
          )
        )
      )
      ,
      
      tabItem(
        tabName = "cancel",
        
        tabBox(
          width = 12,
          id = "cancel_subtabs",
          
          
          tabPanel(
            "Información",
            
            box(
              width = 12,
              status = "primary",
              solidHeader = TRUE,
              title = "Ficha técnica y guía de uso",
              tags$div(
                style = "font-size:16px; line-height:1.65;",
                
                tags$p(
                  "Este capítulo convierte la analítica de fuga en acción. Integra qué factores explican la cancelación, quiénes son los afiliados activos con mayor riesgo y en qué ventana de tiempo conviene intervenir, para priorizar gestión comercial y de experiencia con enfoque costo–beneficio."
                ),
                
                tags$hr(),
                
                
                tags$h4(style="margin-top:14px; font-weight:700;", "Modelos y alcance"),
                tags$p(
                  "Se usaron dos modelos complementarios: XGBoost para estimar la probabilidad de fuga y RSF para entregar una curva de permanencia personalizada por afiliado. En desempeño, XGBoost distingue bien entre quienes tienden a cancelar y quienes tienden a permanecer (AUC 0.859) y permite una priorización efectiva como es el caso del 10% de los afiliados de mayor riesgo que concentra 3.3 veces más fuga que una selección aleatoria. El RSF, por su parte, ordena bien el riesgo en el tiempo (C-index 0.818) y mantiene buena capacidad de separación por horizontes, lo que habilita decisiones estratégicas con una intervención a corto plazo o sostener una gestión gradual."
                  
                ),
                
                
                tags$hr(),
                
                tags$h4(style="margin-top:14px; font-weight:700;", "Qué encontrarás en este capítulo"),
                tags$ul(
                  tags$li(
                    tags$b("Impacto de Variables: "),
                    "importancia y dirección del efecto en la fuga acompañado de curvas de permanencia por variable para identificar señales tempranas."
                  ),
                  tags$li(
                    tags$b("Fuga afiliados activos: "),
                    "tabla priorizable con probabilidad de fuga, distribución de riesgos, ",
                    "grupos operativos y curva de permanencia por afiliado."
                  ),
                  tags$li(
                    tags$b("Permanencia afiliados nuevos: "),
                    "módulo para simular perfiles de ingreso y obtener riesgo a 1, 3, 6 y 12 meses y toda su curva estimada de permanencia."
                  )
                )
                
                
              )
            )
          ),
          
          
          
          tabPanel(
            "Impacto de Variables",
            
            fluidRow(
              column(
                width = 8,
                box(
                  width = 12, status = "primary", solidHeader = TRUE,
                  title = "Importancia de variables",
                  plotlyOutput("plt_importancia_variables", height = "650px")
                )
              ),
              column(
                width = 4,
                box(
                  width = 12, status = "info", solidHeader = TRUE,
                  title = "Análisis de variables",
                  htmlOutput("shap_insights")
                )
              )
            ),
            
            
            fluidRow(
              box(
                width = 12, status = "primary", solidHeader = TRUE,
                title = "Curva de permanencia por variable",
                uiOutput("ui_imp_var"),
                plotlyOutput("plt_surv_by_var", height = "420px")
              )
              
              
            )
          ),
          
          
          tabPanel(
            "Fuga afiliados activos",
            
            fluidRow(
              box(
                width = 12, status = "success", solidHeader = TRUE,
                title = "Filtros",
                uiOutput("filters_grid_fuga")
              )
            ),
            
            fluidRow(
              box(
                width = 8, status = "primary", solidHeader = TRUE,
                title = "Probabilidad de fuga",
                
                fluidRow(
                  column(
                    4,
                    selectInput(
                      "fuga_page_len",
                      "Filas por página",
                      choices = c(5, 10, 15, 25, 50, 100),
                      selected = 10
                    )
                  )
                ),
                br(),
                DTOutput("tbl_fuga_activos")
              ),
              
              column(
                4,
                
                box(
                  width = 12, status = "primary", solidHeader = TRUE,
                  title = "Distribución de probabilidades",
                  plotlyOutput("plt_risk_box", height = 280)
                ),
                
                box(
                  width = 12, status = "info", solidHeader = TRUE,
                  title = "Grupos operativos",
                  DTOutput("tbl_grupo_operativo")
                )
              )
            ),
            
            
            fluidRow(
              box(
                width = 12, status = "primary", solidHeader = TRUE,
                title = "Curva de permanencia por afiliado",
                br(),
                plotlyOutput("plt_surv_fuga", height = "380px")
              )
            )
            
          )
          ,
          
          
          tabPanel(
            "Permanencia afiliados nuevos",
            
            fluidRow(
              box(
                width = 4, status = "primary", solidHeader = TRUE,
                title = "Perfil del nuevo afiliado",
                
                fluidRow(
                  column(6,
                         selectInput("SEGMENTO_EDAD", "Segmento de edad", choices = c(
                           "DEPENDIENTE" = "01_DEPENDIENTE", "ADULTO JOVEN" = "02_ADULTOJOVEN", "PRODUCTIVO" = "03_PRODUCTIVO", "ADULTO MAYOR" = "04_ADULTOMAYOR"
                         ), selected = "02_ADULTOJOVEN")
                  ),
                  column(6,
                         selectInput("TIPO_AFILIADO", "Tipo afiliado", choices = c(
                           "ASEGURADO COLECTIVO" = "ASEGURADO_COLECTIVO", "ASEGURADO FAMILIAR" = "ASEGURADO_FAMILIAR", "TOMADOR FAMILIAR" = "TOMADOR_FAMILIAR"
                         ), selected = "TOMADOR_FAMILIAR")
                  ),
                  
                  column(6,
                         selectInput("Regional_Agrupadora", "Regional", choices = c(
                           "CENTRO", "NORTE", "SUR", "ORIENTE", "OCCIDENTE"
                         ), selected = "NORTE")
                  ),
                  column(6,
                         selectInput("Compania", "Canal de ingreso", choices = c(
                           "DIGITAL", "PROPIO", "TERCERO"
                         ), selected = "PROPIO")
                  ),
                  
                  column(6,
                         selectInput("TIPO_IPS", "Tipo IPS", choices = c(
                           "ALIADA", "CONVENIO", "EXCLUSIVA", "PROPIA", "SIN_INFORMACION"
                         ), selected = "ALIADA")
                  ),
                  column(6,
                         selectInput("CONDICION_SALUD", "Condición de salud", choices = c(
                           "BAJA" = "BAJA", "MEDIA" = "MEDIA", "ALTA" = "ALTA"
                         ), selected = "BAJA")
                  ),
                  
                  column(6,
                         selectInput("NIVEL_INGRESO", "Nivel de ingreso", choices = c(
                           "A" = "A", "B" = "B", "C" = "C"
                         ), selected = "A")
                  ),
                  column(6,
                         selectInput("PLAN", "Plan", choices = c(
                           "BRONCE" = "BRONCE", "PLATA" = "PLATA", "ORO" = "ORO", "DIAMANTE" = "DIAMANTE"
                         ), selected = "ORO")
                  ),
                  
                  column(6,
                         radioButtons("Sexo_Cd_BIN", "Sexo",
                                      choices = c("F" = 0, "M" = 1), selected = 1, inline = TRUE)
                  ),
                  column(6,
                         radioButtons("POLIZA_BIN", "¿Tiene póliza?",
                                      choices = c("No" = 0, "Sí" = 1), selected = 0, inline = TRUE)
                  ),
                  
                  column(6,
                         radioButtons("RAMO_FAMILIAR", "Ramo familiar",
                                      choices = c("No" = 0, "Sí" = 1), selected = 1, inline = TRUE)
                  ),
                  column(6,
                         dateInput("fecha_base", "Fecha base", value = Sys.Date(), format = "yyyy-mm-dd")
                  ),
                  
                  column(12,
                         actionButton("btn_score", "Calcular Permanencia", class = "btn-primary btn-white-text")
                  )
                )
                
              ),
              
              box(
                width = 8, status = "primary", solidHeader = TRUE,
                title = "Permanencia estimada en cada mes",
                
                fluidRow(
                  column(3,
                         div(class="metric-card",
                             div(class="metric-title","Riesgo de fuga 1 mes"),
                             div(class="metric-value", textOutput("m_r1")),
                             div(class="metric-sub", textOutput("m_f1"))
                         )),
                  column(3,
                         div(class="metric-card",
                             div(class="metric-title","Riesgo de fuga 3 meses"),
                             div(class="metric-value", textOutput("m_r3")),
                             div(class="metric-sub", textOutput("m_f3"))
                         )),
                  column(3,
                         div(class="metric-card",
                             div(class="metric-title","Riesgo de fuga 6 meses"),
                             div(class="metric-value", textOutput("m_r6")),
                             div(class="metric-sub", textOutput("m_f6"))
                         )),
                  column(3,
                         div(class="metric-card",
                             div(class="metric-title","Riesgo de fuga 12 meses"),
                             div(class="metric-value", textOutput("m_r12")),
                             div(class="metric-sub", textOutput("m_f12"))
                         ))
                ),
                
                br(),
                plotlyOutput("plot_surv", height = 348),
                
              )
            )
          )
        )
      ),
      
      
      tabItem(
        tabName = "impacto",
        
        
        tabBox(
          width = 12,
          id = "impacto_subtabs",
          
          
          tabPanel(
            "Información",
            
            fluidRow(
              box(
                width = 12,
                status = "primary",
                solidHeader = TRUE,
                title = "Ficha técnica y guía de uso",
                tags$div(
                  style = "font-family: 'Barlow', sans-serif; font-size:16px; line-height:1.6;",
                  
                  tags$p(
                    "En esta sección la app convierte el riesgo de fuga en impacto financiero, permitiendo responder a la pregunta:",
                    tags$b("si invierto en retención, ¿A quiénes debo gestionar y cuánto valor puedo recuperar? "),  
                    
                    "La simulación combina el riesgo estimado de cancelación con supuestos de negocio ",
                    "para entregar una lectura ejecutiva de ganancia neta, ROI y sensibilidad."
                  ),
                  
                  tags$h4(style="margin-top:14px; font-weight:700;", "1) Parámetros de simulación"),
                  tags$ul(
                    tags$li(tags$b("Valor promedio del cliente:"), " ingreso neto promedio que aporta un afiliado durante su permanencia en el PAC."),
                    tags$li(tags$b("Costo llamada:"), " costo unitario de la gestión de contacto por medio del call center."),
                    tags$li(tags$b("Costo incentivo:"), " bono o descuento ofrecido para aumentar la permanencia."),
                    tags$li(tags$b("Presupuesto de gestiones:"), " límite de afiliados que se puede gestionar con la capacidad operativa."),
                    tags$li(tags$b("Tasa de éxito del agente:"), " proporción de afiliados de alto riesgo que se logra retener tras la gestión.")
                  ),
                  
                  tags$h4(style="margin-top:14px; font-weight:700;", "2) Curva de rentabilidad"),
                  tags$p(
                    "La curva indica, con los parámetros definiidos, cuál sería la ganancia neta para cada una de las gestiones definidas."
                  ),
                  
                  tags$h4(style="margin-top:14px; font-weight:700;", "3) Resultados proyectados"),
                  tags$p(
                    "La tabla resume lo esencial para la toma de decisiones con clientes gestionados, fugas reales atacadas, clientes salvados, inversión, retorno bruto, ",
                    "ganancia neta y ROI. Es la lectura rápida para validar si la estrategia es rentable y escalable con la capacidad."
                  ),
                  
                  tags$h4(style="margin-top:14px; font-weight:700;", "4) Mapa de calor de sensibilidad"),
                  tags$p(
                    "El mapa de calor muestra cómo cambia la ganancia neta cuando se varía el valor del incentivo y la efectividad del agente. ",
                    "Sirve para definir rangos realistas de política comercial y entender qué tan robusta es la estrategia ante escenarios conservadores."
                  )
                  
                  
                )
              )
            )
          ),
          
          
          tabPanel(
            "Impacto y escenarios",
            
            fluidRow(
              box(
                width = 12, status = "success", solidHeader = TRUE,
                title = "Filtros de caracterización del afiliado",
                uiOutput("filters_grid_impacto")
                
              )),
            
            fluidRow(
              
              box(
                width = 4, status = "warning", solidHeader = TRUE,
                title = "Parámetros de simulación",
                
                shinyWidgets::textInputIcon(
                  inputId = "LTV_CLIENTE",
                  label   = "Valor promedio del cliente",
                  value   = "720,000",
                  icon    = shiny::icon("dollar-sign")
                ),
                shinyWidgets::textInputIcon(
                  inputId = "COSTO_LLAMADA",
                  label   = "Costo llamada",
                  value   = "10,000",
                  icon    = shiny::icon("phone")
                ),
                shinyWidgets::textInputIcon(
                  inputId = "COSTO_INCENTIVO",
                  label   = "Costo incentivo",
                  value   = "180,000",
                  icon    = shiny::icon("gift")
                ),
                shinyWidgets::textInputIcon(
                  inputId = "PRESUPUESTO_N",
                  label   = "Presupuesto de gestiones",
                  value   = "10,000",
                  icon    = shiny::icon("clipboard-list")
                ),
                
                sliderInput("TASA_EXITO", "Tasa de éxito del agente",
                            min = 0, max = 1, value = 0.30, step = 0.01)
                
                #tags$hr(),
                #actionButton("btn_simular_impacto", "Simular", class = "btn-primary btn-white-text")
              ),
              
              
              
              box(
                width = 8, status = "primary", solidHeader = TRUE,
                title = "Resultados Proyectados",
                DTOutput("tbl_resultados_impacto")
              )
              
              
            ),
            
            fluidRow(
              box(
                width = 6, status = "primary", solidHeader = TRUE,
                title = "Ganancia neta por gestiones",
                plotlyOutput("plt_curva_rentabilidad", height = 420)
              ),
              box(
                width = 6, status = "primary", solidHeader = TRUE,
                title = "Escenarios de ganancia neta",
                plotlyOutput("plt_heatmap_incentivo_exito", height = 420)
              )
            )
          )
          
        )
      )
      
    )
  )
)




# =========================
# SERVER
# =========================


server <- function(input, output, session) {
  
  parse_monto <- function(x) {
    if (is.null(x) || !nzchar(x)) return(NA_real_)
    y <- gsub(",", "", x, fixed = TRUE)
    y <- gsub("[^0-9.]", "", y)        
    suppressWarnings(as.numeric(y))
  }
  
  
  var_labels <- c(
    SEGMENTO_EDAD       = "Segmento de edad",
    TIPO_AFILIADO       = "Tipo afiliado",
    Regional_Agrupadora = "Regional",
    Compania            = "Canal / Compañía",
    TIPO_IPS            = "Tipo IPS",
    CONDICION_SALUD     = "Condición de salud",
    NIVEL_INGRESO       = "Nivel de ingreso",
    PLAN                = "Plan",
    Sexo_Cd_BIN         = "Sexo",
    POLIZA_BIN          = "¿Tiene póliza?",
    RAMO_FAMILIAR       = "Ramo familiar"
  )
  
  
  artifacts <- reactiveVal(NULL)
  
  observe({
    cand <- c("rsf_coldstart_artifacts.rds", file.path("data","rsf_coldstart_artifacts.rds"))
    path <- cand[file.exists(cand)][1]
    if (is.na(path) || is.null(path)) {
      artifacts(NULL)
      showNotification(
        "No encuentro rsf_coldstart_artifacts.rds (raíz o /data). La pestaña RSF no podrá calcular.",
        type = "warning", duration = NULL
      )
    } else {
      art <- tryCatch(readRDS(path), error = function(e) {
        showNotification(paste("Error leyendo rsf_coldstart_artifacts.rds:", e$message),
                         type = "error", duration = NULL)
        NULL
      })
      artifacts(art)
    }
  })
  
  score_res <- eventReactive(input$btn_score, {
    req(artifacts())
    expected_cols <- artifacts()$expected_raw_cols
    new_raw <- build_new_raw(input, expected_cols)
    print(new_raw[, c("CONDICION_SALUD","NIVEL_INGRESO","PLAN"), drop = FALSE])
    str(new_raw[, c("CONDICION_SALUD","NIVEL_INGRESO","PLAN"), drop = FALSE])
    
    cat("\n--- new_raw (valores clave) ---\n")
    print(new_raw[, c("CONDICION_SALUD","NIVEL_INGRESO","PLAN"), drop = FALSE])
    str(new_raw[, c("CONDICION_SALUD","NIVEL_INGRESO","PLAN"), drop = FALSE])
    
    predict_rsf_profile(artifacts(), new_raw, horizons = c(1,3,6,12,18,24))
  })
  
  
  fmt_pct <- function(x) sprintf("%.1f%%", 100 * x)
  fmt_date_plus_m <- function(date0, m) as.Date(date0 + round(30.4375 * m))
  
  output$m_r1  <- renderText({ req(score_res()); fmt_pct(score_res()$risk[["risk_1m"]]) })
  output$m_r3  <- renderText({ req(score_res()); fmt_pct(score_res()$risk[["risk_3m"]]) })
  output$m_r6  <- renderText({ req(score_res()); fmt_pct(score_res()$risk[["risk_6m"]]) })
  output$m_r12 <- renderText({ req(score_res()); fmt_pct(score_res()$risk[["risk_12m"]]) })
  
  output$m_f1  <- renderText({ req(input$fecha_base); paste0("Fecha +1m: ",  fmt_date_plus_m(input$fecha_base, 1)) })
  output$m_f3  <- renderText({ req(input$fecha_base); paste0("Fecha +3m: ",  fmt_date_plus_m(input$fecha_base, 3)) })
  output$m_f6  <- renderText({ req(input$fecha_base); paste0("Fecha +6m: ",  fmt_date_plus_m(input$fecha_base, 6)) })
  output$m_f12 <- renderText({ req(input$fecha_base); paste0("Fecha +12m: ", fmt_date_plus_m(input$fecha_base, 12)) })
  
  output$plot_surv <- plotly::renderPlotly({
    req(score_res())
    dfc <- score_res()$curve
    req(nrow(dfc) > 0)
    
    dfc <- dfc %>%
      dplyr::mutate(
        risk_t = 1 - S_t
      )
    
    plotly::plot_ly(
      data = dfc,
      x = ~t,
      y = ~S_t,
      type = "scatter",
      mode = "lines",
      customdata = ~risk_t,
      hovertemplate = paste0(
        "<b>Mes:</b> %{x}<br>",
        "<b>P(Seguir activo):</b> %{y:.1%}<br>",
        "<b>P(Cancelar):</b> %{customdata:.1%}",
        "<extra></extra>"
      )
    ) %>%
      plotly::layout(
        title = list(text = "Curva de permanencia estimada", x = 0.5),
        xaxis = list(title = "Meses", dtick = 6),
        yaxis = list(title = "Probabilidad de seguir activo", tickformat = ".0%", range = c(0, 1)),
        margin = list(l = 60, r = 20, t = 50, b = 50),
        font = list(family = "Barlow, Arial, sans-serif", size = 13, color = "#2A2E3A")
      )
  })
  
  
  output$tbl_risk <- DT::renderDT({
    req(score_res())
    r <- score_res()$risk
    base <- input$fecha_base
    
    horizons <- c(1, 3, 6, 12, 18, 24)
    
    risk_keys <- paste0("risk_", horizons, "m")
    riesgos <- suppressWarnings(as.numeric(r[risk_keys]))
    if (length(riesgos) != length(horizons)) {
      riesgos <- rep(NA_real_, length(horizons))
    }
    
    tab <- data.frame(
      Meses = horizons,
      `Probabilidad de cancelar` = riesgos,
      `Fecha Objetivo` = sapply(horizons, function(h) fmt_date_plus_m(base, h)),
      check.names = FALSE
    ) %>%
      dplyr::mutate(
        `Probabilidad de cancelar` = dplyr::if_else(
          is.na(`Probabilidad de cancelar`),
          NA_character_,
          sprintf("%.4f", `Probabilidad de cancelar`)
        )
      )
    
    DT::datatable(
      tab,
      rownames = FALSE,
      options = list(pageLength = 6, dom = "tip")
    )
  })
  
  
  
  pac_raw <- reactiveVal(NULL)
  
  observe({
    df <- tryCatch(
      read_pac_local("Base_Final_Modelos_PAC.csv"),
      error = function(e){
        showNotification(paste("Error leyendo Base_Final_Modelos_PAC.csv:", e$message),
                         type = "error", duration = NULL)
        NULL
      }
    )
    if (!is.null(df)) {
      df <- last_spell_by_affiliate(df)
      df <- add_metrics(df)
    }
    pac_raw(df)
  })
  
  
  
  filter_vars <- reactive({
    req(pac_raw())
    df <- pac_raw()
    vars <- c(
      "ESTADO","TIPO_AFILIADO","Regional_Agrupadora","CONDICION_SALUD","Sexo_Cd","POLIZA",
      "NIVEL_INGRESO","GRUPO_CAUSA_CANCELACION","Compania","PLAN","TIPO_IPS","SEGMENTO_EDAD"
    )
    intersect(vars, names(df))
  })
  
  
  output$filters_grid <- renderUI({
    req(pac_raw())
    df <- pac_raw()
    vars <- filter_vars()
    
    vars_top <- vars[seq_len(min(6, length(vars)))]
    vars_bot <- if (length(vars) > 6) vars[7:min(12, length(vars))] else character(0)
    
    labels_filtros <- c(
      ESTADO = "Estado",
      TIPO_AFILIADO = "Tipo de afiliado",
      Regional_Agrupadora = "Regional",
      CONDICION_SALUD = "Condición de salud",
      Sexo_Cd = "Sexo",
      POLIZA = "Póliza",
      NIVEL_INGRESO = "Nivel de ingreso",
      GRUPO_CAUSA_CANCELACION = "Grupo causa cancelación",
      Compania = "Compañía",
      PLAN = "Plan",
      TIPO_IPS = "Tipo IPS",
      SEGMENTO_EDAD = "Segmento de edad"
    )
    
    make_select <- function(v){
      id <- paste0("f_", v)
      choices_raw <- sort(unique(na.omit(df[[v]])))
      choices <- c(ALL_OPT, choices_raw)
      
      lbl <- labels_filtros[[v]] %||% v
      
      selectizeInput(
        id, label = lbl,
        choices = choices,
        selected = ALL_OPT,
        multiple = FALSE,
        options = list(placeholder = "TODOS", allowEmptyOption = FALSE)
      )
    }
    
    row_top <- fluidRow(lapply(vars_top, function(v) column(2, make_select(v))))
    row_bot <- if (length(vars_bot) > 0) fluidRow(lapply(vars_bot, function(v) column(2, make_select(v)))) else NULL
    
    tagList(row_top, br(), row_bot)
  })
  
  
  permanencia_activos <- reactiveVal(NULL)
  
  observe({
    path_perm <- "Permanencia_Activos.parquet"
    
    if (!file.exists(path_perm)) {
      showNotification(
        paste0("No encuentro el archivo: ", path_perm),
        type = "error", duration = NULL
      )
      permanencia_activos(NULL)
      return()
    }
    
    perm <- tryCatch(
      arrow::read_parquet(path_perm) |> as.data.frame(),
      error = function(e) {
        showNotification(
          paste("Error leyendo Permanencia_Activos.parquet:", e$message),
          type = "error", duration = NULL
        )
        NULL
      }
    )
    
    if (is.null(perm)) {
      permanencia_activos(NULL)
      return()
    }
    
    
    if (!("AFILIADO_ID_EPS" %in% names(perm))) {
      showNotification("El parquet no trae AFILIADO_ID_EPS.", type = "error", duration = NULL)
      permanencia_activos(NULL)
      return()
    }
    
    perm <- perm %>%
      dplyr::mutate(AFILIADO_ID_EPS = as.character(AFILIADO_ID_EPS)) %>%
      dplyr::group_by(AFILIADO_ID_EPS) %>%
      dplyr::slice(1) %>%
      dplyr::ungroup()
    
    permanencia_activos(perm)
  })
  
  
  
  pac_activos <- reactive({
    req(pac_raw())
    df <- pac_raw()
    
    
    if ("grupo_churn" %in% names(df)) {
      df <- df %>% dplyr::filter(toupper(trimws(as.character(grupo_churn))) == "ACTIVOS")
    } else if ("ESTADO" %in% names(df)) {
      df <- df %>% dplyr::filter(toupper(trimws(as.character(ESTADO))) == "ACTIVOS")
    }
    
    
    id_shiny <- dplyr::case_when(
      "AFILIADO_ID_EPS" %in% names(df) ~ "AFILIADO_ID_EPS",
      "Afiliado_id_eps" %in% names(df) ~ "Afiliado_id_eps",
      TRUE ~ NA_character_
    )
    validate(need(!is.na(id_shiny),
                  "No encuentro la columna ID del afiliado (AFILIADO_ID_EPS o Afiliado_id_eps)."))
    
    df <- df %>%
      dplyr::mutate(AFILIADO_ID_EPS = as.character(.data[[id_shiny]]))
    
    
    perm <- permanencia_activos()
    req(perm)
    
    
    df <- df %>% dplyr::select(-dplyr::any_of(c("risk_12m", "grupo_operativo", "tiempo_gatillo_m")))
    
    df <- df %>%
      dplyr::left_join(
        perm %>% dplyr::select(AFILIADO_ID_EPS, risk_12m, grupo_operativo, tiempo_gatillo_m),
        by = "AFILIADO_ID_EPS"
      ) %>%
      dplyr::mutate(
        risk_12m = suppressWarnings(as.numeric(risk_12m)),
        
        grupo_operativo = toupper(trimws(as.character(grupo_operativo)))
      )
    
    df
  })
  
  
  
  
  
  output$filters_grid_fuga <- renderUI({
    req(pac_activos())
    df <- pac_activos()
    
    vars <- filter_vars()
    
    vars <- setdiff(vars, c("ESTADO", "Estado", "GRUPO_CAUSA_CANCELACION"))
    
    has_go_low <- "grupo_operativo" %in% names(df)
    has_go_up  <- "GRUPO_OPERATIVO" %in% names(df)
    
    if (has_go_low || has_go_up) {
      
      vars <- unique(c(vars, "grupo_operativo"))
      
      if (!has_go_low && has_go_up) {
        df$grupo_operativo <- df$GRUPO_OPERATIVO
      }
    }
    
    
    labels_filtros <- c(
      TIPO_AFILIADO = "Tipo de afiliado",
      Regional_Agrupadora = "Regional",
      CONDICION_SALUD = "Condición de salud",
      POLIZA = "Póliza",
      NIVEL_INGRESO = "Nivel de ingreso",
      Sexo_Cd = "Sexo",
      Compania = "Compañía",
      PLAN = "Plan",
      TIPO_IPS = "Tipo IPS",
      SEGMENTO_EDAD = "Segmento de edad",
      grupo_operativo = "Grupo operativo"
    )
    
    ALL_OPT <- "TODOS"
    
    make_select <- function(v){
      id  <- paste0("fa_", v)
      
      if (!v %in% names(df)) return(NULL)
      
      choices_raw <- sort(unique(na.omit(df[[v]])))
      choices <- c(ALL_OPT, choices_raw)
      
      lbl <- labels_filtros[[v]] %||% v
      
      selectizeInput(
        inputId = id,
        label   = lbl,
        choices = choices,
        selected = ALL_OPT,
        multiple = FALSE,
        options = list(placeholder = "TODOS", allowEmptyOption = FALSE)
      )
    }
    
    make_afiliado <- function(){
      textInput(
        inputId = "fa_afiliado_id_eps",
        label   = "Id Afiliado",
        value   = "",
        placeholder = "Ingresa el ID del afiliado"
      )
    }
    
    controls <- list()
    
    for (v in vars) {
      ctl <- make_select(v)
      if (!is.null(ctl)) {
        controls <- append(controls, list(column(2, ctl)))
        
        if (v == "grupo_operativo") {
          controls <- append(controls, list(column(2, make_afiliado())))
        }
      }
    }
    
    rows <- list()
    cur  <- list()
    k <- 0
    
    for (ctl in controls) {
      if (k == 6) {
        rows <- append(rows, list(fluidRow(cur)))
        cur <- list()
        k <- 0
      }
      cur <- append(cur, list(ctl))
      k <- k + 1
    }
    
    if (length(cur) > 0) rows <- append(rows, list(fluidRow(cur)))
    
    tagList(rows)
  })
  
  
  
  output$filters_grid_impacto <- renderUI({
    req(pac_activos())
    df <- pac_activos()
    
    vars <- filter_vars()
    vars <- setdiff(vars, c("ESTADO", "Estado", "GRUPO_CAUSA_CANCELACION"))
    
    if ("grupo_operativo" %in% names(df)) {
      vars <- unique(c(vars, "grupo_operativo"))
    }
    
    labels_filtros <- c(
      TIPO_AFILIADO = "Tipo de afiliado",
      Regional_Agrupadora = "Regional",
      CONDICION_SALUD = "Condición de salud",
      POLIZA = "Póliza",
      NIVEL_INGRESO = "Nivel de ingreso",
      Sexo_Cd = "Sexo",
      Compania = "Compañía",
      PLAN = "Plan",
      TIPO_IPS = "Tipo IPS",
      SEGMENTO_EDAD = "Segmento de edad",
      grupo_operativo = "Grupo operativo"
    )
    
    make_select <- function(v){
      if (!v %in% names(df)) return(NULL)
      
      id <- paste0("im_", v)
      choices_raw <- sort(unique(na.omit(df[[v]])))
      choices <- c(ALL_OPT, choices_raw)
      lbl <- labels_filtros[[v]] %||% v
      
      selectizeInput(
        inputId = id,
        label   = lbl,
        choices = choices,
        selected = ALL_OPT,
        multiple = FALSE,
        options = list(placeholder = "TODOS", allowEmptyOption = FALSE)
      )
    }
    
    controls <- list()
    for (v in vars) {
      ctl <- make_select(v)
      if (!is.null(ctl)) controls <- append(controls, list(column(2, ctl)))
    }
    
    
    rows <- list()
    cur <- list()
    k <- 0
    for (ctl in controls) {
      if (k == 6) {
        rows <- append(rows, list(fluidRow(cur)))
        cur <- list()
        k <- 0
      }
      cur <- append(cur, list(ctl))
      k <- k + 1
    }
    if (length(cur) > 0) rows <- append(rows, list(fluidRow(cur)))
    
    tagList(rows)
  })
  
  
  
  
  pac_fuga_flt <- reactive({
    req(pac_activos())
    df <- pac_activos()
    
    excluir <- c("ESTADO", "Estado", "grupo_causa_cancelacion")
    
    vars <- setdiff(filter_vars(), excluir)
    
    if ("grupo_operativo" %in% names(df)) {
      vars <- unique(c(vars, "grupo_operativo"))
    }
    
    
    for (v in vars) {
      id  <- paste0("fa_", v)
      sel <- input[[id]] %||% ALL_OPT
      
      
      if (is.null(sel) || identical(sel, ALL_OPT) || sel == ALL_OPT) next
      
      
      if (!v %in% names(df)) next
      
      
      if (is.character(df[[v]]) || is.factor(df[[v]])) {
        df[[v]] <- trimws(as.character(df[[v]]))
        
        if (v == "grupo_operativo") df[[v]] <- toupper(df[[v]])
        sel <- trimws(as.character(sel))
        if (v == "grupo_operativo") sel <- toupper(sel)
      }
      
      df <- df %>% dplyr::filter(.data[[v]] %in% sel)
    }
    
    df
  })
  
  
  pac_impacto_flt <- reactive({
    req(pac_activos())
    df <- pac_activos()
    
    vars <- filter_vars()
    vars <- setdiff(vars, c("ESTADO", "Estado", "GRUPO_CAUSA_CANCELACION"))
    if ("grupo_operativo" %in% names(df)) vars <- unique(c(vars, "grupo_operativo"))
    
    
    for (v in vars) {
      id  <- paste0("im_", v)
      sel <- input[[id]] %||% ALL_OPT
      if (is.null(sel) || identical(sel, ALL_OPT) || sel == ALL_OPT) next
      if (!v %in% names(df)) next
      
      
      if (is.character(df[[v]]) || is.factor(df[[v]])) {
        df[[v]] <- trimws(as.character(df[[v]]))
        sel <- trimws(as.character(sel))
        if (v == "grupo_operativo") {
          df[[v]] <- toupper(df[[v]])
          sel <- toupper(sel)
        }
      }
      
      df <- df %>% dplyr::filter(.data[[v]] %in% sel)
    }
    
    df
  })
  
  
  pac_fuga_general <- reactive({
    req(pac_activos())
    df <- pac_activos()
    
    vars <- filter_vars()
    if ("grupo_operativo" %in% names(df)) {
      vars <- unique(c(vars, "grupo_operativo"))
    }
    
    for (v in vars) {
      sel <- input[[paste0("fa_", v)]] %||% ALL_OPT
      if (!identical(sel, ALL_OPT)) {
        df <- df %>% dplyr::filter(.data[[v]] %in% sel)
      }
    }
    
    df
  })
  
  
  
  pac_km_base <- reactive({
    req(pac_raw())
    df <- pac_raw()
    
    for (v in filter_vars()) {
      sel <- input[[paste0("fa_", v)]] %||% ALL_OPT
      if (!identical(sel, ALL_OPT)) df <- df %>% dplyr::filter(.data[[v]] %in% sel)
    }
    
    df
  })
  
  
  labels_filtros <- c(
    ESTADO = "Estado",
    TIPO_AFILIADO = "Tipo de afiliado",
    Regional_Agrupadora = "Regional",
    CONDICION_SALUD = "Condición de salud",
    Sexo_Cd = "Sexo",
    POLIZA = "Póliza",
    NIVEL_INGRESO = "Nivel de ingreso",
    GRUPO_CAUSA_CANCELACION = "Grupo causa cancelación",
    Compania = "Compañía",
    PLAN = "Plan",
    TIPO_IPS = "Tipo IPS",
    SEGMENTO_EDAD = "Segmento de edad"
  )
  
  output$ui_imp_var <- renderUI({
    req(filter_vars())
    vars <- filter_vars()
    
    choices <- stats::setNames(as.list(vars), labels_filtros[vars] %||% vars)
    
    selectInput(
      "imp_var",
      "Selecciona la variable para comparar",
      choices = choices,
      selected = if ("NIVEL_INGRESO" %in% vars) "NIVEL_INGRESO" else vars[[1]]
    )
  })
  
  
  
  rsf_mean_curve <- function(df, artifacts) {
    expected_cols <- artifacts$expected_raw_cols
    validate(need(!is.null(expected_cols) && length(expected_cols) > 0,
                  "El artefacto no trae expected_raw_cols."))
    
    new_raw <- build_raw_from_df(df, expected_cols)
    X <- bake(artifacts$recipe, new_data = new_raw)
    pr <- predict(artifacts$model, data = X)
    
    times <- artifacts$model$unique.death.times
    if (is.null(times)) times <- pr$unique.death.times
    times <- as.numeric(times)
    
    S_mat <- pr$survival
    S_mat <- if (is.matrix(S_mat)) S_mat else as.matrix(S_mat)
    
    S_mean <- colMeans(S_mat, na.rm = TRUE)
    
    data.frame(
      t = times,
      S_t = pmin(pmax(S_mean, 0), 1)
    )
  }
  
  output$plt_surv_by_var <- renderPlotly({
    req(pac_km_base())
    df_base <- pac_km_base()
    req(nrow(df_base) > 0)
    
    v <- input$imp_var
    validate(need(!is.null(v) && v %in% names(df_base),
                  "Variable seleccionada no disponible en la base filtrada."))
    
    
    validate(need("FECHA_INICIO" %in% names(df_base), "Falta FECHA_INICIO para Kaplan–Meier."))
    validate(need("FECHA_FIN"    %in% names(df_base), "Falta FECHA_FIN para Kaplan–Meier."))
    validate(need("FALLA"        %in% names(df_base), "Falta FALLA para definir evento/censura."))
    
    
    df_base <- df_base %>%
      dplyr::mutate(
        .grp = as.character(.data[[v]]),
        .grp = dplyr::if_else(is.na(.grp) | !nzchar(trimws(.grp)), "(Sin dato)", .grp)
      )
    
    
    max_lvls <- 12
    top_lvls <- df_base %>%
      dplyr::count(.grp, name = "n") %>%
      dplyr::arrange(dplyr::desc(n)) %>%
      dplyr::slice_head(n = max_lvls) %>%
      dplyr::pull(.grp)
    
    df_base <- df_base %>%
      dplyr::mutate(grupo = dplyr::if_else(.grp %in% top_lvls, .grp, "OTROS"))
    
    
    status_col <- dplyr::case_when(
      "grupo_churn" %in% names(df_base) ~ "grupo_churn",
      "ESTADO"      %in% names(df_base) ~ "ESTADO",
      TRUE ~ NA_character_
    )
    
    validate(need(!is.na(status_col),
                  "No encuentro la columna de estado (esperaba 'grupo_churn' o 'ESTADO')."))
    
    df_km <- df_base %>%
      dplyr::mutate(
        FECHA_INICIO = as.Date(FECHA_INICIO),
        FECHA_FIN    = as.Date(FECHA_FIN),
        .status      = toupper(trimws(as.character(.data[[status_col]])))
      ) %>%
      dplyr::filter(!is.na(FECHA_INICIO), !is.na(FECHA_FIN), FECHA_FIN >= FECHA_INICIO) %>%
      dplyr::mutate(
        
        t_m = lubridate::time_length(lubridate::interval(FECHA_INICIO, FECHA_FIN), "month"),
        t_m = pmax(0, as.numeric(t_m)),
        
        
        event = dplyr::case_when(
          .status == "CANCELADOS" ~ 1L,
          .status == "ACTIVOS"    ~ 0L,
          TRUE                   ~ NA_integer_
        )
      ) %>%
      dplyr::filter(is.finite(t_m), !is.na(event))
    
    
    req(nrow(df_km) > 0)
    validate(need(sum(df_km$event, na.rm = TRUE) > 0,
                  "Con los filtros actuales no hay CANCELADOS (eventos). Kaplan–Meier no mostrará diferencias."))
    
    fit <- survival::survfit(survival::Surv(t_m, event) ~ grupo, data = df_km)
    s <- summary(fit)
    
    
    if (!is.null(fit$strata)) {
      counts <- as.integer(fit$strata)
      strata_names <- names(fit$strata)
      
      ends <- cumsum(counts)
      starts <- c(1L, head(ends, -1L) + 1L)
      
      df_curve <- dplyr::bind_rows(lapply(seq_along(counts), function(i) {
        if (counts[i] <= 0) return(NULL)
        idx <- starts[i]:ends[i]
        data.frame(
          t = fit$time[idx],
          S_t = fit$surv[idx],
          grupo = sub("^grupo=", "", strata_names[i]),
          stringsAsFactors = FALSE
        )
      }))
    } else {
      
      df_curve <- data.frame(
        t = fit$time,
        S_t = fit$surv,
        grupo = as.character(unique(df_km$grupo)[1]),
        stringsAsFactors = FALSE
      )
    }
    
    df_curve <- df_curve %>%
      dplyr::mutate(
        S_t = pmin(pmax(S_t, 0), 1),
        risk_t = 1 - S_t
      )
    
    ng <- df_km %>% dplyr::count(grupo, name = "n")
    df_curve <- df_curve %>% dplyr::left_join(ng, by = "grupo")
    
    v_lbl <- labels_filtros[[v]] %||% v
    
    plot_ly(
      data = df_curve,
      x = ~t, y = ~S_t,
      color = ~grupo,
      type = "scatter", mode = "lines",
      line = list(shape = "hv"),
      text = ~paste0(grupo, " (n=", n, ")"),
      customdata = ~risk_t,
      hovertemplate = paste0(
        "<b>%{text}</b><br>",
        "<b>Mes:</b> %{x:.1f}<br>",
        "<b>P(permanece):</b> %{y:.1%}<br>",
        "<b>P(cancela):</b> %{customdata:.1%}",
        "<extra></extra>"
      )
    ) %>%
      layout(
        title = list(text = paste0("<b>Probabilidad de Permanencia por ", v_lbl, "</b>"), x = 0.02),
        font = list(family = "Barlow, Arial, sans-serif", size = 13, color = "#2A2E3A"),
        margin = list(l = 55, r = 10, t = 50, b = 55),
        xaxis = list(title = "Meses"),
        yaxis = list(title = "Probabilidad de permanecer", tickformat = ".0%", range = c(0, 1)),
        legend = list(orientation = "h", x = 0, y = -0.25)
      )
  })
  
  
  get_curve_cols_120m <- function(perm, months = 1:120) {
    s_cols <- paste0("S_", months, "m")
    r_cols <- paste0("risk_", months, "m")
    
    if (all(s_cols %in% names(perm))) return(list(kind = "S", cols = s_cols))
    if (all(r_cols %in% names(perm))) return(list(kind = "risk", cols = r_cols))
    
    list(kind = "none", cols = character(0))
  }
  
  build_curve_df <- function(values, kind, label, months = 1:120) {
    values <- suppressWarnings(as.numeric(values))
    S_t <- if (kind == "S") values else (1 - values)
    S_t <- pmin(pmax(S_t, 0), 1)
    
    data.frame(
      t = months,
      S_t = S_t,
      risk_t = 1 - S_t,
      serie = label,
      stringsAsFactors = FALSE
    )
  }
  
  
  output$plt_surv_fuga <- renderPlotly({
    perm <- permanencia_activos()
    req(perm)
    
    id_sel <- trimws(as.character(input$fa_afiliado_id_eps %||% ""))
    
    if (!nzchar(id_sel)) id_sel <- "64513"
    
    perm_one <- perm %>% dplyr::filter(as.character(AFILIADO_ID_EPS) == id_sel)
    
    if (nrow(perm_one) == 0) {
      return(
        plotly::plotly_empty(type = "scatter") %>%
          plotly::layout(
            title = list(text = paste0("<b>No encontré el afiliado ", id_sel, " en el parquet</b>"), x = 0.5),
            xaxis = list(visible = FALSE),
            yaxis = list(visible = FALSE),
            font  = list(family = "Barlow, Arial, sans-serif", size = 13, color = "#2A2E3A")
          )
      )
    }
    
    cc <- get_curve_cols_120m(perm_one, months = 1:120)
    validate(need(
      cc$kind != "none",
      "El parquet no trae columnas S_1m..S_120m ni risk_1m..risk_120m."
    ))
    
    df_curve <- build_curve_df(
      values = perm_one[1, cc$cols, drop = TRUE],
      kind   = cc$kind,
      label  = paste0("Afiliado ", id_sel),
      months = 1:120
    )
    
    plotly::plot_ly(
      data = df_curve,
      x = ~t, y = ~S_t,
      type = "scatter", mode = "lines",
      text = ~serie,
      customdata = ~risk_t,
      hovertemplate = paste0(
        "<b>%{text}</b><br>",
        "<b>Mes:</b> %{x}<br>",
        "<b>P(permanece):</b> %{y:.1%}<br>",
        "<b>P(cancela):</b> %{customdata:.1%}",
        "<extra></extra>"
      )
    ) %>%
      plotly::layout(
        font = list(family = "Barlow, Arial, sans-serif", size = 13, color = "#2A2E3A"),
        margin = list(l = 55, r = 10, t = 10, b = 45),
        xaxis = list(title = "Meses", dtick = 6),
        yaxis = list(title = "Probabilidad de seguir activo", tickformat = ".0%", range = c(0, 1)),
        showlegend = FALSE
      )
  })
  
  
  build_curve_df <- function(values, kind, label, months = 1:120) {
    values <- suppressWarnings(as.numeric(values))
    S_t <- if (kind == "S") values else (1 - values)
    S_t <- pmin(pmax(S_t, 0), 1)
    data.frame(
      t = months,
      S_t = S_t,
      risk_t = 1 - S_t,
      serie = label,
      stringsAsFactors = FALSE
    )
  }
  
  
  output$tbl_fuga_activos <- DT::renderDT({
    req(pac_fuga_flt())
    df <- pac_fuga_flt()
    req(nrow(df) > 0)
    
    
    id_in <- trimws(input$fa_afiliado_id_eps %||% "")
    if (nzchar(id_in) && ("AFILIADO_ID_EPS" %in% names(df))) {
      df <- df[as.character(df$AFILIADO_ID_EPS) == id_in, , drop = FALSE]
    }
    req(nrow(df) > 0)
    
    page_len <- suppressWarnings(as.integer(input$fuga_page_len))
    if (is.na(page_len)) page_len <- 5
    
    
    if (!("AFILIADO_ID_EPS" %in% names(df))) {
      return(DT::datatable(
        data.frame(Mensaje = "No existe la columna AFILIADO_ID_EPS en la base."),
        options = list(dom = "t")
      ))
    }
    if (!("FECHA_INICIO" %in% names(df))) df$FECHA_INICIO <- NA
    if (!("risk_12m" %in% names(df))) df$risk_12m <- NA_real_
    
    
    cols_vars <- intersect(filter_vars(), names(df))
    
    
    cols_excluir <- c("ESTADO", "GRUPO_CAUSA_CANCELACION", "tiempo_gatillo_m")
    cols_vars <- setdiff(cols_vars, cols_excluir)
    
    labels_tbl <- c(
      TIPO_AFILIADO = "Tipo de afiliado",
      Regional_Agrupadora = "Regional",
      CONDICION_SALUD = "Condición de salud",
      Sexo_Cd = "Sexo",
      POLIZA = "Póliza",
      NIVEL_INGRESO = "Nivel de ingreso",
      Compania = "Compañía",
      PLAN = "Plan",
      TIPO_IPS = "Tipo IPS",
      SEGMENTO_EDAD = "Segmento de edad",
      grupo_operativo = "Grupo operativo"
    )
    
    tab <- df %>%
      dplyr::mutate(
        risk_12m_num = suppressWarnings(as.numeric(risk_12m))
      ) %>%
      dplyr::arrange(dplyr::desc(risk_12m_num)) %>%
      dplyr::mutate(
        `Probabilidad de cancelar` = dplyr::if_else(
          is.na(risk_12m_num),
          NA_character_,
          sprintf("%.2f%%", 100 * risk_12m_num)
        )
      ) %>%
      dplyr::rename(
        `Id Afiliado` = AFILIADO_ID_EPS,
        `Fecha inicio` = FECHA_INICIO
      ) %>%
      dplyr::select(
        `Id Afiliado`,
        `Probabilidad de cancelar`,
        `Fecha inicio`,
        dplyr::any_of(cols_vars)
      ) %>%
      dplyr::rename_with(
        .fn = function(nm) ifelse(nm %in% names(labels_tbl), unname(labels_tbl[nm]), nm),
        .cols = dplyr::any_of(names(labels_tbl))
      )
    
    DT::datatable(
      tab,
      rownames = FALSE,
      elementId = "tbl_fuga_activos_dt",
      class = "compact stripe",
      options = list(
        pageLength = page_len,
        scrollX = TRUE,
        dom = "tip"
      )
    )
  })
  
  
  
  output$plt_risk_box <- renderPlotly({
    df <- pac_fuga_flt()
    req(nrow(df) > 0)
    
    v <- suppressWarnings(as.numeric(df$risk_12m))
    v <- v[is.finite(v)]
    req(length(v) > 0)
    
    plot_ly(
      y = v,
      type = "box",
      name = "Riesgo general de fuga",
      boxpoints = "outliers",
      boxmean = TRUE,
      hovertemplate = "<b>risk_12m:</b> %{y:.2%}<extra></extra>"
    ) %>%
      layout(
        font = list(family = "Barlow, Arial, sans-serif", size = 13, color = "#2A2E3A"),
        margin = list(l = 50, r = 10, t = 20, b = 40),
        yaxis = list(title = "Probabilidad", tickformat = ".0%", rangemode = "tozero"),
        xaxis = list(title = "")
      )
  })
  
  
  
  pac_flt <- reactive({
    req(pac_raw())
    df <- pac_raw()
    for (v in filter_vars()) {
      sel <- input[[paste0("f_", v)]] %||% ALL_OPT
      if (!identical(sel, ALL_OPT)) df <- df %>% filter(.data[[v]] %in% sel)
    }
    df
  })
  
  bar_metric <- reactive(input$bar_metric %||% "count")
  
  
  output$plt_tipo     <- renderPlotly({ plot_bar_metric(pac_flt(), "TIPO_AFILIADO",           metric = bar_metric(), title = "TIPO AFILIADO") })
  output$plt_regional <- renderPlotly({ plot_bar_metric(pac_flt(), "Regional_Agrupadora",     metric = bar_metric(), title = "REGIONAL") })
  output$plt_salud    <- renderPlotly({ plot_bar_metric(pac_flt(), "CONDICION_SALUD",         metric = bar_metric(), title = "CONDICIÓN DE SALUD") })
  output$plt_plan     <- renderPlotly({ plot_bar_metric(pac_flt(), "PLAN",                    metric = bar_metric(), title = "PLAN") })
  output$plt_ingreso  <- renderPlotly({ plot_bar_metric(pac_flt(), "NIVEL_INGRESO",           metric = bar_metric(), title = "NIVEL DE INGRESO") })
  output$plt_ips      <- renderPlotly({ plot_bar_metric(pac_flt(), "TIPO_IPS",                metric = bar_metric(), title = "TIPO IPS") })
  output$plt_seg_edad <- renderPlotly({ plot_bar_metric(pac_flt(), "SEGMENTO_EDAD",           metric = bar_metric(), title = "SEGMENTO EDAD") })
  output$plt_poliza   <- renderPlotly({ plot_bar_metric(pac_flt(), "POLIZA",                  metric = bar_metric(), title = "PÓLIZA") })
  output$plt_causa    <- renderPlotly({ plot_bar_metric(pac_flt(), "GRUPO_CAUSA_CANCELACION", metric = bar_metric(), title = "GRUPO CAUSA CANCELACIÓN") })
  output$plt_compania <- renderPlotly({ plot_bar_metric(pac_flt(), "Compania",                metric = bar_metric(), title = "COMPAÑÍA") })
  
  
  output$plt_consumos_cat <- renderPlotly({
    plot_bar_metric(
      pac_flt(), "consumos_cat",
      metric = bar_metric(),
      title  = "CONSUMOS (TOTAL BASE) | 0 / 1 / 2 a 5 / 6+"
    )
  })
  
  output$plt_pqrs_cat <- renderPlotly({
    plot_bar_metric(
      pac_flt(), "pqrs_cat",
      metric = bar_metric(),
      title  = "PQRS (TOTAL BASE) | 0 / 1 / 2 a 5 / 6+"
    )
  })
  
  
  output$plt_piramide <- renderPlotly({
    plot_piramide(pac_flt(), metric = bar_metric())
  })
  
  
  
  
  perfil_cancelados <- list(
    "3" = list(
      nombre = "Familias de interacción media",
      icon  = "users",
      bullets = c(
        "Es el segmento más grande y corresponde a familias con un nivel de interacción medio y experiencia fluida con baja fricción.",
        "Tienen una dinámica más digital y una relación práctica con el producto.",
        "No saturan canales ni se caracterizan por quejas; el comportamiento es más silencioso, por eso el riesgo se activa por señales tempranas y sutiles.",
        "Pueden cancelar cuando perciben que el valor no compensa el costo, ante ofertas comparables o cuando se acumulan pequeñas fricciones en trámites, claridad de cobertura y tiempos.",
        "Es el mejor objetivo para estrategias escalables de automatización, mensajes personalizados, recordatorios oportunos y alertas tempranas para intervenir antes de la decisión de salida."
      )
    ),
    "2" = list(
      nombre = "Colectivos Poco Vinculados",
      icon  = "building",
      bullets = c(
        "Afiliados colectivos, usualmente más jóvenes y sanos, con consumo bajo y poca fricción.",
        "Mantienen una relación distante con el plan debido a que lo tienen, pero no lo perciben como propio ni indispensable.",
        "La permanencia se define por conveniencia y encaje como cambios de empleo, beneficios corporativos y comparaciones de cobertura, más que por una mala experiencia.",
        "Son sensibles a mensajes simples de valor ya que si no entienden rápidamente qué ganan y cuándo usarlo, el plan se vuelve prescindible.",
        "La clave es hacer el beneficio visible y cotidiano con propuesta de valor clara, casos de uso concretos y comunicación breve que traduzca el PAC en ventajas reales para ellos y su familia."
      )
    ),
    "0" = list(
      nombre = "Mayor Demandanda",
      icon  = "user-clock",
      bullets = c(
        "Afiliados con alta interacción y uso del PAC por encima del promedio; lo utilizan de forma recurrente.",
        "Suelen reflejar mayor complejidad en salud y una relación más clínica con el sistema, con necesidades más frecuentes de atención y seguimiento.",
        "No se caracterizan por ser conflictivos; la fricción existe, pero suele ser manejable y más asociada a coordinación, tiempos y continuidad.",
        "Es un perfil estratégico porque si se van, se pierde un afiliado que sí estaba capturando valor del producto y tenía mayor probabilidad de permanencia.",
        "La prioridad es asegurar continuidad y acompañamiento con una gestión proactiva de casos, seguimiento, facilidad de agenda y navegación del servicio para evitar quiebres en la experiencia."
      )
    ),
    "1" = list(
      nombre = "Desconectados del valor",
      icon  = "heartbeat",
      bullets = c(
        "Afiliados con uso muy bajo del PAC; pasan por el sistema sin generar fricción ni interacción relevante.",
        "No incorporan el plan a su día a día y no perciben beneficios claros, por lo que el PAC se vuelve fácil de soltar.",
        "Se van en silencio ya que casi no dejan señales de inconformidad, quejas o eventos previos que anticipen la salida.",
        "La oportunidad está en activaciones simples y oportunas con una bienvenida efectiva, recordación de beneficios y empuje a un primer uso de alto valor percibido.",
        "Enfocar en lo básico que mueve decisión con mensajes cortos, casos de uso concretos y una acción guiada para probar el plan sin esfuerzo."
      )
    ),
    
    "999" = list(
      nombre = "Sin Clasificación",
      icon  = "question-circle",
      bullets = c(
        "Afiliados que no encajan claramente en ningún patrón de uso o fricción debido a que suelen mezclar comportamientos inusuales o combinaciones poco comunes de variables."
        
      )
    )
  )
  
  perfil_activos <- list(
    "3" = list(
      nombre = "Consumo medio y baja fricción",
      icon  = "money-bill-wave",
      bullets = c(
        "Segmento más grande de afiliados activos, con comportamiento estable y consistente en el tiempo.",
        "Presentan consumo medio y una experiencia generalmente fluida; conviven bien con la red propia y aliada, con fricción menor a la esperada.",
        "No requieren intervención intensiva; el mayor valor está en sostener la estabilidad y evitar deterioros graduales de experiencia o uso.",
        "Es el perfil ideal para operación eficiente de automatización, microsegmentación ligera y monitoreo continuo con alertas tempranas.",
        "El foco estratégico es detectar desvíos como caídas de uso, cambios en patrones, señales incipientes de fricción y actuar solo cuando se active riesgo."
      )
    ),
    "0" = list(
      nombre = "Familias de bajo contacto",
      icon  = "hand-holding-dollar",
      bullets = c(
        "Afiliados activos con uso bajo del PAC y casi sin fricción; su interacción es mínima.",
        "Se mantienen con una relación débil con el plan ya que están presentes, pero con poco involucramiento y baja recordación de valor.",
        "Se observa más afiliación familiar y una mayor tendencia a atenderse en red de convenio, lo que sugiere decisiones prácticas y orientadas a facilidad de acceso.",
        "Segmento adecuado para retención de bajo costo con recordatorios simples, comunicación regionalizada y activaciones livianas que aumenten uso y percepción de beneficio sin cargar operación."
      )
    ),
    "1" = list(
      nombre = "Colectivos jóvenes",
      icon  = "triangle-exclamation",
      bullets = c(
        "Afiliados de colectivos concentrados en perfiles jóvenes, con alta antigüedad y una condición de salud media y alta.",
        "Uso muy elevado de servicios de PAC y PBS; se observan picos de quejas, especialmente asociadas al PBS.",
        "Mayor concentración en región Oriente y en IPS exclusivas, lo que puede amplificar fricciones por capacidad, accesibilidad y coordinación de atención.",
        "La prioridad estratégica se concentra en una gestión proactiva de continuidad y coordinación, y control de causas no clínicas con procesos simples para reducir pérdidas evitables."
      )
    ),
    "2" = list(
      nombre = "Crónicos de Alto Valor Perdido",
      icon  = "hospital-user",
      bullets = c(
        "Afiliados mayoritariamente jóvenes, con comportamiento tranquilo de poco uso del PAC y fricción muy baja.",
        "Su permanencia suele estar más anclada al colectivo que a una decisión personal; no necesariamente sienten el plan como propio.",
        "El riesgo es perderlos sin señales visibles si cambia su contexto laboral o si el beneficio deja de parecer relevante.",
        "Responden mejor a fidelización liviana y preventiva de beneficios digitales, bienestar, prevención y contenidos accionables para su rutina.",
        "El objetivo estratégico está en crear hábito y aumentar el valor percibido con intervenciones de bajo costo operativo, sin elevar demanda de servicio."
      )
    ),
    "999" = list(
      nombre = "Sin Clasificación",
      icon  = "question-circle",
      bullets = c(
        "Afiliados que no encajan claramente en ningún patrón de uso o fricción debido a que suelen mezclar comportamientos inusuales o combinaciones poco comunes de variables."
        
      )
    )
  )
  
  
  norm_grupo <- function(x){
    x0 <- trimws(toupper(as.character(x)))
    dplyr::case_when(
      x0 %in% c("ACTIVO", "ACTIVOS") ~ "ACTIVO",
      x0 %in% c("CANCELADO", "CANCELADOS") ~ "CANCELADO",
      TRUE ~ NA_character_
    )
  }
  
  
  activos_summary <- reactive({
    req(pac_raw())
    df <- pac_raw()
    
    validate(need("cluster" %in% names(df), "No existe la columna 'cluster' en la base."))
    validate(need("grupo_churn" %in% names(df), "No existe la columna 'grupo_churn' en la base."))
    
    df %>%
      mutate(
        cluster = clean_cluster(cluster),
        grupo_norm = norm_grupo(grupo_churn)
      ) %>%
      filter(grupo_norm == "ACTIVO", !is.na(cluster)) %>%
      count(cluster, name = "n") %>%
      mutate(
        p = n / sum(n),
        cluster_chr = as.character(cluster),
        nombre = vapply(cluster_chr, function(k){
          info <- perfil_activos[[k]]
          if (!is.null(info) && !is.null(info$nombre)) info$nombre else paste("Cluster", k)
        }, character(1))
      ) %>%
      select(-cluster_chr) %>%
      arrange(desc(n))
  })
  
  
  cluster_summary <- reactive({
    req(pac_raw())
    df <- pac_raw()
    
    validate(need("cluster" %in% names(df), "No encuentro la columna 'cluster' en Base_Final_Modelos_PAC.csv"))
    validate(need("grupo_churn" %in% names(df), "No encuentro la columna 'grupo_churn' en Base_Final_Modelos_PAC.csv"))
    
    tmp <- df %>%
      mutate(
        cluster = clean_cluster(cluster),
        grupo_norm = norm_grupo(grupo_churn)
      ) %>%
      filter(!is.na(cluster), !is.na(grupo_norm)) %>%
      count(grupo_norm, cluster, name = "Cantidad Afiliados") %>%
      group_by(grupo_norm) %>%
      mutate(
        Participación = `Cantidad Afiliados` / sum(`Cantidad Afiliados`)
      ) %>%
      ungroup() %>%
      arrange(grupo_norm, desc(`Cantidad Afiliados`))
    
    tmp
  })
  
  
  output$tbl_clusters_activos <- renderDT({
    req(cluster_summary())
    dd <- cluster_summary() %>% filter(grupo_norm == "ACTIVO")
    
    
    dd$`Nombre Cluster` <- sapply(as.character(dd$cluster), function(k) {
      if (!is.null(perfil_activos[[k]]$nombre)) perfil_activos[[k]]$nombre else paste("Cluster", k)
    })
    
    out <- dd %>%
      transmute(
        `Id Cluster` = cluster,
        `Nombre Cluster`,
        `Cantidad Afiliados`,
        `Participación` = scales::percent(Participación, accuracy = 1)
      )
    
    DT::datatable(out, rownames = FALSE, options = list(pageLength = 10, dom = "tip"))
  })
  
  output$tbl_clusters_cancelados <- renderDT({
    req(cluster_summary())
    dd <- cluster_summary() %>% filter(grupo_norm == "CANCELADO")
    
    dd$`Nombre Cluster` <- sapply(as.character(dd$cluster), function(k) {
      if (!is.null(perfil_cancelados[[k]]$nombre)) perfil_cancelados[[k]]$nombre else paste("Cluster", k)
    })
    
    out <- dd %>%
      transmute(
        `Id Cluster` = cluster,
        `Nombre Cluster`,
        `Cantidad Afiliados`,
        `Participación` = scales::percent(Participación, accuracy = 1)
      )
    
    DT::datatable(out, rownames = FALSE, options = list(pageLength = 10, dom = "tip"))
  })
  
  
  render_cards <- function(keys, meta){
    tagList(
      lapply(keys, function(k){
        info <- meta[[as.character(k)]]
        if (is.null(info)) {
          info <- list(nombre = paste("Cluster", k), icon = "circle-info", bullets = c("Sin descripción configurada."))
        }
        
        box(
          width = 12, status = "success", solidHeader = TRUE,
          title = tagList(icon(info$icon), tags$span(tags$b(paste0("Cluster ", k, ": ")), info$nombre)),
          tags$ul(lapply(info$bullets, tags$li))
        )
      })
    )
  }
  
  render_cards_icons <- function(keys, meta, suffix = "A"){
    
    tagList(lapply(keys, function(k){
      
      k_chr <- as.character(k)
      info <- meta[[k_chr]]
      if (is.null(info)) {
        info <- list(nombre = paste("Cluster", k_chr), icon = "circle-info", bullets = c("Sin descripción configurada."))
      }
      
      img_src <- paste0("C", k_chr, suffix, ".png")
      has_img <- file.exists(file.path("www", img_src))
      
      box(
        width = 12, status = "success", solidHeader = TRUE,
        title = tagList(icon(info$icon), tags$span(tags$b(paste0("Cluster ", k_chr, ": ")), info$nombre)),
        
        fluidRow(
          column(
            width = 9,
            tags$ul(lapply(info$bullets, tags$li))
          ),
          column(
            width = 3,
            if (has_img) {
              tags$div(
                style = "display:flex; justify-content:center; align-items:center; height:100%; padding-top:8px;",
                tags$img(
                  src = img_src,
                  style = "width:100%; max-width:180px; border-radius:14px; box-shadow:0 6px 18px rgba(0,0,0,0.10); background:#fff;"
                )
              )
            } else NULL
          )
        )
      )
    }))
  }
  
  
  output$ui_perfiles_activos <- renderUI({
    dd <- activos_summary()
    req(nrow(dd) > 0)
    render_cards_icons(dd$cluster, perfil_activos, suffix = "A")
  })
  
  
  
  output$ui_perfiles_cancelados <- renderUI({
    req(cluster_summary())
    dd <- cluster_summary() %>% filter(grupo_norm == "CANCELADO") %>% arrange(desc(`Cantidad Afiliados`))
    keys <- unique(dd$cluster)
    render_cards(keys, perfil_cancelados)
  })
  
  output$pie_activos <- renderPlotly({
    dd <- activos_summary()
    
    
    fnt <- list(family = "Barlow, Arial, sans-serif", size = 13, color = "#2A2E3A")
    
    if (is.null(dd) || nrow(dd) == 0) {
      return(
        plotly::plotly_empty() %>%
          plotly::layout(
            title = list(text = "<b>No hay datos de ACTIVO para graficar</b>", x = 0.5),
            font  = fnt
          )
      )
    }
    
    p <- plotly::plot_ly(
      dd,
      type   = "pie",
      labels = ~nombre,
      values = ~n,
      key    = ~as.character(cluster), 
      textinfo  = "percent",
      hoverinfo = "text",
      text = ~paste0(
        "<b>", nombre, "</b><br>",
        "Afiliados: ", scales::comma(n), "<br>",
        "Participación: ", scales::percent(p, accuracy = 1),
        "<br><i>Click para ver detalle</i>"
      ),
      sort   = FALSE,
      source = "pieA"
      
    ) %>%
      plotly::event_register("plotly_click") %>%
      plotly::layout(
        font = fnt,
        showlegend = TRUE,
        legend = list(font = fnt)
      )
    
    p
  })
  
  
  
  output$icons_activos <- renderUI({
    dd <- activos_summary()
    req(nrow(dd) > 0)
    
    tags$div(
      class = "icons-row",
      lapply(dd$cluster, function(cid){
        cid <- as.character(cid)
        src <- paste0("C", cid, "A.png")
        nombre <- if (!is.null(perfil_activos[[cid]]$nombre)) perfil_activos[[cid]]$nombre else paste("Cluster", cid)
        
        if (!file.exists(file.path("www", src))) return(NULL)
        
        tags$div(
          class = "icon-wrap",
          tags$img(
            src = src,
            class = "cluster-icon",
            title = nombre,
            onclick = sprintf(
              "Shiny.setInputValue('cluster_activo_click', '%s', {priority: 'event'});",
              cid
            )
          ),
          tags$div(class = "icon-label", paste0("C", cid))
        )
      })
    )
  })
  
  
  show_cluster_modal_activos <- function(cid){
    cid <- as.character(cid)
    info <- perfil_activos[[cid]]
    validate(need(!is.null(info), paste0("No hay descripción configurada para Cluster ", cid)))
    
    src <- paste0("C", cid, "A.png")
    
    showModal(modalDialog(
      title = HTML(paste0(info$nombre, "</b>")),
      size = "l",
      easyClose = TRUE,
      footer = modalButton("Cerrar"),
      tags$div(
        style="display:flex; gap:18px; align-items:flex-start;",
        tags$img(src = src, style="width:180px;height:180px;border-radius:16px;box-shadow:0 6px 18px rgba(0,0,0,0.10);background:#fff;"),
        tags$div(tags$ul(lapply(info$bullets, tags$li)))
      )
    ))
  }
  
  
  observeEvent(input$cluster_activo_click, {
    req(input$cluster_activo_click)
    show_cluster_modal_activos(input$cluster_activo_click)
  })
  
  
  observeEvent(plotly::event_data("plotly_click", source = "pieA"), {
    ev <- plotly::event_data("plotly_click", source = "pieA")
    req(!is.null(ev), nrow(ev) > 0)
    
    cid <- ev$key[1]
    req(!is.null(cid), !is.na(cid), cid != "")
    
    show_cluster_modal_activos(cid)
  }, ignoreInit = TRUE)
  
  
  observeEvent(plotly::event_data("plotly_click", source = "pieC"), {
    ev <- plotly::event_data("plotly_click", source = "pieC")
    req(!is.null(ev), nrow(ev) > 0)
    
    cid <- ev$key[1]
    req(!is.null(cid), !is.na(cid), cid != "")
    
    show_cluster_modal_cancelados(cid)
  }, ignoreInit = TRUE)
  
  
  
  
  observeEvent(input$cluster_cancelado_click, {
    req(input$cluster_cancelado_click)
    show_cluster_modal_cancelados(input$cluster_cancelado_click)
  })
  
  
  
  render_cluster_boxes <- function(keys, meta, suffix = "A", box_width = 4){
    
    
    boxes <- lapply(keys, function(k){
      k_chr <- as.character(k)
      info <- meta[[k_chr]]
      if (is.null(info)) {
        info <- list(
          nombre = paste("Cluster", k_chr),
          bullets = c("Sin descripción configurada.")
        )
      }
      
      img_src <- paste0("C", k_chr, suffix, ".png")
      
      has_img <- file.exists(file.path("www", img_src))
      
      box(
        width = box_width, status = "success", solidHeader = TRUE,
        title = tags$div(
          class = "cluster-head",
          if (has_img) tags$img(src = img_src) else NULL,
          tags$div(
            tags$div(class = "cluster-title", paste0("Cluster ", k_chr, ": ", info$nombre))
          )
        ),
        tags$div(
          class = "cluster-body",
          tags$ul(lapply(info$bullets, tags$li))
        )
      )
    })
    
    per_row <- if (box_width == 6) 2 else if (box_width == 4) 3 else 2
    rows <- split(boxes, ceiling(seq_along(boxes) / per_row))
    
    tagList(lapply(rows, function(rr) fluidRow(rr)))
  }
  
  
  
  cancelados_summary <- reactive({
    req(pac_raw())
    df <- pac_raw()
    
    validate(need("cluster" %in% names(df), "No existe la columna 'cluster' en la base."))
    validate(need("grupo_churn" %in% names(df), "No existe la columna 'grupo_churn' en la base."))
    
    df %>%
      mutate(
        cluster = clean_cluster(cluster),
        grupo_norm = norm_grupo(grupo_churn)
      ) %>%
      filter(grupo_norm == "CANCELADO", !is.na(cluster)) %>%
      count(cluster, name = "n") %>%
      mutate(
        p = n / sum(n),
        cluster_chr = as.character(cluster),
        nombre = vapply(cluster_chr, function(k){
          info <- perfil_cancelados[[k]]
          if (!is.null(info) && !is.null(info$nombre)) info$nombre else paste("Cluster", k)
        }, character(1))
      ) %>%
      select(-cluster_chr) %>%
      arrange(desc(n))
  })
  
  
  
  output$pie_cancelados <- renderPlotly({
    dd <- cancelados_summary()
    
    fnt <- list(family = "Barlow, Arial, sans-serif", size = 13, color = "#2A2E3A")
    
    if (is.null(dd) || nrow(dd) == 0) {
      return(
        plotly::plotly_empty() %>%
          plotly::layout(
            title = list(text = "<b>No hay datos de CANCELADO para graficar</b>", x = 0.5),
            font  = fnt
          )
      )
    }
    
    p <- plotly::plot_ly(
      dd,
      type   = "pie",
      labels = ~nombre,
      values = ~n,
      key    = ~as.character(cluster),
      textinfo  = "percent",
      hoverinfo = "text",
      text = ~paste0(
        "<b>", nombre, "</b><br>",
        "Afiliados: ", scales::comma(n), "<br>",
        "Participación: ", scales::percent(p, accuracy = 1),
        "<br><i>Click para ver detalle</i>"
      ),
      sort   = FALSE,
      source = "pieC"
    ) %>%
      plotly::event_register("plotly_click") %>%
      plotly::layout(
        font = fnt,
        showlegend = TRUE,
        legend = list(font = fnt) 
      )
    
    p
  })
  
  
  
  perfil_base_seg <- reactive({
    req(pac_raw())
    df <- pac_raw()
    
    
    df <- df %>%
      dplyr::mutate(
        cluster = clean_cluster(cluster),
        grupo_norm = norm_grupo(grupo_churn)
      )
    
    
    tab_sel <- input$perfiles_subtabs %||% "Activos"
    
    if (identical(tab_sel, "Cancelados")) {
      df <- df %>% dplyr::filter(grupo_norm == "CANCELADO")
    } else {
      df <- df %>% dplyr::filter(grupo_norm == "ACTIVO")
    }
    
    df %>% dplyr::filter(!is.na(cluster))
  })
  
  
  output$plt_cluster_dist <- renderPlotly({
    df <- perfil_base_seg()
    req(nrow(df) > 0)
    
    
    fnt <- list(family = "Barlow, Arial, sans-serif", size = 13, color = "#2A2E3A")
    
    var_sel <- input$var_cluster_dist
    req(!is.null(var_sel), var_sel %in% names(df))
    
    tab_sel <- input$perfiles_subtabs %||% "Activos"
    perfiles <- if (identical(tab_sel, "Cancelados")) perfil_cancelados else perfil_activos
    
    
    rank_df <- df %>%
      dplyr::mutate(cluster_chr = as.character(cluster)) %>%
      dplyr::count(cluster_chr, name = "n_total") %>%
      dplyr::mutate(p_total = n_total / sum(n_total)) %>%
      dplyr::arrange(dplyr::desc(p_total))
    
    orden_clusters <- rank_df$cluster_chr 
    
    
    dd <- df %>%
      dplyr::mutate(
        nivel = as.character(.data[[var_sel]]),
        nivel = dplyr::if_else(is.na(nivel) | nivel == "", "SIN_INFORMACION", nivel),
        cluster_chr = as.character(cluster)
      ) %>%
      dplyr::count(cluster_chr, nivel, name = "n") %>%
      dplyr::group_by(cluster_chr) %>%
      dplyr::mutate(pct_cluster = n / sum(n)) %>%
      dplyr::ungroup() %>%
      dplyr::mutate(
        cluster_label = vapply(cluster_chr, function(k){
          info <- perfiles[[k]]
          if (!is.null(info) && !is.null(info$nombre)) info$nombre else paste("Cluster", k)
        }, character(1)),
        cluster_x = cluster_label
      )
    
    
    levels_x <- vapply(orden_clusters, function(k){
      info <- perfiles[[k]]
      if (!is.null(info) && !is.null(info$nombre)) info$nombre else paste("Cluster", k)
    }, character(1))
    
    dd$cluster_x <- factor(dd$cluster_x, levels = levels_x)
    
    metric  <- input$metric_cluster_dist %||% "pct_cluster"
    barmode <- input$barmode_cluster_dist %||% "stack"
    
    yvec   <- if (metric == "count") dd$n else dd$pct_cluster
    ytitle <- if (metric == "count") "Afiliados" else "% dentro del cluster"
    
    plotly::plot_ly(
      dd,
      x = ~cluster_x,
      y = yvec,
      color = ~nivel,
      type  = "bar",
      text  = ~nivel,
      hovertemplate = paste0(
        "<b>Cluster:</b> %{x}<br>",
        "<b>Nivel:</b> %{fullData.name}<br>",
        if (metric == "count") "<b>N:</b> %{y}<br>" else "<b>%:</b> %{y:.1%}<br>",
        "<extra></extra>"
      )
    ) %>%
      plotly::layout(
        font = fnt,            
        barmode = barmode,
        xaxis = list(title = "Perfil", tickangle = -20),
        yaxis = list(title = ytitle, rangemode = "tozero"),
        legend = list(
          title = list(text = var_labels[[var_sel]] %||% var_sel),
          font  = fnt   
        ),
        margin = list(l = 50, r = 10, t = 20, b = 90)
      )
  })
  
  
  
  output$icons_cancelados <- renderUI({
    dd <- cancelados_summary()
    req(nrow(dd) > 0)
    
    tags$div(
      class = "icons-row",
      lapply(dd$cluster, function(cid){
        cid <- as.character(cid)
        src <- paste0("C", cid, "C.png")
        nombre <- if (!is.null(perfil_cancelados[[cid]]$nombre)) perfil_cancelados[[cid]]$nombre else paste("Cluster", cid)
        
        if (!file.exists(file.path("www", src))) return(NULL)
        
        tags$div(
          class = "icon-wrap",
          tags$img(
            src = src,
            class = "cluster-icon",
            title = nombre,
            onclick = sprintf(
              "Shiny.setInputValue('cluster_cancelado_click', '%s', {priority: 'event'});",
              cid
            )
          ),
          tags$div(class = "icon-label", paste0("C", cid))
        )
      })
    )
  })
  
  show_cluster_modal_cancelados <- function(cid){
    cid <- as.character(cid)
    info <- perfil_cancelados[[cid]]
    validate(need(!is.null(info), paste0("No hay descripción configurada para Cluster ", cid)))
    
    src <- paste0("C", cid, "C.png")
    
    showModal(modalDialog(
      title = HTML(paste0(info$nombre, "</b>")),
      size = "l",
      easyClose = TRUE,
      footer = modalButton("Cerrar"),
      tags$div(
        style="display:flex; gap:18px; align-items:flex-start;",
        tags$img(
          src = src,
          style="width:180px;height:180px;border-radius:12px;background:#fff;"
        ),
        tags$div(tags$ul(lapply(info$bullets, tags$li)))
      )
    ))
  }
  
  
  
  output$icons_activos_side <- renderUI({
    dd <- activos_summary()
    req(nrow(dd) > 0)
    
    dd <- dd %>% arrange(desc(p))
    
    tags$div(
      class = "icons-side",
      lapply(seq_len(nrow(dd)), function(i){
        cid <- as.character(dd$cluster[i])
        nombre <- dd$nombre[i]
        pct <- scales::percent(dd$p[i], accuracy = 1)
        
        src <- paste0("C", cid, "A.png")
        if (!file.exists(file.path("www", src))) return(NULL)
        
        tags$div(
          class = "icon-card",
          onclick = sprintf("Shiny.setInputValue('cluster_activo_click', '%s', {priority: 'event'});", cid),
          tags$img(src = src),
          tags$div(class = "icon-name", nombre),
          tags$div(class = "icon-pct", pct)
        )
      })
    )
  })
  
  output$icons_cancelados_side <- renderUI({
    dd <- cancelados_summary()
    req(nrow(dd) > 0)
    
    dd <- dd %>% arrange(desc(p))
    
    tags$div(
      class = "icons-side",
      lapply(seq_len(nrow(dd)), function(i){
        cid <- as.character(dd$cluster[i])
        nombre <- dd$nombre[i]
        pct <- scales::percent(dd$p[i], accuracy = 1)
        
        src <- paste0("C", cid, "C.png") 
        if (!file.exists(file.path("www", src))) return(NULL)
        
        tags$div(
          class = "icon-card",
          onclick = sprintf("Shiny.setInputValue('cluster_cancelado_click', '%s', {priority: 'event'});", cid),
          tags$img(src = src),
          tags$div(class = "icon-name", nombre),
          tags$div(class = "icon-pct", pct)
        )
      })
    )
  })
  
  
  
  grupo_operativo_desc <- c(
    CRITICO = "El grupo Crítico concentra afiliados con probabilidad alta de cancelación en el muy corto plazo, principalmente de 1 a 3 meses.",
    ALTO = "El grupo de riesgo Alto corresponde a afiliados con riesgo relevante que se materializa hacia el mediano plazo de aproximadamente 6 meses.",
    ESTRATEGIA_PROACTIVA = "Estrategia Proactiva agrupa afiliados cuyo riesgo es más visible en el horizonte, donde la gestión preventiva puede anticiparse a la decisión de salida.",
    BAJO = "El grupo de riesgo Bajo incluye al resto de afiliados con probabilidades inferiores a los umbrales definidos."
  )
  
  rv_grupo_operativo <- reactiveVal(NULL)
  
  output$tbl_grupo_operativo <- DT::renderDT({
    df <- pac_fuga_flt()
    req(nrow(df) > 0)
    
    validate(need("grupo_operativo" %in% names(df), "No existe la columna 'grupo_operativo' en la base."))
    
    dd <- df %>%
      dplyr::mutate(grupo_operativo = as.character(grupo_operativo)) %>%
      dplyr::filter(!is.na(grupo_operativo), grupo_operativo != "") %>%
      dplyr::mutate(
        grupo_operativo = factor(grupo_operativo,
                                 levels = c("CRITICO", "ALTO", "ESTRATEGIA_PROACTIVA", "BAJO")
        ),
        Grupo = dplyr::case_when(
          as.character(grupo_operativo) == "CRITICO" ~ "Crítico",
          as.character(grupo_operativo) == "ALTO" ~ "Alto",
          as.character(grupo_operativo) == "ESTRATEGIA_PROACTIVA" ~ "Estrategia Proactiva",
          as.character(grupo_operativo) == "BAJO" ~ "Bajo",
          TRUE ~ as.character(grupo_operativo)
        ),
        Grupo_html = sprintf(
          '<span title="%s" style="cursor:pointer;">%s</span>',
          grupo_operativo_desc[as.character(grupo_operativo)] %||% "Sin descripción disponible.",
          Grupo
        )
      ) %>%
      dplyr::count(grupo_operativo, Grupo_html, name = "Afiliados") %>%
      dplyr::arrange(grupo_operativo) %>%
      dplyr::mutate(grupo_operativo = as.character(grupo_operativo)) %>%
      dplyr::select(grupo_operativo, Grupo_html, Afiliados)
    
    rv_grupo_operativo(dd)
    
    dt <- DT::datatable(
      dd %>% dplyr::select(`Grupo operativo` = Grupo_html, Afiliados),
      rownames = FALSE,
      escape = FALSE,
      options = list(
        pageLength = 6,
        dom = "tip",
        ordering = FALSE
      )
    )
    
    dt %>% DT::formatCurrency("Afiliados", currency = "", interval = 3, mark = ",", digits = 0)
  })
  
  
  
  observeEvent(input$tbl_grupo_operativo_cell_clicked, {
    click <- input$tbl_grupo_operativo_cell_clicked
    req(!is.null(click$row), click$row > 0)
    
    dd <- rv_grupo_operativo()
    req(!is.null(dd), nrow(dd) >= click$row)
    
    code <- dd$grupo_operativo[click$row]
    desc <- grupo_operativo_desc[[code]] %||% "Sin descripción disponible."
    
    titulo <- dplyr::case_when(
      code == "CRITICO" ~ "Crítico",
      code == "ALTO" ~ "Alto",
      code == "ESTRATEGIA_PROACTIVA" ~ "Estrategia Proactiva",
      code == "BAJO" ~ "Bajo",
      TRUE ~ code
    )
    
    showModal(modalDialog(
      title = paste0("Grupo operativo: ", titulo),
      tags$div(
        style = "font-family: Barlow, Arial, sans-serif; font-size: 14px;",
        tags$p(desc)
      ),
      easyClose = TRUE,
      footer = modalButton("Cerrar")
    ))
  }, ignoreInit = TRUE)
  
  
  numify_simple <- function(x) {
    x <- trimws(as.character(x))
    x <- gsub("\u00A0", " ", x, fixed = TRUE)
    x <- gsub(" ", "", x, fixed = TRUE)
    x <- gsub(",", ".", x, fixed = TRUE)
    suppressWarnings(as.numeric(x))
  }
  
  
  read_shap_long_csv <- function() {
    cand <- c("shap_summary_long.csv", file.path("data", "shap_summary_long.csv"))
    path <- cand[file.exists(cand)][1]
    if (is.na(path) || is.null(path)) return(NULL)
    
    df <- readr::read_csv(path, show_col_types = FALSE)
    names(df) <- trimws(names(df))
    df
  }
  
  
  pretty_feature_name <- function(x) {
    x <- as.character(x)
    x <- gsub("_+", " ", x)
    x <- gsub("\\s+", " ", x)
    x <- trimws(x)
    
    x <- stringr::str_to_title(tolower(x))
    
    acronyms <- c("Pac", "Pbs", "Ips", "Eps", "Ltv", "Ibnr", "Rsf", "Shap", "Id", "Bin")
    for (a in acronyms) {
      x <- gsub(paste0("\\b", a, "\\b"), toupper(a), x, perl = TRUE)
    }
    
    x <- gsub("\\bCd\\b", "Cod.", x, perl = TRUE)
    x
  }
  
  
  sample_by_group <- function(df, group_col, max_n = 1500, seed = 123) {
    set.seed(seed)
    g <- df[[group_col]]
    idx <- split(seq_len(nrow(df)), g)
    
    keep <- unlist(lapply(idx, function(ii) {
      if (length(ii) <= max_n) ii else sample(ii, max_n)
    }), use.names = FALSE)
    
    df[keep, , drop = FALSE]
  }
  
  
  
  
  output$plt_importancia_variables <- renderPlotly({
    
    df <- read_shap_long_csv()
    req(df)
    
    validate(
      need(all(c("ID", "feature", "shap_value", "feature_value") %in% names(df)),
           "shap_summary_long.csv debe tener columnas: ID, feature, shap_value, feature_value.")
    )
    
    df <- df %>%
      dplyr::mutate(
        ID           = as.character(ID),
        feature      = as.character(feature),
        shap_value   = suppressWarnings(as.numeric(shap_value)),
        feature_value= suppressWarnings(as.numeric(feature_value))
      ) %>%
      dplyr::filter(!is.na(feature), feature != "", !is.na(shap_value))
    
    req(nrow(df) > 0)
    
    top_n <- 20
    max_points_per_feature <- 1500
    
    
    feat_rank <- df %>%
      dplyr::group_by(feature) %>%
      dplyr::summarise(
        mean_abs = mean(abs(shap_value), na.rm = TRUE),
        .groups = "drop"
      ) %>%
      dplyr::arrange(dplyr::desc(mean_abs)) %>%
      dplyr::slice_head(n = top_n)
    
    dd0 <- df %>% dplyr::semi_join(feat_rank, by = "feature")
    req(nrow(dd0) > 0)
    
    dd <- sample_by_group(dd0, group_col = "feature", max_n = max_points_per_feature, seed = 123) %>%
      dplyr::mutate(feature_pretty = pretty_feature_name(feature))
    
    
    levels_pretty <- pretty_feature_name(rev(feat_rank$feature))
    dd$feature_pretty <- factor(dd$feature_pretty, levels = levels_pretty)
    
    
    y_base <- as.numeric(dd$feature_pretty)
    set.seed(123)
    dd$y_jit <- y_base + runif(nrow(dd), min = -0.33, max = 0.33)
    
    
    dd <- dd %>%
      dplyr::group_by(feature_pretty) %>%
      dplyr::mutate(
        fv = feature_value,
        fv_min = suppressWarnings(min(fv, na.rm = TRUE)),
        fv_max = suppressWarnings(max(fv, na.rm = TRUE)),
        fv01 = dplyr::case_when(
          all(is.na(fv)) ~ 0.5,
          isTRUE(fv_max == fv_min) ~ 0.5,
          is.na(fv) ~ 0.5,
          TRUE ~ (fv - fv_min) / (fv_max - fv_min)
        )
      ) %>%
      dplyr::ungroup()
    
    colorscale_corp <- list(
      list(0,   pal$blue_primary),
      list(0.5, pal$white),
      list(1,   pal$green_primary)
    )
    
    
    plotly::plot_ly(
      data = dd,
      x = ~shap_value,
      y = ~y_jit,
      type = "scattergl",
      mode = "markers",
      marker = list(
        size = 6,
        opacity = 0.60,
        color = ~fv01,
        colorscale = colorscale_corp,
        cmin = 0, cmax = 1,
        showscale = TRUE,
        colorbar = list(
          title = "Valor de la variable",
          tickmode = "array",
          tickvals = c(0, 0.5, 1),
          ticktext = c("Bajo", "Medio", "Alto"),
          titlefont = list(family = "Barlow, sans-serif"),
          tickfont  = list(family = "Barlow, sans-serif")
        )
      ),
      customdata = ~cbind(
        as.character(feature_pretty),
        as.character(ID),
        as.numeric(feature_value),
        as.numeric(fv01)
      )
      
    ) %>%
      plotly::layout(
        paper_bgcolor = pal$bg,
        plot_bgcolor  = pal$bg,
        font = list(family = "Barlow, sans-serif", color = pal$navy),
        title = list(
          text = paste0(
            #"<b>SHAP summary (impacto + valor de variable)</b>",
            "<br><span style='font-size:12px;color:", pal$gray, ";'>",
            #"Ranking = importancia global promedio (|SHAP|). ",
            "Eje X = Positivo → fuga; Negativo → permanencia. ",
            "Color = Valor dentro de la variable.",
            "</span>"
          )
        ),
        xaxis = list(
          title = "Impacto en el riesgo",
          zeroline = FALSE,
          gridcolor = "rgba(128,157,166,0.20)"
        ),
        yaxis = list(
          title = "",
          tickmode = "array",
          tickvals = seq_along(levels(dd$feature_pretty)),
          ticktext = levels(dd$feature_pretty),
          showgrid = FALSE
        ),
        shapes = list(
          list(
            type = "line",
            x0 = 0, x1 = 0,
            y0 = 0.5, y1 = length(levels(dd$feature_pretty)) + 0.5,
            xref = "x", yref = "y",
            line = list(color = "rgba(42,46,58,0.35)", width = 1)
          )
        ),
        
        margin = list(l = 260, r = 60, t = 90, b = 60)
      ) %>%
      plotly::config(displayModeBar = TRUE, displaylogo = FALSE)
  })
  
  
  output$shap_insights <- renderUI({
    
    df <- read_shap_long_csv()
    req(df)
    
    df <- df %>%
      dplyr::mutate(
        ID            = as.character(ID),
        feature       = as.character(feature),
        shap_value    = suppressWarnings(as.numeric(shap_value)),
        feature_value = suppressWarnings(as.numeric(feature_value))
      ) %>%
      dplyr::filter(!is.na(feature), feature != "", !is.na(shap_value))
    
    req(nrow(df) > 0)
    
    
    df2 <- df %>%
      dplyr::group_by(feature) %>%
      dplyr::mutate(
        fv = feature_value,
        fv_min = suppressWarnings(min(fv, na.rm = TRUE)),
        fv_max = suppressWarnings(max(fv, na.rm = TRUE)),
        fv01 = dplyr::case_when(
          all(is.na(fv)) ~ NA_real_,
          isTRUE(fv_max == fv_min) ~ 0.5,
          is.na(fv) ~ NA_real_,
          TRUE ~ (fv - fv_min) / (fv_max - fv_min)
        )
      ) %>%
      dplyr::ungroup()
    
    
    top_k   <- 7
    q_high  <- 0.80
    min_n   <- 80  
    
    metrics <- df2 %>%
      dplyr::group_by(feature) %>%
      dplyr::summarise(
        mean_abs = mean(abs(shap_value), na.rm = TRUE),
        
        
        n_high   = sum(!is.na(fv01) & fv01 >= q_high),
        p_high   = mean(!is.na(fv01) & fv01 >= q_high),
        
        
        shap_high_mean   = mean(shap_value[!is.na(fv01) & fv01 >= q_high], na.rm = TRUE),
        shap_high_median = stats::median(shap_value[!is.na(fv01) & fv01 >= q_high], na.rm = TRUE),
        shap_high_p90    = stats::quantile(shap_value[!is.na(fv01) & fv01 >= q_high], 0.90, na.rm = TRUE),
        
        
        pct_high_pos = mean(shap_value[!is.na(fv01) & fv01 >= q_high] > 0, na.rm = TRUE),
        
        .groups = "drop"
      ) %>%
      dplyr::mutate(
        feature_pretty = pretty_feature_name(feature),
        
        
        score_fuga_high = dplyr::if_else(shap_high_mean > 0, shap_high_mean * sqrt(p_high), NA_real_),
        score_perm_high = dplyr::if_else(shap_high_mean < 0, abs(shap_high_mean) * sqrt(p_high), NA_real_)
      )
    
    
    top_fuga_high <- metrics %>%
      dplyr::filter(!is.na(score_fuga_high), n_high >= min_n) %>%
      dplyr::arrange(dplyr::desc(score_fuga_high)) %>%
      dplyr::slice_head(n = top_k)
    
    top_perm_high <- metrics %>%
      dplyr::filter(!is.na(score_perm_high), n_high >= min_n) %>%
      dplyr::arrange(dplyr::desc(score_perm_high)) %>%
      dplyr::slice_head(n = top_k)
    
    fmt <- function(x) ifelse(is.na(x), "NA", formatC(x, format="f", digits=4))
    
    htmltools::tagList(
      tags$div(
        style = "font-family: Barlow, sans-serif; color: #2a2e3a;",
        tags$p(
          style="font-size:14px;color:#809da6;margin-bottom:10px;",
          HTML(paste0(
            "Interpretación enfocada en el apalancamiento de las variables hacia la fuga y permanencia de los afiliados.</b>"
            
          ))
        ),
        
        tags$h4(style="font-size:16px;font-weight:700;margin:10px 0 6px 0;",
                HTML(paste0("<span style='color:", pal$orange, ";'>Variables que apalancan la fuga</span>"))),
        if (nrow(top_fuga_high) == 0) {
          tags$p(style="font-size:16px;color:#809da6;",
                 HTML("No se encontraron variables con señal robusta (o no cumplen mínimo de casos en alto)."))
        } else {
          tags$ul(
            style="padding-left:18px;margin-top:6px;",
            lapply(seq_len(nrow(top_fuga_high)), function(i){
              r <- top_fuga_high[i,]
              tags$li(
                style="font-size:14px;margin-bottom:6px;",
                HTML(paste0(
                  "<b>", r$feature_pretty, "</b> ",
                  
                  "</span>"
                ))
              )
            })
          )
        },
        
        tags$h4(style="font-size:16px;font-weight:700;margin:12px 0 6px 0;",
                HTML(paste0("<span style='color:", pal$green_alt, ";'>Variables que apalancan la permanencia</span>"))),
        if (nrow(top_perm_high) == 0) {
          tags$p(style="font-size:16px;color:#809da6;",
                 HTML("No se encontraron variables con señal robusta (o no cumplen mínimo de casos en alto)."))
        } else {
          tags$ul(
            style="padding-left:18px;margin-top:6px;",
            lapply(seq_len(nrow(top_perm_high)), function(i){
              r <- top_perm_high[i,]
              tags$li(
                style="font-size:14px;margin-bottom:6px;",
                HTML(paste0(
                  "<b>", r$feature_pretty, "</b>",
                  
                  "</span>"
                ))
              )
            })
          )
        }
        
        
      )
    )
  })
  
  
  
  
  
  impacto_vars <- reactive({
    req(pac_activos())
    df <- pac_activos()
    
    vars <- filter_vars()
    vars <- setdiff(vars, c("ESTADO", "Estado", "GRUPO_CAUSA_CANCELACION"))
    
    if ("grupo_operativo" %in% names(df)) {
      vars <- unique(c(vars, "grupo_operativo"))
    }
    
    vars
  })
  
  apply_impacto_filters <- function(df, vars) {
    
    for (v in vars) {
      id <- paste0("im_", v)
      sel <- input[[id]]  
      
      if (!is.null(sel) && sel != "" && !identical(sel, ALL_OPT)) {
        if (v %in% names(df)) {
          df <- dplyr::filter(df, .data[[v]] == sel)
        }
      }
    }
    df
  }
  
  
  impacto_base <- reactive({
    df <- pac_fuga_flt() 
    req(df, nrow(df) > 0)
    
    
    if ("grupo_churn" %in% names(df)) {
      df <- dplyr::filter(df, grupo_churn == "ACTIVOS")
    }
    
    
    vars <- impacto_vars()
    df <- apply_impacto_filters(df, vars)
    
    validate(
      need(nrow(df) > 0, "No hay afiliados activos con la combinación actual de filtros (Impacto).")
    )
    
    
    validate(need("risk_12m" %in% names(df), "Falta risk_12m en la base filtrada."))
    df <- df %>%
      dplyr::mutate(risk_12m = suppressWarnings(as.numeric(risk_12m))) %>%
      dplyr::filter(is.finite(risk_12m))
    
    validate(
      need(nrow(df) > 0, "Los filtros dejaron la base sin risk_12m válido (NA/Inf).")
    )
    
    df
  })
  
  
  
  impacto_res <- reactive({
    
    
    num1 <- function(x, default = 0) {
      x <- trimws(as.character(x))
      x <- gsub("\u00A0", " ", x, fixed = TRUE) 
      x <- gsub(" ", "", x, fixed = TRUE)       
      x <- gsub(",", "", x, fixed = TRUE)       
      x <- suppressWarnings(as.numeric(x))
      if (length(x) != 1L || is.na(x) || !is.finite(x)) default else x
    }
    
    
    int1 <- function(x, default = 100L) {
      x <- trimws(as.character(x))
      x <- gsub(",", "", x, fixed = TRUE)
      x <- suppressWarnings(as.integer(x))
      if (length(x) != 1L || is.na(x) || !is.finite(x) || x <= 0L) default else x
    }
    
    
    
    df <- impacto_base()
    req(df, nrow(df) > 0)
    
    validate(
      need("risk_12m" %in% names(df),
           "No existe la columna 'risk_12m' en la base filtrada de afiliados activos.")
    )
    
    
    df$risk_12m <- suppressWarnings(as.numeric(df$risk_12m))
    df$risk_12m[is.na(df$risk_12m) | !is.finite(df$risk_12m)] <- 0
    
    
    df_dt <- data.table::as.data.table(df)
    data.table::setorder(df_dt, -risk_12m)
    
    
    n_manage <- int1(input$PRESUPUESTO_N, default = min(100L, nrow(df_dt)))
    n_manage <- min(n_manage, nrow(df_dt))
    top <- df_dt[seq_len(n_manage)]
    
    
    params <- list(
      ltv   = num1(input$LTV_CLIENTE, 0),
      c_ll  = num1(input$COSTO_LLAMADA, 0),
      c_inc = num1(input$COSTO_INCENTIVO, 0),
      exito = num1(input$TASA_EXITO, 0)
    )
    
    
    
    fugas_esp <- sum(top$risk_12m, na.rm = TRUE)
    salvados  <- fugas_esp * params$exito
    retorno   <- salvados * params$ltv
    
    costo_llamadas <- n_manage * params$c_ll
    costo_incent   <- salvados * params$c_inc
    costo          <- costo_llamadas + costo_incent
    
    ganancia <- retorno - costo
    roi <- if (is.finite(costo) && costo > 0) ganancia / costo else NA_real_
    
    
    
    list(
      base     = as.data.frame(df_dt),
      top      = as.data.frame(top),
      n_manage = n_manage,
      params   = params,
      kpis     = list(
        fugas_esp      = fugas_esp,
        salvados_esp   = salvados,
        retorno_esp    = retorno,
        costo_esp      = costo,
        ganancia_neta  = ganancia,
        roi            = roi
      )
    )
  })
  
  
  
  
  
  impacto_res_esperado <- reactive({
    r <- impacto_res()
    req(r)
    
    df_base <- r$base
    df_top  <- r$top
    req(nrow(df_base) > 0, nrow(df_top) > 0)
    
    ltv   <- r$params$ltv
    c_ll  <- r$params$c_ll
    c_inc <- r$params$c_inc
    exito <- r$params$exito
    
    fugas_esp_n   <- sum(df_top$risk_12m, na.rm = TRUE)
    prob_prom_top <- mean(df_top$risk_12m, na.rm = TRUE)
    
    salvados_esp  <- fugas_esp_n * exito
    retorno_esp   <- salvados_esp * ltv
    
    costo_llamadas <- r$n_manage * c_ll
    costo_incent   <- salvados_esp * c_inc
    costo_esp      <- costo_llamadas + costo_incent
    
    ganancia_esp <- retorno_esp - costo_esp
    roi_esp <- if (!is.na(costo_esp) && is.finite(costo_esp) && costo_esp > 0) ganancia_esp / costo_esp else NA_real_
    
    
    list(
      n_activos_filtrados = nrow(df_base),
      n_manage            = r$n_manage,
      fugas_esp_n         = fugas_esp_n,
      prob_prom_top       = prob_prom_top,
      salvados_esp        = salvados_esp,
      retorno_esp         = retorno_esp,
      costo_llamadas      = costo_llamadas,
      costo_incent        = costo_incent,
      costo_esp           = costo_esp,
      ganancia_esp        = ganancia_esp,
      roi_esp             = roi_esp
    )
  })
  
  
  
  
  
  output$plt_curva_rentabilidad <- renderPlotly({
    r <- impacto_res()
    req(r)
    
    df <- r$base %>% dplyr::arrange(dplyr::desc(risk_12m))
    
    nmax <- min(r$n_manage, nrow(df), na.rm = TRUE)
    if (!is.finite(nmax) || is.na(nmax)) nmax <- 0L
    if (isTRUE(nmax < 10)) nmax <- min(100L, nrow(df))
    
    ks <- unique(round(seq(50, nmax, length.out = 25)))
    ks <- ks[ks > 0 & ks <= nrow(df)]
    ks <- sort(unique(c(ks, r$n_manage))) 
    
    ltv   <- r$params$ltv
    c_ll  <- r$params$c_ll
    c_inc <- r$params$c_inc
    exito <- r$params$exito
    
    risk <- df$risk_12m
    risk[!is.finite(risk) | is.na(risk)] <- 0
    
    cs <- cumsum(risk)
    fugas_ks <- cs[ks]
    
    salvados_ks <- ks * exito
    salvados_ks <- pmin(fugas_ks, salvados_ks)
    
    retorno_ks <- salvados_ks * ltv
    
    costo_llamadas_ks <- ks * c_ll
    costo_incent_ks   <- salvados_ks * c_inc
    costo_total_ks    <- costo_llamadas_ks + costo_incent_ks
    
    curve <- data.frame(
      k = ks,
      ganancia_neta = retorno_ks - costo_total_ks
    )
    
    plot_ly(
      curve, x = ~k, y = ~ganancia_neta,
      type = "scatter", mode = "lines+markers",
      hovertemplate = "<b>Gestionados:</b> %{x}<br><b>Ganancia neta:</b> %{y:,.0f}<extra></extra>"
    ) %>%
      layout(
        font = list(family = "Barlow, sans-serif"),
        xaxis = list(
          title = "Afiliados gestionados",
          titlefont = list(family = "Barlow, sans-serif"),
          tickfont  = list(family = "Barlow, sans-serif")
        ),
        yaxis = list(
          title = "Ganancia neta esperada",
          titlefont = list(family = "Barlow, sans-serif"),
          tickfont  = list(family = "Barlow, sans-serif")
        ),
        margin = list(l = 60, r = 15, t = 30, b = 55)
      ) %>%
      config(displayModeBar = FALSE)
  })
  
  
  
  
  
  
  output$tbl_resultados_impacto <- DT::renderDT({
    r <- impacto_res_esperado()
    req(r)
    
    tab <- data.frame(
      Métrica = c(
        "Total afiliados activos",
        "Top N Afiliados gestionados",
        "Fugas esperadas",
        "Probabilidad promedio de fuga del TOP N",
        "Clientes retenidos esperados",
        "Retorno esperado",
        "Costo llamadas",
        "Costo incentivos esperado",
        "Costo total esperado",
        "Ganancia neta esperada",
        "ROI esperado"
      ),
      Valor = c(
        scales::comma(r$n_activos_filtrados),
        scales::comma(r$n_manage),
        scales::comma(round(r$fugas_esp_n, 0)),
        scales::percent(r$prob_prom_top, accuracy = 0.1),
        scales::comma(round(r$salvados_esp, 0)),
        scales::comma(round(r$retorno_esp, 0)),
        scales::comma(round(r$costo_llamadas, 0)),
        scales::comma(round(r$costo_incent, 0)),
        scales::comma(round(r$costo_esp, 0)),
        scales::comma(round(r$ganancia_esp, 0)),
        scales::percent(r$roi_esp, accuracy = 0.1)
      ),
      check.names = FALSE
    )
    
    
    DT::datatable(tab, rownames = FALSE, options = list(dom = "tip", pageLength = 20))
  })
  
  output$plt_heatmap_incentivo_exito <- renderPlotly({
    r <- impacto_res()
    req(r)
    
    df_top <- r$top
    req(nrow(df_top) > 0)
    
    ltv  <- r$params$ltv
    c_ll <- r$params$c_ll
    
    incentivos <- round(seq(0, r$params$c_inc * 2, length.out = 15))
    exitos     <- seq(0.05, 0.80, by = 0.05)
    
    fugas_esp <- sum(df_top$risk_12m, na.rm = TRUE)
    N <- r$n_manage
    
    grid <- expand.grid(COSTO_INCENTIVO = incentivos, TASA_EXITO = exitos) %>%
      dplyr::mutate(
        salvados = fugas_esp * TASA_EXITO,
        retorno  = salvados * ltv,
        costo_llamadas = N * c_ll,
        costo_incent   = salvados * COSTO_INCENTIVO,
        costo_total    = costo_llamadas + costo_incent,
        ganancia_neta  = retorno - costo_total
      )
    
    plot_ly(
      grid,
      x = ~COSTO_INCENTIVO,
      y = ~TASA_EXITO,
      z = ~ganancia_neta,
      type = "heatmap",
      colorbar = list(
        title = "Ganancia neta",
        titlefont = list(family = "Barlow, sans-serif"),
        tickfont  = list(family = "Barlow, sans-serif")
      ),
      hovertemplate = paste0(
        "<b>Incentivo:</b> %{x:,.0f}<br>",
        "<b>Éxito:</b> %{y:.0%}<br>",
        "<b>Ganancia neta:</b> %{z:,.0f}<extra></extra>"
      )
    ) %>%
      layout(
        font = list(family = "Barlow, sans-serif"),
        xaxis = list(title = "Costo Incentivo", titlefont = list(family="Barlow, sans-serif"), tickfont=list(family="Barlow, sans-serif")),
        yaxis = list(title = "Tasa de éxito", tickformat = ".0%", titlefont = list(family="Barlow, sans-serif"), tickfont=list(family="Barlow, sans-serif")),
        margin = list(l = 60, r = 20, t = 20, b = 60)
      ) %>%
      config(displayModeBar = FALSE)
  })
  
  
}

shinyApp(ui, server)