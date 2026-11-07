---
type: spike
subject: Trademark risk of the name Linux Hello
artifact: spike
status: answered
owner: "@atterdag"
concepts: [name, trademark, one-way-door]
tags: [spike, m0, one-way-door]
sources:
  - https://tmsearch.uspto.gov/search/search-information
  - https://euipo.europa.eu/eSearch/
  - https://www.tmdn.org/tmview/
  - https://branddb.wipo.int/
  - https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general
  - https://api.github.com/search/repositories?q=%22linux+hello%22+in:name,description
  - https://crates.io/api/v1/crates/linux-hello
  - https://rdap.org/domain/linuxhello.org
date: 2026-11-08
issue: https://github.com/LinuxHello/linux-hello/issues/14
---

# Spike: Trademark risk of the name Linux Hello

**This is not legal advice.** It records what public searches returned on one day and what the risk looks like to a non-lawyer. A search of public databases does not replace a clearance search by a trade mark attorney.

## Question

Is 'Linux Hello' likely to conflict with Microsoft's 'Windows Hello' trademark or any registered mark, and what are the fallback names?

## Time box

2 working days proposed. Done in under one day: public searches only.

## Method

All lookups were made on 2026-11-07 (the session clock, UTC) from a browser and `curl`. The files carry 2026-11-08 as the note date.

| Source | Queried? | How |
| :-- | :-- | :-- |
| USPTO Trademark Search, <https://tmsearch.uspto.gov> | **Yes** | Wordmark search in the page: `"windows hello"`, `"linux hello"`, `linuxhello`, `hello`, and the fallback names. Matching is loose (the query `"linux hello"` returned 4,288 records, nearly all for `LINUX` alone), so only the top of each list was read |
| EUIPO eSearch plus, <https://euipo.europa.eu/eSearch/> | **Yes** | Basic search: `windows hello`, `linux hello`, `linuxhello`, and the fallback names |
| TMview, <https://www.tmdn.org/tmview/> | **Yes** | Trade mark name "contains": `windows hello`, `linux hello`, and the fallback names. It reports a total of about 144 million marks across more than 70 offices, and says it is not an official register |
| WIPO Global Brand Database, <https://branddb.wipo.int> | **No** | The site returns a bot-check page (an Altcha challenge) before any search. Bypassing it is not done here. Madrid records for WINDOWS HELLO appear instead through TMview (see Evidence) |
| Microsoft trademark pages | Partly | The general usage page was read. The linked "Microsoft Trademarks" PDF list and the Windows brand guidelines were **not** read |
| GitHub, crates.io, PyPI, npm, AUR, Repology, Flathub, Debian source search | Yes | HTTP API or search endpoints, no login |
| Domain names | Partly | RDAP (<https://rdap.org>) for registration status and dates; no page content could be read for most names |

What was not searched: national offices outside TMview's coverage, common-law (unregistered) use, figurative marks by image, phonetic variants, and the full `hello` result lists (4,969 USPTO records). Fuzzy matches such as `HELLO` plus another word were not reviewed one by one.

Every command or query above is **tested** (browser session and `curl`, 2026-11-07). Nothing was built.

## Blocks

The name is a one-way door: package names, D-Bus names and links depend on it. Blocks the crate and package names ADR ([#22](https://github.com/LinuxHello/linux-hello/issues/22)), the D-Bus name ADR ([#17](https://github.com/LinuxHello/linux-hello/issues/17), already written as [ADR-0012](../adr/0012-dbus-names.md)) and the first release.

## Evidence

All dates are the day looked, 2026-11-07.

### 1. Microsoft's WINDOWS HELLO registrations

| Office | Number | Mark | Classes | Status | Owner | Source |
| :-- | :-- | :-- | :-- | :-- | :-- | :-- |
| USPTO | 86687464 | WINDOWS HELLO (word) | 9, 42 | Live, registered | Microsoft Corporation | <https://tmsearch.uspto.gov/search/search-results> (query `"windows hello"`, first result) |
| EUIPO / WIPO (Madrid) | 1275138 | WINDOWS HELLO (word), designation date 13/07/2015 | 9, 42 | "IR accepted" at EUIPO; Registered at WIPO | Microsoft Corporation | <https://euipo.europa.eu/eSearch/#basic/1+1+1+1/100+100+100+100/windows%20hello>; <https://www.tmdn.org/tmview/#/tmview/results?page=1&pageSize=30&criteria=C&basicSearch=windows%20hello> |
| UKIPO | UK00801275138 | WINDOWS HELLO | 9, 42 | Registered, expires 13/07/2035 | Microsoft Corporation | same TMview page |
| Brazil INPI | 909657688, 909657734 | WINDOWS HELLO | 9; 42 | Registered | Microsoft Corporation | same TMview page |
| Ukraine UANIPIO | m202111069 | windows hello | 9, 42 | Registered, expires 11/05/2031 | Microsoft Corporation | same TMview page |

TMview listed 8 records for `windows hello`; the first five are above, and the remaining three were not read. The goods in the UKIPO record are security software, user authentication software, and password management and protection software for mobile and computing devices (class 9), and online authentication and log-in credential services and SaaS (class 42). These are the same kind of goods as a biometric login tool for Linux.

### 2. Registrations for "Linux Hello" and close variants

| Query | USPTO | EUIPO | TMview |
| :-- | :-- | :-- | :-- |
| `linux hello` | No record containing both words in the first page; the 4,288 hits are `LINUX`-only marks (for example LINUX, reg. to Linus Torvalds, class 9, serial 74560867, live) | 0 results | No rows |
| `linuxhello` | No results | 0 results | not run |
| `windows hello` | see 1 | see 1 | see 1 |

`HELLO` alone returns thousands of unrelated records. The USPTO first page of `hello` showed none in class 9 or 42 for authentication software. The records are not exhaustive and the lists were not read to the end.

### 3. Microsoft usage guidance

<https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general> (read 2026-11-07, no page date shown). It does not mention "Hello". It says third parties may not claim rights in Microsoft brand assets or in brands "confusingly similar" to them, and its Don'ts list includes implying "an affiliation, endorsement, sponsorship, or approval" and filing applications to register terms or logos identical or similar to Microsoft's. The Microsoft trademark list page (<https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks>) links a PDF list that was not read, so whether it names "Windows Hello" separately is unknown.

### 4. Existing uses of "Linux Hello" or "LinuxHello"

Source: <https://api.github.com/search/repositories?q=%22linux+hello%22+in:name,description> (116 results; 2026-11-07) and the `linuxhello` name query (16 results). Repositories that use the name for facial or biometric login on Linux:

| Repository | Stars | Created | Notes |
| :-- | :-- | :-- | :-- |
| `rexackermann/linux-hello` | 11 | 2025-12-07 | "Windows Hello-style facial authentication for Linux" |
| `kennycoder/linux-hello` | 8 | 2026-10-11 | Facial biometrics for Linux; Apache-2.0 |
| `yghlaio/linux-hello` | 3 | not read | Facial authentication "inspired by Windows Hello" |
| `ducvd89/linux-hello-camera` | 2 | not read | Windows Hello-style IR face unlock |
| `Dines97/linux-hello`, `kieran-tanner-9/LinuxHello`, `SzymonPaczos/LinuxHello` | 0 to 3 | not read | Small or empty repositories |

None appears to be a company or a registered mark; whether any is in wide use was not checked. Several describe themselves by reference to "Windows Hello", which is the comparison that makes the name look like a play on Microsoft's.

Package registries and distributions (2026-11-07):

- crates.io: `linux-hello`, `linuxhello` and `linux_hello` return 404 (<https://crates.io/api/v1/crates/linux-hello>). Free today.
- PyPI and npm: the same three names return 404.
- Flathub, AUR, Repology, Debian source search: no package named `linux-hello` or `linuxhello`. The nearest hit is the AUR package `archlinux-hello`, an unrelated documentation tool.
- GitHub organisation `LinuxHello` exists (created 2026-11-01, <https://api.github.com/orgs/LinuxHello>). The user `linux-hello` returns 404.

Domains (RDAP, 2026-11-07, <https://rdap.org/domain/linuxhello.org>):

- `linuxhello.org`: registered 2026-10-23 by someone else; the site returned no content.
- `linuxhello.com`: registered since 2022-08-27; content not read.
- `linuxhello.net`, `.io`, `.dev`, `.app`: RDAP returned 404, which suggests unregistered. RDAP 404 is not a guarantee.

ADR-0012 states the project owns no domain.

### 5. Fallback names

Both were chosen as unrelated to "Hello", "Windows" and "Linux", and searched the same way on 2026-11-07.

| Check | Lychgate | Thresholdkey |
| :-- | :-- | :-- |
| EUIPO eSearch | 0 results | 0 results |
| USPTO | 1 record: LYCHGATE, serial 88553968, class 9, registered to an individual for music CDs and downloadable audio, not software | No results |
| TMview | 4 records: the US one above; UKIPO UK00003325542 (classes 25, 26, clothing and hair accessories); New Zealand (expired shopping mark and a second NZ record, not read) | No rows |
| crates.io, PyPI, npm | 404 on all three | 404 on all three |
| GitHub user or org | `lychgate` is an unused personal account (1 repository, created 2025-01-30); 11 repositories with the word in the name, none with more than 0 stars | `thresholdkey` returns 404 |
| AUR, Flathub, Repology | none | none |
| Domains (RDAP) | `.com`, `.org`, `.net` registered; `.io`, `.dev` 404 | `.com` registered; `.org` 404 |

Notes on the fallbacks: a lychgate is a covered gateway at a churchyard, so the name suggests a gate without naming authentication. "Thresholdkey" is a coined compound; "threshold" also has a meaning in cryptography (threshold signatures), which could cause confusion in search results. The third candidate tried, `Doorward`, was dropped because USPTO serial 90235373 (class 9 and 42 software for landlords, status "Ended") exists and the `doorward` GitHub account and `.com` are taken. `Postern` was dropped because crates.io, PyPI and npm already hold it.

## Answer

**Partly.** The name is not registered by anyone in the databases that could be searched, but it shares its distinctive word, and the same class of goods, with a live Microsoft registration.

- **Exact conflict:** none found. `Linux Hello` and `LinuxHello` returned no records in USPTO, EUIPO or TMview. WIPO could not be queried.
- **Confusion with WINDOWS HELLO:** the shared word is `Hello`, the goods are the same kind (user authentication software, classes 9 and 42), and the form is "operating system + Hello". Several projects already describe themselves as "Windows Hello-style". That pattern can read as a claim of affiliation, which Microsoft's usage page says it does not allow. Risk of a complaint or a refused registration: **moderate**. It is not high because "Linux" differs from "Windows", the project is free software, and no case or enforcement against a similar project was found (none was searched for specifically).
- **Descriptive or dilution problem:** not assessed beyond the above. Whether `Hello` is distinctive for biometric login, or whether WINDOWS HELLO is a famous mark in any jurisdiction, is a legal question this note does not answer.
- **Other uses:** at least four GitHub projects already use "linux-hello" for face login, so the name is not unique in the field, and `linuxhello.org` and `linuxhello.com` are held by others.
- **One-way doors:** the crate name `linux-hello` and its variants are free on crates.io, PyPI and npm today, and the GitHub organisation `LinuxHello` is held. The D-Bus prefix `io.github.LinuxHello.` in ADR-0012 and the `linuxhello-*` crate names are tied to that spelling. A rename after the first release would change the bus name, the Flathub application ID and the crate names, so the decision is cheapest before the first release. This note does not change ADR-0012.

**Fallback names** (both clean in the three databases searched, with the caveats in the Evidence section): **Lychgate** (one unrelated US class 9 mark for music) and **Thresholdkey** (no hits).

**Not legal advice; get a lawyer before the first release if the name matters.** Before any public release, a trade mark attorney should run a full clearance search, including WIPO, and say whether "Linux Hello" is acceptable for authentication software. A publicly visible disclaimer of affiliation with Microsoft is a low-cost step, but whether it is sufficient is a legal question.

Not answered: the WIPO Global Brand Database results; the three unread TMview records for `windows hello`; Microsoft's trademark list PDF; the content of `linuxhello.org` and `linuxhello.com`; use of the name outside GitHub.
