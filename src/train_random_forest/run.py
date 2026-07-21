#!/usr/bin/env python
"""
Train a Random Forest regressor on the NYC Airbnb dataset.

Pipeline overview:
    1. Download trainval artifact from W&B.
    2. Split into train/val (optionally stratified).
    3. Build an sklearn ColumnTransformer that handles:
        - ordinal room_type
        - one-hot neighbourhood_group
        - TF-IDF on the "name" column
        - impute + delta-days on "last_review"
        - impute + passthrough on numeric columns
    4. Fit a RandomForestRegressor.
    5. Score on validation set (MAE, R2) and log to W&B.
    6. Export the fitted pipeline via mlflow.sklearn and log as a W&B artifact.
"""
import argparse
import itertools
import json
import logging
import os
import shutil

import matplotlib.pyplot as plt
import mlflow
import numpy as np
import pandas as pd
import wandb
from mlflow.models import infer_signature
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.impute import SimpleImputer
from sklearn.metrics import mean_absolute_error, r2_score
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline, make_pipeline
from sklearn.preprocessing import FunctionTransformer, OneHotEncoder, OrdinalEncoder

from feature_engineering import delta_date_feature

logging.basicConfig(level=logging.INFO, format="%(asctime)-15s %(message)s")
logger = logging.getLogger()


def go(args):
    run = wandb.init(job_type="train_random_forest")
    run.config.update(args)

    # ------------------------------------------------------------------
    # 1. Load config & data
    # ------------------------------------------------------------------
    with open(args.rf_config) as fp:
        rf_config = json.load(fp)
    run.config.update(rf_config)

    trainval_local_path = run.use_artifact(args.trainval_artifact).file()
    X = pd.read_csv(trainval_local_path)
    y = X.pop("price")

    logger.info(
        "Loaded trainval dataset with %s rows and %s columns", *X.shape
    )

    # ------------------------------------------------------------------
    # 2. Train / validation split
    # ------------------------------------------------------------------
    stratify = X[args.stratify_by] if args.stratify_by != "none" else None

    X_train, X_val, y_train, y_val = train_test_split(
        X,
        y,
        test_size=args.val_size,
        stratify=stratify,
        random_state=args.random_seed,
    )

    logger.info("Preparing sklearn pipeline")
    sk_pipe, processed_features = get_inference_pipeline(rf_config, args.max_tfidf_features)

    # ------------------------------------------------------------------
    # 3. Fit pipeline
    # ------------------------------------------------------------------
    logger.info("Fitting the Random Forest pipeline")
    sk_pipe.fit(X_train, y_train)

    # ------------------------------------------------------------------
    # 4. Evaluate
    # ------------------------------------------------------------------
    logger.info("Scoring on validation set")
    y_pred = sk_pipe.predict(X_val)

    r_squared = r2_score(y_val, y_pred)
    mae = mean_absolute_error(y_val, y_pred)

    logger.info("Validation R2  : %s", r_squared)
    logger.info("Validation MAE : %s", mae)

    run.summary["r2"] = r_squared
    run.summary["mae"] = mae

    # Feature importance plot
    fig_feat_imp = plot_feature_importance(sk_pipe, processed_features)
    run.log({"feature_importance": wandb.Image(fig_feat_imp)})

    # ------------------------------------------------------------------
    # 5. Export the model with MLflow
    # ------------------------------------------------------------------
    if os.path.isdir("random_forest_dir"):
        shutil.rmtree("random_forest_dir")

    signature = infer_signature(X_val, y_pred)

    mlflow.sklearn.save_model(
        sk_pipe,
        path="random_forest_dir",
        serialization_format=mlflow.sklearn.SERIALIZATION_FORMAT_CLOUDPICKLE,
        signature=signature,
        input_example=X_val.iloc[:2],
    )

    artifact = wandb.Artifact(
        args.output_artifact,
        type="model_export",
        description="Random Forest pipeline export",
        metadata=rf_config,
    )
    artifact.add_dir("random_forest_dir")
    run.log_artifact(artifact)
    artifact.wait()

    run.finish()


def plot_feature_importance(pipe, feat_names):
    """Bar plot of feature importances from the fitted Random Forest."""
    feat_imp = pipe["random_forest"].feature_importances_[: len(feat_names) - 1]
    nlp_importance = sum(pipe["random_forest"].feature_importances_[len(feat_names) - 1 :])
    feat_imp = np.append(feat_imp, nlp_importance)

    fig_feat_imp, sub_feat_imp = plt.subplots(figsize=(10, 10))
    idx = np.argsort(feat_imp)[::-1]
    sub_feat_imp.bar(range(feat_imp.shape[0]), feat_imp[idx], color="r", align="center")
    _ = sub_feat_imp.set_xticks(range(feat_imp.shape[0]))
    _ = sub_feat_imp.set_xticklabels(np.array(feat_names)[idx], rotation=90)
    fig_feat_imp.tight_layout()
    return fig_feat_imp


def get_inference_pipeline(rf_config, max_tfidf_features):
    # ------------------------------------------------------------------
    # Categorical, ordinal features
    # ------------------------------------------------------------------
    ordinal_categorical = ["room_type"]
    non_ordinal_categorical = ["neighbourhood_group"]

    ordinal_categorical_preproc = OrdinalEncoder()

    non_ordinal_categorical_preproc = make_pipeline(
        SimpleImputer(strategy="most_frequent"),
        OneHotEncoder(handle_unknown="ignore"),
    )

    # ------------------------------------------------------------------
    # Numeric features
    # ------------------------------------------------------------------
    zero_imputed = [
        "minimum_nights",
        "number_of_reviews",
        "reviews_per_month",
        "calculated_host_listings_count",
        "availability_365",
        "longitude",
        "latitude",
    ]
    zero_imputer = SimpleImputer(strategy="constant", fill_value=0)

    # ------------------------------------------------------------------
    # last_review → days since most recent review
    # ------------------------------------------------------------------
    date_imputer = make_pipeline(
        SimpleImputer(strategy="constant", fill_value="2010-01-01"),
        FunctionTransformer(delta_date_feature, check_inverse=False, validate=False),
    )

    # ------------------------------------------------------------------
    # TF-IDF on the listing name
    # ------------------------------------------------------------------
    reshape_to_1d = FunctionTransformer(np.reshape, kw_args={"newshape": -1})
    name_tfidf = make_pipeline(
        SimpleImputer(strategy="constant", fill_value=""),
        reshape_to_1d,
        TfidfVectorizer(
            binary=False,
            max_features=max_tfidf_features,
            stop_words="english",
        ),
    )

    # ------------------------------------------------------------------
    # Combine all preprocessors
    # ------------------------------------------------------------------
    preprocessor = ColumnTransformer(
        transformers=[
            ("ordinal_cat", ordinal_categorical_preproc, ordinal_categorical),
            ("non_ordinal_cat", non_ordinal_categorical_preproc, non_ordinal_categorical),
            ("impute_zero", zero_imputer, zero_imputed),
            ("transform_date", date_imputer, ["last_review"]),
            ("transform_name", name_tfidf, ["name"]),
        ],
        remainder="drop",
    )

    processed_features = (
        ordinal_categorical + non_ordinal_categorical + zero_imputed + ["last_review", "name"]
    )

    # ------------------------------------------------------------------
    # Random Forest
    # ------------------------------------------------------------------
    random_forest = RandomForestRegressor(**rf_config)

    sk_pipe = Pipeline(
        steps=[
            ("preprocessor", preprocessor),
            ("random_forest", random_forest),
        ]
    )

    return sk_pipe, processed_features


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="Train a Random Forest regressor")

    parser.add_argument("--trainval_artifact", type=str, required=True,
                        help="Train + validation dataset artifact from W&B")
    parser.add_argument("--val_size", type=float, required=True,
                        help="Fraction of the trainval set held out for validation")
    parser.add_argument("--random_seed", type=int, default=42,
                        help="Random seed for reproducibility")
    parser.add_argument("--stratify_by", type=str, default="none",
                        help="Column used to stratify the train/val split ('none' to disable)")
    parser.add_argument("--rf_config", type=str, required=True,
                        help="Path to a JSON file with the Random Forest hyperparameters")
    parser.add_argument("--max_tfidf_features", type=int, required=True,
                        help="Maximum number of TF-IDF features to extract from the 'name' column")
    parser.add_argument("--output_artifact", type=str, required=True,
                        help="Name for the exported model artifact")

    args = parser.parse_args()

    go(args)
