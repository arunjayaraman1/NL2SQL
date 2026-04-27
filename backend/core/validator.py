"""
Comprehensive SQL Validation Layer for NL2SQL

Generic, extensible validation system that:
- Detects question intent
- Enhances prompts with hints
- Validates SQL structure
- Auto-fixes common issues

Architecture:
1. Intent Detection - Extract required SQL patterns from question
2. Prompt Enhancement - Add intent-specific hints to prompt
3. Post-Generation Validation - Check SQL structure vs intent
4. Auto-Fix - Apply fixes for common issues
"""

from __future__ import annotations

import re
import logging
from dataclasses import dataclass, field
from typing import Optional

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


INTENT_PATTERNS = {
    "aggregation": {
        "keywords": [
            "count",
            "total",
            "sum",
            "average",
            "avg",
            "how many",
            "number of",
        ],
        "requires": ["GROUP BY"],
        "hint": "- If counting/summing/average by category, use COUNT/SUM/AVG with GROUP BY\n- 'per X', 'each X', 'by X' requires GROUP BY X",
    },
    "ordering": {
        # Removed "first" and "last" — too commonly part of column names ("first name", "last name")
        "keywords": [
            "order by",
            "sorted by",
            "ranked by",
            "highest",
            "lowest",
            "largest",
            "smallest",
            "best",
            "worst",
            "ascending",
            "descending",
        ],
        "requires": ["ORDER BY"],
        "hint": "- If asking for order/rank/sort, include ORDER BY with appropriate column\n- 'top N' requires ORDER BY + LIMIT N",
    },
    "limiting": {
        # Pattern-only: only fire when an explicit number follows top/first/only
        "keywords": [],
        "requires": ["LIMIT"],
        "pattern": r"top\s+\d+|first\s+\d+|only\s+\d+",
        "hint": "- 'top N', 'first N', 'only N' requires LIMIT N",
    },
    "filtering": {
        # Removed "only" and "with" — too common in general English
        "keywords": [
            "where",
            "filter",
            "having",
            "among",
            "matching",
            "whose",
        ],
        "requires": ["WHERE"],
        "hint": "- Use WHERE clause for filtering conditions",
    },
    "joining": {
        # Removed "with" — matches almost every query.  Keep explicit multi-word phrases.
        "keywords": [
            "along with",
            "and their",
            "belonging to",
            "linked to",
            "connected to",
        ],
        "requires": ["JOIN"],
        "hint": "- 'and their X', 'along with X' may require JOIN between tables",
    },
    "comparison": {
        "keywords": [
            "more than",
            "less than",
            "above",
            "below",
            "over",
            "under",
            "greater than",
            "exceeds",
            "higher than",
            "lower than",
        ],
        "requires": ["WHERE comparison"],
        "hint": "- Use comparison operators: >, <, >=, <=, =\n- 'above/over' = >=, 'below/under' = <=",
    },
    "exclusion": {
        # Removed bare "no" — too common.  Keep specific multi-word phrases.
        "keywords": [
            "without",
            "not in",
            "exclude",
            "except",
            "never",
            "who have not",
            "who hasn't",
            "does not have",
            "have no",
        ],
        "requires": ["NOT IN / LEFT JOIN"],
        "hint": "- 'without X', 'never' may require LEFT JOIN + IS NULL or NOT IN subquery",
    },
    "null_handling": {
        "keywords": ["null", "empty", "missing", "no phone", "no email", "no record", "not provided"],
        "requires": ["IS NULL / IS NOT NULL"],
        "hint": "- 'no X', 'without X', 'missing X' requires IS NULL check",
    },
    "date_range": {
        # Removed "from" — matches almost every question ("from each department", etc.)
        "keywords": [
            "before",
            "after",
            "between",
            "since",
            "until",
            "older than",
            "newer than",
            "last week",
            "last month",
            "last year",
            "this year",
        ],
        "requires": ["WHERE date comparison"],
        "hint": "- Use date comparisons: >, <, BETWEEN\n- 'between X and Y' = BETWEEN X AND Y",
    },
    "subquery": {
        "keywords": [
            "more than average",
            "higher than average",
            "above average",
            "below average",
            "who earn more",
            "who make more",
        ],
        "requires": ["Subquery"],
        "hint": "- 'more than average', 'above average' requires subquery: (SELECT AVG(column) FROM table)",
    },
    "case_expression": {
        "keywords": ["label", "categorize", "categorized", "classified", "categorization"],
        "requires": ["CASE expression"],
        "hint": "- Use CASE WHEN for categorization/labeling",
    },
    "distinct": {
        "keywords": ["distinct", "unique values", "without duplicates", "deduplicate"],
        "requires": ["DISTINCT"],
        "hint": "- Use DISTINCT to remove duplicate rows",
    },
}


@dataclass
class ValidationResult:
    sql: str
    is_valid: bool
    issues: list[str] = field(default_factory=list)
    fixes_applied: list[str] = field(default_factory=list)
    detected_intents: list[str] = field(default_factory=list)


def detect_intents(question: str) -> list[str]:
    """
    Detect all SQL intents from the user's question.

    Args:
        question: User's natural language question

    Returns:
        List of detected intent names
    """
    question_lower = question.lower()
    detected = []

    for intent_name, intent_data in INTENT_PATTERNS.items():
        keywords = intent_data.get("keywords", [])
        pattern = intent_data.get("pattern")

        keyword_match = any(kw in question_lower for kw in keywords)
        pattern_match = False

        if pattern:
            pattern_match = bool(re.search(pattern, question_lower))

        if keyword_match or pattern_match:
            detected.append(intent_name)
            logger.debug(
                f"Detected intent: {intent_name} from question: {question[:50]}..."
            )

    logger.info(f"Total intents detected: {len(detected)} - {detected}")
    return detected


def build_intent_hints(question: str) -> str:
    """
    Build hint block for prompt based on detected intents.

    Args:
        question: User's natural language question

    Returns:
        String with intent-specific hints for the prompt
    """
    intents = detect_intents(question)

    if not intents:
        return ""

    hints = ["[IMPORTANT - SQL Requirements based on your question:]"]

    for intent in intents:
        if intent in INTENT_PATTERNS:
            hint = INTENT_PATTERNS[intent].get("hint", "")
            if hint:
                hints.append(hint)

    return "\n".join(hints)


def extract_limit_from_question(question: str) -> Optional[int]:
    """Extract LIMIT value from question if present."""
    patterns = [
        r"top\s+(\d+)",
        r"first\s+(\d+)",
        r"only\s+(\d+)",
        r"last\s+(\d+)",
        r"show\s+(\d+)",
    ]

    for pattern in patterns:
        match = re.search(pattern, question.lower())
        if match:
            return int(match.group(1))

    return None


def extract_order_column_from_question(question: str, sql: str) -> Optional[str]:
    """
    Try to determine which column to order by from the question.

    Args:
        question: User's question
        sql: Generated SQL (to check available columns)

    Returns:
        Column name to order by, or None
    """
    question_lower = question.lower()
    sql_lower = sql.lower()

    order_keywords = {
        "salary": ["salary", "paid", "earn"],
        "name": ["name", "named"],
        "date": ["date", "hire", "created", "added"],
        "count": ["count", "total", "number"],
        "amount": ["amount", "total"],
        "score": ["score", "rating", "performance"],
        "id": ["id", "first", "by default"],
    }

    for column, keywords in order_keywords.items():
        if any(kw in question_lower for kw in keywords):
            if column in sql_lower:
                return column

    return None


class SQLValidator:
    """
    Comprehensive SQL validator with generic checks.

    Validates SQL structure against detected question intent
    and auto-fixes common issues.
    """

    def __init__(self, question: str, sql: str):
        self.question = question
        self.sql = sql.strip()
        self.question_lower = question.lower()
        self.sql_lower = sql.lower()
        self.detected_intents = detect_intents(question)
        self.issues: list[str] = []
        self.fixes_applied: list[str] = []
        self.fixed_sql = self.sql

    def validate(self) -> ValidationResult:
        """
        Run all validation checks.

        Returns:
            ValidationResult with validated SQL and any issues/fixes
        """
        logger.info(f"Starting validation for SQL: {self.sql[:100]}...")

        self._check_ordering()
        self._check_limiting()
        self._check_aggregation()
        self._check_null_handling()
        self._check_join_requirements()

        is_valid = len(self.issues) == 0 and len(self.fixes_applied) == 0

        logger.info(
            f"Validation complete. Valid: {is_valid}, Issues: {len(self.issues)}, Fixes: {len(self.fixes_applied)}"
        )

        return ValidationResult(
            sql=self.fixed_sql,
            is_valid=is_valid,
            issues=self.issues,
            fixes_applied=self.fixes_applied,
            detected_intents=self.detected_intents,
        )

    def _check_ordering(self):
        """Check if ORDER BY is present when needed."""
        needs_order = any(
            kw in self.question_lower for kw in INTENT_PATTERNS["ordering"]["keywords"]
        )

        if needs_order and "order by" not in self.sql_lower:
            self.issues.append(
                "Missing ORDER BY clause (user asked for ordered results)"
            )

            order_column = extract_order_column_from_question(self.question, self.sql)

            if order_column:
                self._add_order_by(order_column)
            else:
                direction = (
                    "DESC"
                    if any(
                        kw in self.question_lower
                        for kw in ["highest", "largest", "top", "best", "most"]
                    )
                    else "ASC"
                )
                self.issues.append(
                    f"Could not auto-fix: unknown order column. Please specify column to order by."
                )

    def _check_limiting(self):
        """Check if LIMIT is present when needed."""
        limit_match = re.search(
            r"top\s+(\d+)|first\s+(\d+)|only\s+(\d+)", self.question_lower
        )

        if limit_match and "limit" not in self.sql_lower:
            limit_value = int(limit_match.group(1))
            self.issues.append(
                f"Missing LIMIT clause (user asked for top/first {limit_value})"
            )
            self._add_limit(limit_value)

    def _check_aggregation(self):
        """Check if GROUP BY is present when using aggregates."""
        has_aggregate = any(
            func in self.sql_lower
            for func in ["count(", "sum(", "avg(", "max(", "min("]
        )

        asks_per = any(
            word in self.question_lower for word in ["per", "each", "by ", "grouped"]
        )

        if has_aggregate and asks_per and "group by" not in self.sql_lower:
            self.issues.append(
                "Missing GROUP BY clause (using aggregate with 'per/each/by')"
            )
            self._add_group_by()

    def _check_null_handling(self):
        """Check for proper NULL handling."""
        has_null_keywords = any(
            kw in self.question_lower
            for kw in ["no ", "without", "null", "empty", "missing"]
        )

        if (
            has_null_keywords
            and "is null" not in self.sql_lower
            and "coalesce" not in self.sql_lower
        ):
            if "where" not in self.sql_lower:
                self.issues.append("May need WHERE clause for null/empty filtering")

    def _check_join_requirements(self):
        """Check if JOINs are needed based on question."""
        has_join_keywords = any(
            kw in self.question_lower
            for kw in ["with their", "and their", "including", "along with"]
        )

        if (
            has_join_keywords
            and " join " not in self.sql_lower
            and " from " in self.sql_lower
        ):
            from_match = re.search(r"from\s+(\w+)", self.sql_lower)
            if from_match and " join " not in self.sql_lower:
                self.issues.append("May need JOIN to connect tables")

    def _add_order_by(self, column: str, direction: str = "DESC"):
        """Add ORDER BY clause to SQL."""
        if " order by " not in self.fixed_sql.lower():
            order_clause = f" ORDER BY {column} {direction}"

            if " limit " in self.fixed_sql.lower():
                self.fixed_sql = self.fixed_sql.lower().replace(
                    " limit ", order_clause + " LIMIT "
                )
            else:
                self.fixed_sql += order_clause

            self.fixes_applied.append(f"Added ORDER BY {column} {direction}")
            logger.info(f"Auto-fixed: Added ORDER BY {column} {direction}")

    def _add_limit(self, limit_value: int):
        """Add LIMIT clause to SQL."""
        if " limit " not in self.fixed_sql.lower():
            self.fixed_sql += f" LIMIT {limit_value}"
            self.fixes_applied.append(f"Added LIMIT {limit_value}")
            logger.info(f"Auto-fixed: Added LIMIT {limit_value}")

    def _add_group_by(self):
        """Add GROUP BY clause (conservative - log issue instead of auto-fix)."""
        self.issues.append(
            "GROUP BY auto-fix skipped: requires column selection - needs manual review"
        )


def validate_sql(sql: str, question: str, auto_fix: bool = True) -> ValidationResult:
    """
    Main entry point for SQL validation.

    Args:
        sql: Generated SQL query
        question: User's original question
        auto_fix: Whether to auto-fix issues (default: True)

    Returns:
        ValidationResult with validated SQL and any issues/fixes
    """
    validator = SQLValidator(question, sql)
    return validator.validate()


def validate_and_enhance_prompt(question: str) -> str:
    """
    Get intent hints for prompt enhancement.

    Args:
        question: User's question

    Returns:
        String with intent hints for the prompt
    """
    return build_intent_hints(question)


if __name__ == "__main__":
    test_questions = [
        "Show top 5 employees by salary",
        "How many employees in each department?",
        "Find active employees in Engineering ordered by salary",
        "List employees with no phone number",
        "What are the highest paid jobs",
    ]

    print("=" * 60)
    print("SQL Validator Test")
    print("=" * 60)

    for q in test_questions:
        intents = detect_intents(q)
        hints = build_intent_hints(q)
        limit = extract_limit_from_question(q)

        print(f"\nQuestion: {q}")
        print(f"Intents: {intents}")
        print(f"Limit: {limit}")
        print(f"Hints:\n{hints}")
        print("-" * 40)
