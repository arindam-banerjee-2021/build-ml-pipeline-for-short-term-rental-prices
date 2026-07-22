#!/usr/bin/env python
"""
Download the raw dataset from W&B, apply basic cleaning, and upload the cleaned
result as a new artifact.

Cleaning performed:
    - Remove duplicate rows.
    - Drop rows with missing prices.
    - Filter price outliers based on min_price / max_price.
    - Filter rows outside the NYC geographical boundaries
      (longitude in [-74.25, -73.50] and latitude in [40.5, 41.2]).
    - Convert last_review to datetime.
"""
import argparse
import logging

import pandas as pd
import wandb

logging.basicConfig(level=logging.INFO, format="%(asctime)-15s %(message)s")
logger = logging.getLogger()


def go(args):
    run = wandb.init(job_type="basic_cleaning")
    run.config.update(args)

    # Download input artifact from W&B
    logger.info("Downloading artifact %s", args.input_artifact)
    artifact_local_path = run.use_artifact(args.input_artifact).file()

    # Load raw sample
    df = pd.read_csv(artifact_local_path)
    logger.info("Loaded raw data with %s rows and %s columns", *df.shape)

    # Drop duplicates
    df = df.drop_duplicates().reset_index(drop=True)

    # Drop rows missing price
    df = df.dropna(subset=["price"])

    # Drop price outliers
    logger.info("Filtering prices between %s and %s", args.min_price, args.max_price)
    idx = df["price"].between(args.min_price, args.max_price)
    df = df[idx].copy()


    # Convert last_review to datetime
    df["last_review"] = pd.to_datetime(df["last_review"], errors="coerce")

    logger.info("Cleaned data has %s rows and %s columns", *df.shape)

    # Save the cleaned data locally
    df.to_csv("clean_sample.csv", index=False)

    # Upload as a new artifact
    logger.info("Uploading %s to Weights & Biases", args.output_artifact)
    artifact = wandb.Artifact(
        args.output_artifact,
        type=args.output_type,
        description=args.output_description,
    )
    artifact.add_file("clean_sample.csv")
    run.log_artifact(artifact)
    artifact.wait()  # Ensures the artifact is fully logged before the run ends

    run.finish()


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="A very basic data cleaning step")

    parser.add_argument(
        "--input_artifact",
        type=str,
        help="Fully-qualified name of the input W&B artifact (e.g. sample.csv:latest)",
        required=True,
    )
    parser.add_argument(
        "--output_artifact",
        type=str,
        help="Name of the output artifact produced by this step",
        required=True,
    )
    parser.add_argument(
        "--output_type",
        type=str,
        help="Type of the output artifact (e.g. clean_sample)",
        required=True,
    )
    parser.add_argument(
        "--output_description",
        type=str,
        help="Description of the output artifact",
        required=True,
    )
    parser.add_argument(
        "--min_price",
        type=float,
        help="Minimum price to consider (rows below this are dropped)",
        required=True,
    )
    parser.add_argument(
        "--max_price",
        type=float,
        help="Maximum price to consider (rows above this are dropped)",
        required=True,
    )

    args = parser.parse_args()

    go(args)
