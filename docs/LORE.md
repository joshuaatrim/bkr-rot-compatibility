# Lore Provenance

This compatibility patch needs lore decisions, but lore decisions must stay
separate from raw data discovery. The raw ROT dump tells us what the installed
Realm of Thrones modules contain. It does not prove whether that content is
canon, ROT-team adaptation, or original compatibility work.

## Provenance Buckets

Use these buckets when documenting title, culture, law, dynasty, language,
shipping, and balance decisions:

| Bucket | Meaning | How to use it |
| --- | --- | --- |
| Raw ROT data | IDs and relationships verified from installed ROT XML/XSLT or live runtime dumps. | Use as the authority for gameplay IDs, load integration, and crash-sensitive references. |
| Canon source | Book/show/source-backed lore. | Use to guide names, rationale, and flavor when it does not conflict with ROT gameplay data. |
| ROT adaptation | Choices made by the Realm of Thrones mod team. | Prefer this over external canon for in-game relationships and geography. |
| BKR-ROT compatibility lore | Original additions made by this patch to satisfy BKR systems. | Clearly label as original compatibility interpretation. |

## Decision Rule

When canon and ROT adaptation conflict, follow ROT for gameplay integration and
document the difference. This module should make Banner Kings Redux feel native
inside Realm of Thrones, not replace Realm of Thrones with a separate canon
model.

When BKR needs data that neither canon nor ROT defines directly, create original
compatibility data conservatively and label it as BKR-ROT compatibility lore.

## Research Table

Use this table shape for durable lore decisions:

| Subject | ROT ID(s) | Raw ROT data | Canon basis | ROT adaptation | Compatibility decision | Confidence | Source notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| _Example_ | _kingdom_or_settlement_id_ | _Verified source file or runtime dump row._ | _Brief cited canon basis._ | _How ROT represents it._ | _What this patch will do._ | _High/Medium/Low_ | _Links, file paths, or unresolved questions._ |

## Practical Guidance

- Do not treat inferred lore as a verified ROT ID relationship.
- Do not overwrite ROT's adaptation with canon solely because canon differs.
- Keep source notes short and link out where possible; do not copy large source
  passages into this repository.
- Mark invented compatibility decisions explicitly as non-canon.
- Revisit low-confidence entries after runtime dumps or in-game testing.

