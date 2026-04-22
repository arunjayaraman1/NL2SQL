import unittest
import sys
from types import SimpleNamespace

sys.modules.setdefault(
    "psycopg2",
    SimpleNamespace(
        connect=lambda *args, **kwargs: None,
        extensions=SimpleNamespace(connection=object),
        sql=SimpleNamespace(SQL=lambda x: x, Identifier=lambda x: x, Composed=object),
    ),
)

from backend.core.nl2sql_pipeline import _should_enable_jsonb_querying


class Nl2SqlJsonbAutodetectTests(unittest.TestCase):
    def test_returns_false_when_profile_missing(self):
        self.assertFalse(_should_enable_jsonb_querying(None))

    def test_returns_false_when_no_json_columns(self):
        profile_cache = SimpleNamespace(
            tables={
                "public.employees": SimpleNamespace(
                    columns={
                        "id": SimpleNamespace(data_type="integer"),
                        "name": SimpleNamespace(data_type="character varying"),
                    }
                )
            }
        )
        self.assertFalse(_should_enable_jsonb_querying(profile_cache))

    def test_returns_true_when_jsonb_column_exists(self):
        profile_cache = SimpleNamespace(
            tables={
                "public.events": SimpleNamespace(
                    columns={
                        "payload": SimpleNamespace(data_type="jsonb"),
                    }
                )
            }
        )
        self.assertTrue(_should_enable_jsonb_querying(profile_cache))


if __name__ == "__main__":
    unittest.main()
