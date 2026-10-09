# Data Import & Excel Extraction Directives

1. **Excel & CSV Logic Integrity**:
   - Never manually hardcode or artificially inject specific courses or professors into seed maps to "fix" an import issue.
   - Always resolve issues at the parser level in `ModeratorDataProvider.importExcelBytes` and `ModeratorDataProvider.importCsvData`:
     - Dynamic header discovery & column index resolution.
     - Dynamic branch resolution from sheet content, filename, and course code prefixes (`EE` -> `EEE`, `EC` -> `ECE`, `CS` -> `CSE`, `ME`/`MCE` -> `MCE`, `CE`/`CVE` -> `CVE`).
     - Dynamic semester tracking across multi-row group headers.
     - Dynamic coordinator extraction, name normalization, and automatic faculty profile generation from the file itself.
2. **Crash & Exception Prevention**:
   - Keep all UI dropdown selections strictly synchronized with items and deduplicated.
   - Use safe type conversions (`(val as num?)?.toDouble() ?? 0.0`) instead of direct `as double` casts.
