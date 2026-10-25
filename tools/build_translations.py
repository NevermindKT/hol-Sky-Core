"""Build Godot PO translations from UTF-8 CSV catalogs (no engine import needed)."""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("uk", "en", "ru")


def build():
    messages = {locale: {} for locale in LOCALES}
    for path in sorted((ROOT / "localization" / "catalogs").glob("*.csv")):
        with path.open(encoding="utf-8", newline="") as stream:
            for row in csv.DictReader(stream):
                key = row["source"]
                for locale in LOCALES:
                    value = row[locale]
                    if not value:
                        raise ValueError(f"{path}: missing {locale}: {key!r}")
                    previous = messages[locale].get(key)
                    if previous is not None and previous != value:
                        raise ValueError(f"Conflicting {locale} translation: {key!r}")
                    messages[locale][key] = value
    for locale, entries in messages.items():
        quote = lambda value: json.dumps(value, ensure_ascii=False)
        lines = ['msgid ""', 'msgstr ""',
                 quote(f'Language: {locale}\n'),
                 quote('Content-Type: text/plain; charset=UTF-8\n'), '']
        for key, value in sorted(entries.items()):
            lines += [f'msgid {quote(key)}', f'msgstr {quote(value)}', '']
        (ROOT / "localization" / f"{locale}.po").write_text('\n'.join(lines), encoding="utf-8")
    print(f"Built {len(messages['uk'])} messages for {', '.join(LOCALES)}")


if __name__ == "__main__":
    build()
