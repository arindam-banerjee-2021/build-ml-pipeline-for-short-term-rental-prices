"""
Deterministic and non-deterministic data quality tests for the cleaned dataset.

These tests are executed by the `data_check` pipeline step and are also
reusable in CI or local development.
"""
import numpy as np
import pandas as pd
import scipy.stats


def test_column_presence_and_type(data: pd.DataFrame):
    """The cleaned dataset must contain the expected columns with expected dtypes."""

    required_columns = {
        "name": pd.api.types.is_object_dtype,
        "host_name": pd.api.types.is_object_dtype,
        "neighbourhood_group": pd.api.types.is_object_dtype,
        "neighbourhood": pd.api.types.is_object_dtype,
        "room_type": pd.api.types.is_object_dtype,
        "last_review": pd.api.types.is_datetime64_any_dtype,
        "id": pd.api.types.is_integer_dtype,
        "host_id": pd.api.types.is_integer_dtype,
        "price": pd.api.types.is_numeric_dtype,
        "minimum_nights": pd.api.types.is_integer_dtype,
        "number_of_reviews": pd.api.types.is_integer_dtype,
        "reviews_per_month": pd.api.types.is_float_dtype,
        "calculated_host_listings_count": pd.api.types.is_integer_dtype,
        "availability_365": pd.api.types.is_integer_dtype,
        "latitude": pd.api.types.is_float_dtype,
        "longitude": pd.api.types.is_float_dtype,
    }

    # Convert last_review if present (CSV round-trip may store as string)
    if "last_review" in data.columns:
        data["last_review"] = pd.to_datetime(data["last_review"], errors="coerce")

    assert set(data.columns.values).issuperset(set(required_columns.keys())), (
        f"Missing columns: {set(required_columns.keys()) - set(data.columns.values)}"
    )

    for col_name, format_verification_funct in required_columns.items():
        assert format_verification_funct(data[col_name]), (
            f"Column {col_name} failed test {format_verification_funct}"
        )


def test_neighborhood_names(data: pd.DataFrame):
    """The dataset should contain exactly the five NYC boroughs."""

    known_names = ["Bronx", "Brooklyn", "Manhattan", "Queens", "Staten Island"]

    neigh = set(data["neighbourhood_group"].unique())

    # Unordered check
    assert set(known_names) == set(neigh)


def test_proper_boundaries(data: pd.DataFrame):
    """Every row must fall within the geographic bounds of New York City."""
    idx = data["longitude"].between(-74.25, -73.50) & data["latitude"].between(40.5, 41.2)

    assert np.sum(~idx) == 0


def test_similar_neigh_distrib(
    data: pd.DataFrame, ref_data: pd.DataFrame, kl_threshold: float
):
    """
    KL-divergence based drift test: the distribution of neighbourhood_group in the
    new data should not diverge from the reference by more than `kl_threshold`.
    """
    dist1 = data["neighbourhood_group"].value_counts().sort_index()
    dist2 = ref_data["neighbourhood_group"].value_counts().sort_index()

    assert scipy.stats.entropy(dist1, dist2, base=2) < kl_threshold


def test_row_count(data: pd.DataFrame):
    """Ensure the dataset size is reasonable (guard against catastrophic pipeline errors)."""
    assert 15000 < data.shape[0] < 1000000


def test_price_range(data: pd.DataFrame, min_price: float, max_price: float):
    """All prices must fall within the configured min_price / max_price range."""
    assert data["price"].between(min_price, max_price).all()
