# Churn Prediction and Permanence Modelling for the Retention of Profitable Clients in a Colombian Health Insurer's Complementary Plan
### Graduation Seminar — Master's in Business Analytics · Pontificia Universidad Católica de Chile
**Defence grade: 7.0 / 7.0 — Máxima Distinción** · 24 March 2026

> **Academic Notice**
>
> This work is the degree capstone of the **Master's in Business Analytics at Pontificia Universidad Católica de Chile (PUC Chile)**, structured across three sequential seminars (*Seminario de Graduación I, II & III*). As the programme is conducted in Spanish at a Chilean institution, the project was developed and documented in **Spanish**. The thesis was defended on **24 March 2026** and received a grade of **7.0 / 7.0 — Máxima Distinción**, the highest distinction in the Chilean academic grading system.
>
> This repository is published solely to document a personal learning and knowledge-building process. It is **not intended for reproduction, redistribution, or commercial use** of any kind. The intellectual property of this work belongs to the members of **Group 11** as its authors. The client organisation is referred to as **EPS ABC** in accordance with a confidentiality agreement. Source data files are not included in this repository.
>
> This was a **collaborative group project** in which all members contributed equally. This repository is published from Katherin Molina's personal academic portfolio; no individual authorship is claimed over any specific component of the work. Co-authors' contributions are fully acknowledged.
>
> **Supervision:** This project was guided and supervised by **Professor Jaime Caiceo** (PUC Chile).
>
> **Acknowledgements:** The authors wish to express their gratitude to **Professor Pablo Marshall**, **Professor Marcos Sepúlveda**, and **Professor Jaime Navon** (PUC Chile) for their academic guidance throughout the Master's programme.

---

## 📌 Executive Summary

A Colombian health insurer (*EPS*) operating complementary health plans (*Planes de Atención Complementaria — PAC*) faced a critical churn problem: an annual cancellation rate of **2.8%** that **quintupled in its highest-value, lowest-claims segments**. Existing retention strategies were entirely reactive — triggered only after customers had already decided to leave.

This project designed and validated an **end-to-end analytical retention system** that:

1. Segments the customer base into behavioural archetypes using unsupervised topology-aware clustering
2. Predicts individual 12-month churn probability using supervised classification
3. Calibrates churn scores for reliable probability estimation
4. Validates model performance with AUC-ROC, Brier Score, and calibration curves — including expected-value financial analysis
5. Generates interpretable outputs and stakeholder reports via a **production-ready R Shiny dashboard**

**Best model (XGBoost):** AUC = **0.86** · Lift@10% = **3.29** · captures **32% of total churn** by intervening on just **10% of the population**

**Financial projection:** Estimated net benefit of **COP $5,732 million/year** · ROI = **302%**

---

## 🏢 Organisational Context

| Item | Detail |
|---|---|
| **Organisation** | EPS ABC (anonymised Colombian health insurer) |
| **Sector** | Health insurance — Complementary Health Plans (PAC) |
| **Country** | Colombia |
| **Total affiliates (EPS)** | ~13.8 million |
| **PAC affiliates** | ~298,000 |
| **PAC market share** | ~30–40% of the Colombian PAC market |
| **Problem** | Reactive churn management; highest-value segments churning 5× the average rate |
| **Data horizon** | Internal: Permanencia, CRM/PQRS, Consumos Médicos |

The PAC operates within the Colombian health system (*SGSSS*) as a voluntary complement to the mandatory *Plan de Beneficios en Salud (PBS)*. It provides faster specialist access, direct referrals, and enhanced comfort — and is exclusively available to contributory-regime affiliates of the same EPS.

---

## 🎯 Objectives

**Primary objective:** Develop an integrated analytical system to identify customer archetypes, predict individual churn probability at 12 months, and model permanence windows — enabling proactive, financially-optimised retention allocation.

**Specific objectives:**
1. **Build unsupervised behavioural segmentation** to characterise customer archetypes based on healthcare consumption patterns, operational friction (PQRS), and contractual stability
2. **Train and compare churn classifiers** (Logistic Regression vs. XGBoost), calibrating the churn score via Platt Scaling or isotonic regression to ensure probabilities accurately reflect real exit risk
3. **Implement survival analysis models** (Kaplan-Meier, Cox, Random Survival Forest) to estimate time-to-churn distributions and identify critical retention windows
4. **Validate model performance** using AUC-ROC, Brier Score, and calibration curves, integrating an expected-value analysis that quantifies potential savings and optimises the retention budget across intervention scenarios
5. **Quantify financial impact through scenario simulation** and generate interpretable visualisations and stakeholder reports highlighting the most influential churn drivers

---

## 🗂️ Dataset & Feature Engineering

Three internal data sources were integrated under the **CRISP-DM** framework:

| Source | Description | Key Variables |
|---|---|---|
| `df_permanencia` | Subscription history and tenure records | Enrollment date, plan type, cancellation flag, tenure months |
| `df_CRM` | Customer relationship & complaints (PQRS) | Complaint volume, resolution time, interaction channels |
| `df_consumos` | Medical consumption patterns | Service utilisation, IPS exclusiva usage, claim frequency |

**Feature engineering highlights:**
- Temporal indicators: tenure brackets, months since last complaint, activity recency
- Behavioural ratios: claim frequency normalised by plan age
- Binary flag: use of *IPS Exclusiva* (proprietary network) — key protective factor
- Sociodemographic variables: age group, stratum, geographic region

---

## 🔬 Methods & Technical Approach

### Phase 1 — Unsupervised Segmentation
Two complementary approaches were tested and compared:

**K-Means** (`A_4_Modelo_de_Segmentacion_Kmeans.ipynb`)
- Classical centroid-based clustering
- Elbow method + silhouette score for k selection
- Interpretable archetypes with clear business labels

**UMAP + HDBSCAN** (`A_5_Modelo_de_Segmentacion_UMAP___HDBSCAN.ipynb`)
- **UMAP**: Non-linear dimensionality reduction preserving topological structure
- **HDBSCAN**: Density-based clustering robust to irregular shapes and noise
- Revealed latent behavioural structures invisible to K-Means
- Superior for detecting the "healthy young volatile" archetype

### Phase 2 — Supervised Churn Prediction
(`A_6_Modelo_de_Regresion_y_XGBoost.ipynb`)

| Model | AUC | Lift@10% | Notes |
|---|---|---|---|
| Logistic Regression | ~0.74 | ~2.1 | Interpretable baseline |
| **XGBoost (optimised)** | **0.86** | **3.29** | Production model |

XGBoost configuration: strategic class-weight tuning, early stopping, SHAP-based feature selection. Captures **32% of all churners** by targeting only the top-risk decile.

### Phase 3 — Survival Analysis
(`A_6_Modelo_de_Regresion_y_XGBoost.ipynb` · section on survival)

Three survival models were implemented to capture the temporal dynamics of churn:

| Model | Purpose |
|---|---|
| **Kaplan-Meier** | Non-parametric survival curves by customer segment |
| **Cox Proportional Hazards** | Semi-parametric hazard estimation with covariate effects |
| **Random Survival Forest (RSF)** | Non-linear survival prediction; handles interactions |

Key finding: critical churn windows concentrate in months **6–18** of the customer lifecycle.

### Phase 4 — Conversational Interface Simulation
(`A_7_Preguntele_al_modelo_ABC_EPS.ipynb`)

A functional simulation of a natural-language query interface for business users. The notebook mimics the experience of querying the trained churn model through plain-language inputs — e.g., *"What is the churn risk of a 35-year-old customer in Bogotá who has not used IPS Exclusiva in 6 months?"* — and returns model-driven responses. No external LLM was connected; the simulation was designed to prototype the interaction flow and validate the concept's business viability before a potential production integration.

### Phase 5 — Financial Simulation
(`A_8_Simulacion_Financiera_EPS_ABC.ipynb`)

Scenario modelling under variable retention effectiveness and budget constraints:
- Top-5%, Top-10%, Top-20% intervention scenarios
- Estimated net benefit: **COP $5,732 million/year**
- ROI: **302%** under conservative assumptions

---

### Phase 6 — Production-Ready Shiny Dashboard
(`APP_Permanencia_PAC.R`)

A fully functional **R Shiny dashboard** built for deployment in the EPS ABC retention team's operational workflow. This is not a prototype — it is a complete, styled, multi-module application ready for production use.

**Five modules:**

| Module | Description |
|---|---|
| **Introduction** | Executive summary, navigation guide, project context |
| **Descriptive Analysis** | Interactive portfolio characterisation with dynamic filters across all demographic, geographic, plan and behavioural variables; population pyramid; cancellation rate overlays |
| **Customer Profiles** | UMAP+HDBSCAN-derived archetypes visualised as interactive pie charts with clickable cluster detail modals; cross-variable behaviour analysis per profile |
| **Churn & Retention** | SHAP variable importance chart; Kaplan-Meier curves by variable; prioritised churn risk table for active affiliates; individual survival curve per affiliate ID; new-affiliate permanence simulator |
| **Financial Impact** | Real-time ROI simulation with configurable LTV, call cost, incentive cost, and agent success rate; profitability curve by number of managed affiliates; sensitivity heatmap (incentive × success rate) |

**Technical highlights:**
- Custom corporate CSS (Barlow font, EPS ABC colour palette) — production-quality UI
- JavaScript input formatters for currency fields
- `ranger` (Random Survival Forest) model loaded at runtime from serialised `.rds` artifact
- `recipes` pipeline for consistent feature preprocessing at inference time
- `arrow` for high-performance Parquet data loading
- `plotly` interactive charts throughout; `DT` interactive tables
- Reactive filter system propagated across all modules

---

## 📊 Key Findings

### Structural Phenomena Discovered

**🔴 The "Health Paradox"**
Young, healthy customers — the most profitable due to low claims — exhibit the highest churn volatility. Paradoxically, good health reduces engagement with plan benefits, weakening retention anchors.

**🏰 The "Fortress Effect"**
Customers who regularly use the insurer's proprietary network (*IPS Exclusiva*) show a **40% lower relative churn risk**. This is the single strongest protective factor identified across all models.

**📅 Critical Retention Windows**
Survival analysis reveals that months **6–18** represent the highest-risk period. Proactive intervention must occur *before* month 6 to be effective.

### Model Performance Summary

```
XGBoost Final Model
─────────────────────────────────────
AUC-ROC:          0.86
Lift @ decile 1:  3.29×
Churn captured:   32% targeting top 10% of population
Financial ROI:    302% (net COP $5,732M/year projected)
```

---

## 🛠️ Tech Stack

| Category | Tools |
|---|---|
| **Languages** | Python 3.x · R |
| **Data manipulation** | pandas, numpy · dplyr, data.table |
| **Machine Learning** | scikit-learn, XGBoost |
| **Survival Analysis** | lifelines, scikit-survival · ranger (RSF), survival |
| **Dimensionality Reduction** | UMAP-learn |
| **Clustering** | HDBSCAN, scikit-learn (K-Means) |
| **Explainability** | SHAP |
| **Visualisation** | matplotlib, seaborn, plotly · plotly (R), ggplot2 |
| **Dashboard / Deployment** | R Shiny · shinydashboard · DT |
| **Feature preprocessing** | recipes (R) |
| **Data format** | Parquet (`.parquet`) via arrow |
| **Conversational simulation** | Custom Python scripting (no external LLM connected) |
| **Framework** | CRISP-DM |

---

## 📁 Repository Structure

```
seminario-graduacion/
│
├── README.md                                      ← This file (English)
│
├── notebooks/
│   ├── A_4_Modelo_de_Segmentacion_Kmeans.ipynb          ← K-Means segmentation
│   ├── A_5_Modelo_de_Segmentacion_UMAP_HDBSCAN.ipynb    ← Topology-aware clustering
│   ├── A_6_Modelo_de_Regresion_y_XGBoost.ipynb          ← Churn prediction + survival
│   ├── A_7_Preguntele_al_modelo_ABC_EPS.ipynb            ← Conversational interface simulation
│   └── A_8_Simulacion_Financiera_EPS_ABC.ipynb           ← Financial scenario simulator
│
├── app/
│   └── APP_Permanencia_PAC.R                             ← Production-ready R Shiny dashboard
│
├── report/
│   └── Informe_Final_Seminario_3_vFinal.pdf              ← Full technical report (Spanish)
│
└── data/
    ├── data_dictionary.md                                ← Variable definitions & provenance
    └── [source data not included — confidentiality agreement]
```

---

## 👥 Team & Contribution

**Group 11 — Master's in Business Analytics 2025**

| Member |
|---|
| Katherin Molina |
| Joan Martinez |
| Sebastián Cornejo |
| Andrés Ospina |

> *This repository is published from Katherin Molina's personal academic portfolio. Co-authors' contributions are fully acknowledged.*

---

## 🔭 Open Questions & Further Work

This project surfaced several methodological tensions and empirical puzzles worth pursuing further:

- **The "Health Paradox" demands a causal lens.** Observing that low-utilisation customers churn more is descriptively interesting — but understanding *why* requires moving beyond predictive modelling toward causal inference. Does low utilisation *cause* disengagement, or is it a proxy for a third driver (e.g. income shock, employer plan change)? Instrumental variable or difference-in-differences designs on longitudinal data could test this.

- **Survival model calibration under administrative censoring.** The dataset exhibits heavy right-censoring due to the EPS's 2024 commercial freeze on new PAC sales. Standard Cox assumptions may not hold; testing accelerated failure time (AFT) models and comparing calibration curves against RSF under this specific censoring mechanism would be a natural extension.

- **Generalisability across Latin American health systems.** The structural phenomena identified here — IPS network lock-in as a retention anchor, lifecycle volatility in young low-claim segments — may be specific to the Colombian PAC market structure or may generalise to analogous voluntary health products in Peru, Mexico, or Brazil. A multi-market replication study would be of significant applied value.

- **Conversational interface: from simulation to production.** The query interface (Notebook A_7) was implemented as a scripted simulation to prototype the interaction flow and validate business viability. The natural next step is a formal integration with an LLM — and a subsequent evaluation measuring decision quality improvements among non-technical retention managers using the interface versus baseline spreadsheet workflows. This sits at the intersection of HCI and applied business analytics.

---

## 📚 Methodological Framework

The project followed **CRISP-DM** (Cross-Industry Standard Process for Data Mining):

```
Business Understanding → Data Understanding → Data Preparation
→ Modelling → Evaluation → Deployment (prototype)
```

All stages are documented in the full report (`Informe_Final_Seminario_3_vFinal.pdf`).

---

## 🗃️ Data Dictionary

Source data files are not included in this repository in compliance with the confidentiality agreement with the client. The full variable reference is available in [`data/data_dictionary.md`](./data/data_dictionary.md).

A summary of the three integrated datasets and their variable groups:

| Dataset | Variable groups |
|---|---|
| `df_permanencia` | Identifiers · dates · tenure (`meses_transcurridos`) · target (`FALLA_BIN`) · plan & commercial flags |
| `df_CRM` | PQRS interaction counts by type and network (PAC / PBS): complaints, requests, enquiries, suggestions, compliments |
| `df_consumos` | Service utilisation counts (PAC / PBS) · IPS network type (`TIPO_IPS_EXCLUSIVA`, `TIPO_IPS_ALIADA`) |

**Engineered features include:** age-segment binary flags · geographic region dummies · affiliation type dummies · cancellation cause dummies (profiling only, excluded from prediction to prevent leakage) · `FLAG_FRICCION_INICIAL`.

**Key variable:** `TIPO_IPS_EXCLUSIVA` — use of the EPS's proprietary network — identified as the single strongest protective factor, associated with a **40% reduction in relative churn risk** (the "Fortress Effect").

---

*Part of the [Master's in Business Analytics Portfolio](../README.md) — Pontificia Universidad Católica de Chile*

## 📄 Paper

This repository accompanies the research paper:

**A Multi-Layer Analytical Framework for Customer Retention in Voluntary Health Insurance**

The study proposes an integrated approach combining clustering, explainable machine learning, survival analysis, and financial simulation to address customer churn.

📄 Preprint available at:  
https://doi.org/10.5281/zenodo.19815868
