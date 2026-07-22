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

    logger.info("Downloading artifact %s", args.input_artifact)
    artifact_local_path = run.use_artifact(args.input_artifact).file()

    df = pd.read_csv(artifact_local_path)
    logger.info("Loaded raw data with %s rows and %s columns", *df.shape)

    df = df.drop_duplicates().reset_index(drop=True)
    df = df.dropna(subset=["price"])

    logger.info("Filtering prices between %s and %s", args.min_price, args.max_price)
    idx = df["price"].between(args.min_price, args.max_price)
    df = df[idx].copy()

    # Filter rows outside NYC geographic boundaries
    logger.info("Filtering rows outside NYC geographic boundaries")
    idx = df["longitude"].between(-74.25, -73.50) & df["latitude"].between(40.5, 41.2)
    df = df[idx].copy()

    df["last_review"] = pd.to_datetime(df["last_review"], errors="coerce")

    logger.info("Cleaned data has %s rows and %s columns", *df.shape)

    df.to_csv("clean_sample.csv", index=False)

    logger.info("Uploading %s to Weights & Biases", args.output_artifact)
    artifact = wandb.Artifact(
        args.output_artifact,
        type=args.output_type,
        description=args.output_description,
    )
    artifact.add_file("clean_sample.csv")
    run.log_artifact(artifact)
    artifact.wait()

    run.finish()


if __name__ == "__main__":

    parser = argparse.ArgumentParser(description="A very basic data cleaning step")

    parser.add_argument("--input_artifact", type=str, required=True,
                        help="Fully-qualified name of the input W&B artifact")
    parser.add_argument("--output_artifact", type=str, required=True,
                        help="Name of the output artifact produced by this step")
    parser.add_argument("--output_type", type=str, required=True,
                        help="Type of the output artifact")
    parser.add_argument("--output_description", type=str, required=True,
                        help="Description of the output artifact")
    parser.add_argument("--min_price", type=float, required=True,
                        help="Minimum price to keep")
    parser.add_argument("--max_price", type=float, required=True,
                        help="Maximum price to keep")

    args = parser.parse_args()
    go(args)
