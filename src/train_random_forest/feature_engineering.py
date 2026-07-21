"""
Feature-engineering helpers for the Random Forest training step.
"""
import numpy as np
import pandas as pd


def delta_date_feature(dates):
    """
    Given a 2D array containing datetime strings (in a single column),
    return a 2D numpy array with the number of days elapsed between each
    date and the maximum date in the batch.

    Used as an sklearn transformer for the `last_review` column.
    """
    date_sanitized = pd.DataFrame(dates).apply(pd.to_datetime, errors="coerce")
    return date_sanitized.apply(
        lambda d: (d.max() - d).dt.days, axis=0
    ).to_numpy().reshape(-1, 1)
