# Data Dictionary
## Churn Prediction and Permanence Modelling — EPS ABC

> **Note:** Source data files are not included in this repository in compliance with the confidentiality agreement with the client organisation. This dictionary documents the structure, meaning, and provenance of all variables used in the analytical pipeline, enabling reproducibility of the methodology with equivalent data.

---

## Data Sources

Three internal datasets from EPS ABC were integrated into a single analytical base (`Merge_Completo_vigencia_total.parquet`):

| Dataset | Internal name | Description |
|---|---|---|
| Permanence records | `df_permanencia` | Subscription history — one row per affiliate per active period |
| CRM / Complaints | `df_CRM` | Customer interactions and formal PQRS (complaints, requests, suggestions) |
| Medical consumption | `df_consumos` | Service utilisation records per affiliate across PBS and PAC networks |

---

## Variable Reference

### 🔑 Identifiers & Dates

| Variable | Type | Source | Description |
|---|---|---|---|
| `AFILIADO_ID_EPS` | string | df_permanencia | Anonymised affiliate identifier. Excluded from models to prevent leakage. |
| `FECHA_INICIO` | date | df_permanencia | Start date of the complementary plan (PAC) subscription period. |
| `FECHA_FIN` | date | df_permanencia | End date of the subscription period. For active affiliates, imputed as the analysis cut-off date. |

---

### 🎯 Target Variable

| Variable | Type | Values | Description |
|---|---|---|---|
| `FALLA_BIN` | binary | `0` = active, `1` = churned | Churn indicator. Derived from subscription status at the observation window close. Core prediction target across all supervised models. |

---

### ⏱️ Engineered: Tenure

| Variable | Type | Source | Description |
|---|---|---|---|
| `meses_transcurridos` | integer | Engineered | Months elapsed between `FECHA_INICIO` and `FECHA_FIN`. Computed as calendar months with day-level adjustment. Clipped at 0. Used as the time variable in survival models and as a profiling indicator in segmentation. Affiliates with `FALLA_BIN = 0` and `meses_transcurridos < 12` are excluded to control for administrative censoring. |

---

### 👤 Demographic & Affiliation Variables

| Variable | Type | Values / Categories | Description |
|---|---|---|---|
| `Sexo_Cd_BIN` | binary | `0` = female, `1` = male | Affiliate biological sex, binarised. |
| `SEGMENTO_EDAD_01_DEPENDIENTE` | binary | `0/1` | Age segment flag: dependent (typically under 18). |
| `SEGMENTO_EDAD_02_ADULTOJOVEN` | binary | `0/1` | Age segment flag: young adult. |
| `SEGMENTO_EDAD_03_PRODUCTIVO` | binary | `0/1` | Age segment flag: working-age adult. |
| `SEGMENTO_EDAD_04_ADULTOMAYOR` | binary | `0/1` | Age segment flag: older adult. |
| `TIPO_AFILIADO_ASEGURADO COLECTIVO` | binary | `0/1` | Affiliation type: collective policyholder (employer-sponsored). |
| `TIPO_AFILIADO_ASEGURADO FAMILIAR` | binary | `0/1` | Affiliation type: family member under a group policy. |
| `TIPO_AFILIADO_TOMADOR FAMILIAR` | binary | `0/1` | Affiliation type: primary family policyholder. |
| `NIVEL_INGRESO` | categorical | Ordinal levels | Socioeconomic income level of the affiliate. Used as ordinal-encoded category in models. |
| `CONDICION_SALUD` | categorical | Health condition codes | Health status classification of the affiliate (e.g. healthy, chronic condition). Ordinal-encoded. |
| `RAMO_FAMILIAR` | binary | `0/1` | Flag indicating the affiliate belongs to a family-plan product (`RAMO = FAMILIAR`). |

---

### 🗺️ Geographic Variables

| Variable | Type | Values | Description |
|---|---|---|---|
| `Regional_Agrupadora_CENTRO` | binary | `0/1` | Affiliate's regional assignment: Central zone. |
| `Regional_Agrupadora_NORTE` | binary | `0/1` | Affiliate's regional assignment: Northern zone. |
| `Regional_Agrupadora_OCCIDENTE` | binary | `0/1` | Affiliate's regional assignment: Western zone. |
| `Regional_Agrupadora_ORIENTE` | binary | `0/1` | Affiliate's regional assignment: Eastern zone. |
| `Regional_Agrupadora_SUR` | binary | `0/1` | Affiliate's regional assignment: Southern zone. |

---

### 📋 Plan & Commercial Variables

| Variable | Type | Values | Description |
|---|---|---|---|
| `PLAN` | categorical | Plan codes (e.g. Plan 3) | PAC product tier subscribed by the affiliate. Ordinal-encoded. |
| `POLIZA_BIN` | binary | `0/1` | Indicates whether the affiliate also holds an additional insurance policy with the EPS. |
| `MARCA_CAC_BIN` | binary | `0/1` | Flag for affiliates marked by the commercial retention team (CAC) — indicates prior intervention history. |
| `FLAG_FRICCION_INICIAL` | binary | `0/1` | Signals affiliates who showed friction or resistance at the initial onboarding stage. Retained despite `_FIN` suffix exclusion rule due to predictive value. |
| `Compania_DIGITAL` | binary | `0/1` | Acquisition/service channel: digital (web, app, WhatsApp). |
| `Compania_PROPIO` | binary | `0/1` | Acquisition/service channel: proprietary (EPS-owned sales force). |
| `Compania_TERCERO` | binary | `0/1` | Acquisition/service channel: third-party broker or intermediary. |

---

### 🏥 Healthcare Network Variables

| Variable | Type | Values | Description |
|---|---|---|---|
| `TIPO_IPS_ALIADA` | binary | `0/1` | Affiliate primarily uses an allied (non-exclusive) IPS network. |
| `TIPO_IPS_EXCLUSIVA` | binary | `0/1` | Affiliate primarily uses the EPS's exclusive IPS network. Key protective factor: associated with **40% lower relative churn risk** (the "Fortress Effect"). |

---

### 📊 Service Utilisation Variables (from `df_consumos`)

PAC = Complementary Plan interactions. PBS = Mandatory Basic Plan interactions.

| Variable | Type | Description |
|---|---|---|
| `Prestaciones_PAC` | integer | Number of PAC healthcare services rendered to the affiliate. |
| `Prestaciones_PBS` | integer | Number of PBS healthcare services rendered to the affiliate. High values associated with chronic conditions. |

---

### 📞 CRM Interaction Variables (from `df_CRM`)

All variables below follow the pattern `{InteractionType}_{Plan}` where Plan is either `PAC` or `PBS`.

| Variable | Type | Description |
|---|---|---|
| `Felicitaciones_PAC` | integer | Number of compliments/positive feedback logged under the PAC. |
| `Felicitaciones_PBS` | integer | Number of compliments/positive feedback logged under the PBS. |
| `Inquietud_PAC` | integer | Number of enquiries (informal questions/concerns) filed under the PAC. |
| `Inquietud_PBS` | integer | Number of enquiries filed under the PBS. |
| `Peticion_PAC` | integer | Number of formal requests (*peticiones*) filed under the PAC. |
| `Peticion_PBS` | integer | Number of formal requests filed under the PBS. |
| `Queja_PAC` | integer | Number of formal complaints (*quejas*) filed under the PAC. Elevated values are associated with higher churn probability. |
| `Queja_PBS` | integer | Number of formal complaints filed under the PBS. |
| `Sugerencia_PAC` | integer | Number of suggestions submitted under the PAC. |
| `Sugerencia_PBS` | integer | Number of suggestions submitted under the PBS. |

---

### ❌ Cancellation Variables (used in cancelled-segment profiling only)

These variables are excluded from the churn prediction feature matrix to prevent target leakage, but are used in the post-hoc profiling of cancelled affiliates.

| Variable | Type | Description |
|---|---|---|
| `GRUPO_CAUSA_CANCELACION_MORA` | binary | Cancellation caused by payment default. |
| `GRUPO_CAUSA_CANCELACION_NO APLICA` | binary | Cancellation reason not applicable or not recorded. |
| `GRUPO_CAUSA_CANCELACION_NO PBS` | binary | Cancellation due to loss of PBS (mandatory plan) affiliation. |
| `GRUPO_CAUSA_CANCELACION_OTRAS CAUSAS` | binary | Cancellation attributed to other causes. |
| `GRUPO_CAUSA_CANCELACION_PETICION DEL CLIENTE` | binary | Voluntary cancellation at the client's explicit request — most analytically relevant category. |

---

## Data Integration Notes

- The three source datasets were merged on `AFILIADO_ID_EPS` and time-aligned to the active subscription period.
- Null values in CRM and consumption tables were imputed as `0` (no interaction recorded), under the assumption that absence of records implies no event occurred.
- The final integrated file (`Merge_Completo_vigencia_total.parquet`) contains one row per affiliate per subscription period, with all features computed over the full active window.
- Affiliates with `FALLA_BIN = 0` and `meses_transcurridos < 12` were excluded from the modelling dataset to control for administrative right-censoring introduced by the EPS's 2024 commercial freeze on new PAC sales.

---

## Variable Exclusions Applied in Modelling

| Exclusion rule | Variables affected | Reason |
|---|---|---|
| `_FIN` suffix pattern | All `*_FIN` columns except `FLAG_FRICCION_INICIAL` | Post-cancellation variables — target leakage |
| `GRUPO_CAUSA_CANCELACION_*` | All cancellation cause dummies | Direct leakage of target |
| Technical identifiers | `AFILIADO_ID_EPS`, `FECHA_INICIO`, `FECHA_FIN`, `meses_transcurridos` | Non-predictive metadata; `meses_transcurridos` used only in survival models |

---

*Part of the [Master's in Business Analytics Portfolio](../README.md) — Pontificia Universidad Católica de Chile*
