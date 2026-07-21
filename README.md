# Build an ML Pipeline for Short-Term Rental Prices in NYC

An end-to-end, reusable Machine Learning pipeline for a property management company that estimates the typical price for short-term rental properties in NYC based on similar listings. The pipeline supports **weekly retraining** on new incoming data and is fully orchestrated with **MLflow + Hydra + Weights & Biases**.

## 🔗 Links

- **GitHub Repository:** https://github.com/<your-username>/build-ml-pipeline-for-short-term-rental-prices
- **Weights & Biases Project:** https://wandb.ai/<your-username>/nyc_airbnb
- **Original Starter Repository:** https://github.com/udacity/build-ml-pipeline-for-short-term-rental-prices

> ⚠️ Make your W&B project **public** before submission.

## 📋 Table of Contents
1. [Project Overview](#project-overview)
2. [Environment Setup](#environment-setup)
3. [W&B Login](#wb-login)
4. [Project Structure](#project-structure)
5. [Running the Pipeline](#running-the-pipeline)
6. [Pipeline Steps](#pipeline-steps)
7. [Hyperparameter Optimization](#hyperparameter-optimization)
8. [Selecting the Best Model](#selecting-the-best-model)
9. [Testing the Production Model](#testing-the-production-model)
10. [Releasing the Pipeline](#releasing-the-pipeline)
11. [Training on New Data](#training-on-new-data)

---

## Project Overview

The pipeline covers the full MLOps lifecycle:

`download → basic_cleaning → data_check → data_split → train_random_forest → test_regression_model`

Each step is an independent, reproducible MLflow component, versioned via W&B artifacts.

## Environment Setup

```bash
conda env create -f environment.yml
conda activate nyc_airbnb_dev
```

**Windows users:** Please use WSL for a smoother setup.

## W&B Login

Export your API key in every terminal session:

```bash
export WANDB_API_KEY=<your_api_key>
wandb login $WANDB_API_KEY
```

Get your key from: https://wandb.ai/authorize

## Project Structure

```
.
├── main.py                       # Pipeline orchestrator (Hydra + MLflow)
├── config.yaml                   # All pipeline parameters
├── MLproject                     # Root MLflow project descriptor
├── conda.yml                     # Root conda environment
├── environment.yml               # Dev environment
├── EDA.ipynb                     # Exploratory Data Analysis notebook
├── README.md
├── cookie-mlflow-step/           # Cookiecutter template for new steps
├── components/                   # Pre-built remote components (get_data, train_val_test_split, test_regression_model)
└── src/
    ├── basic_cleaning/           # Cleans raw data → clean_sample.csv
    ├── data_check/               # Deterministic + non-deterministic data tests
    └── train_random_forest/      # Trains + exports Random Forest model
```

## Running the Pipeline

**Full pipeline:**
```bash
mlflow run .
```

**Specific step(s):**
```bash
mlflow run . -P steps=download
mlflow run . -P steps=download,basic_cleaning
```

**Override Hydra parameters:**
```bash
mlflow run . \
  -P steps=download,basic_cleaning \
  -P hydra_options="modeling.random_forest.n_estimators=10 etl.min_price=50"
```

## Pipeline Steps

| Step | Description | Input Artifact | Output Artifact |
|------|-------------|---------------|-----------------|
| `download` | Downloads raw dataset from source | — | `sample.csv` |
| `basic_cleaning` | Removes outliers, drops nulls, filters geo bounds | `sample.csv:latest` | `clean_sample.csv` |
| `data_check` | Runs data quality tests (row count, price range, KL divergence, etc.) | `clean_sample.csv:latest`, `clean_sample.csv:reference` | — |
| `data_split` | Splits into trainval + test sets | `clean_sample.csv:latest` | `trainval_data.csv`, `test_data.csv` |
| `train_random_forest` | Trains RF, tracks metrics, exports model | `trainval_data.csv:latest` | `random_forest_export` |
| `test_regression_model` | Evaluates prod model on test set | `random_forest_export:prod`, `test_data.csv:latest` | — |

## Hyperparameter Optimization

Grid search with Hydra multi-run (`-m`):

```bash
mlflow run . \
  -P steps=train_random_forest \
  -P hydra_options="modeling.max_tfidf_features=10,15,30 modeling.random_forest.max_features=0.1,0.33,0.5,0.75,1 -m"
```

This launches **15 training runs**. Compare them in W&B.

## Selecting the Best Model

1. Go to W&B → **Table view**.
2. Add columns: `ID`, `Job Type`, `max_depth`, `n_estimators`, `mae`, `r2`.
3. Sort by **`mae` ascending**.
4. Open the top run → **Artifacts** → `random_forest_export` → add alias **`prod`**.

> ⚠️ Use a **W&B alias**, not just a tag. The pipeline references `random_forest_export:prod`.

## Testing the Production Model

Run explicitly (not in the default step list):

```bash
mlflow run . -P steps=test_regression_model
```

## Releasing the Pipeline

1. Copy your best hyperparameters into `config.yaml`.
2. Commit + push.
3. Create a GitHub release: **`1.0.0`**.

## Training on New Data

Run from the released version against a new sample:

```bash
mlflow run https://github.com/<your-username>/build-ml-pipeline-for-short-term-rental-prices.git \
  -v 1.0.0 \
  -P hydra_options="etl.sample='sample2.csv'"
```

If it fails on `test_proper_boundaries`, that's expected. Fix `src/basic_cleaning/run.py` to filter NYC lat/long boundaries, release `1.0.1`, and re-run.

## License

MIT — See original repo for license details.

- **Weights & Biases Project:** https://wandb.ai/arindam-b21-accenture/nyc_airbnb_v2
