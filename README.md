# SiteIQ API Clients

API clients for the **DFS Site-IQ Tickets External API** in two languages:

| Module | Language | Folder |
|--------|----------|--------|
| **POSH-SiteIQ** | PowerShell 5.1 / 7+ | [`POSH-SiteIQ/`](POSH-SiteIQ/) |
| **pySiteIQ** | Python 3.9+ | [`pySiteIQ/`](pySiteIQ/) |

Example scripts for each live in [`POSH-Examples/`](POSH-Examples/) and [`pyExamples/`](pyExamples/).

Interactive API documentation (Swagger UI) is in [`docs/index.html`](docs/index.html) — open it in any browser, no server required.

**API base URL:** `https://dfs.site-iq.com`

---

## Table of Contents

1. [REST API Reference](#rest-api-reference)
   - [POST /api/web/auth/token](#post-apiwebauthtoken)
   - [GET /api/external/ticket](#get-apiexternalticket)
2. [Data Structures](#data-structures)
   - [Ticket](#ticket-object)
   - [Alert](#alert-object)
3. [API Documentation (Swagger UI)](#api-documentation-swagger-ui)
4. [POSH-SiteIQ — PowerShell Module](#posh-siteiq--powershell-module)
   - [Installation](#installation)
   - [Credential Storage](#credential-storage)
   - [Cmdlet Reference](#cmdlet-reference)
   - [Examples](#examples)
5. [pySiteIQ — Python Module](#pysiteiq--python-module)
   - [Installation](#installation-1)
   - [Credential Storage](#credential-storage-1)
   - [API Reference](#api-reference)
   - [Examples](#examples-1)

---

## REST API Reference

Both clients wrap the same two HTTP endpoints.

### POST /api/web/auth/token

Exchanges email + password for a bearer token. Every other API call requires this token in its `Authorization` header.

**Request**

```
POST https://dfs.site-iq.com/api/web/auth/token
Content-Type: application/json
```

```json
{
  "email": "user@example.com",
  "password": "ExamplePass123"
}
```

| Field      | Type   | Required | Description               |
|------------|--------|----------|---------------------------|
| `email`    | string | Yes      | Your Site-IQ account email |
| `password` | string | Yes      | Your Site-IQ password     |

**Response — 200 OK**

```json
{ "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." }
```

| Field   | Type   | Description                                 |
|---------|--------|---------------------------------------------|
| `token` | string | Bearer token for use in subsequent requests |

**Error Responses**

| Code | Meaning                          |
|------|----------------------------------|
| 401  | Invalid credentials              |
| 403  | Account does not have API access |
| 500  | Server error                     |

### GET /api/external/ticket

Returns tickets for all sites your account has access to. Supports filtering by status, date range or delta timestamp, and pagination.

**Request**

```
GET https://dfs.site-iq.com/api/external/ticket?{parameters}
Authorization: Bearer {token}
Accept: */*
```

**Query Parameters**

| Parameter    | Type   | Required | Default      | Description |
|--------------|--------|----------|--------------|-------------|
| `status`     | string | No       | `InProgress` | `InProgress`, `Closed`, `Pending Closed`, `Dispatch`, or `All` |
| `startDate`  | string | No       | 30 days ago  | `YYYY-MM-DD`. Ignored when `delta` is supplied. |
| `endDate`    | string | No       | Today        | `YYYY-MM-DD`. Ignored when `delta` is supplied. |
| `delta`      | number | No       | —            | Unix epoch (seconds). Returns tickets modified **after** this timestamp. Overrides date range. |
| `pageLimit`  | number | No       | `1000`       | Tickets per page, 1–1000. |
| `pageOffset` | number | No       | `0`          | Zero-based page offset. |

**Status values**

| Value            | Description                             |
|------------------|-----------------------------------------|
| `InProgress`     | Tickets currently open and being worked |
| `Closed`         | Tickets that have been resolved         |
| `Pending Closed` | Tickets awaiting final closure          |
| `Dispatch`       | Tickets in dispatch queue               |
| `All`            | All statuses combined                   |

The default date window is the last 30 days. `delta` entirely replaces the date-range logic and is useful for scheduled sync jobs. The API returns at most 1000 tickets per call — increment `pageOffset` by `pageLimit` until a response returns fewer records than `pageLimit`. Both clients handle this automatically with `-All` (PowerShell) or `all_pages=True` (Python).

**Response — 200 OK**

An array of [Ticket](#ticket-object) objects:

```json
[
  {
    "ticketID": 12345,
    "ticketOpenTimestamp": "2025-08-05 11:48:19",
    "siteID": "123456",
    "siteName": "Trial #376",
    "companyName": "Demo Company",
    "address": "123 Main St, City, ST",
    "integrationID1": "Id1",
    "integrationID2": "Id2",
    "integrationID3": "Id3",
    "warrantyDate": "2025-09-29",
    "warrantyStatus": "In",
    "dispenser": "9/10",
    "ticketStatus": "open",
    "component": "Printer",
    "alerts": [
      {
        "error": "communication error",
        "fuelingPosition": 9,
        "alertOpenTimestamp": "2025-08-05 11:42:08",
        "alertCloseTimestamp": null
      }
    ]
  }
]
```

**Error Responses**

| Code | Meaning                                          |
|------|--------------------------------------------------|
| 400  | Bad request — typically an invalid date range    |
| 401  | Missing or expired bearer token                  |
| 403  | Account lacks permission to access this resource |
| 500  | Server error                                     |

---

## Data Structures

### Ticket Object

| Property              | Type         | Nullable | Description |
|-----------------------|--------------|----------|-------------|
| `ticketID`            | number       | No       | Unique ticket identifier |
| `ticketOpenTimestamp` | string       | No       | When the ticket opened — `YYYY-MM-DD HH:MM:SS` |
| `siteID`              | string       | No       | Internal site identifier |
| `siteName`            | string       | No       | Human-readable site name |
| `companyName`         | string       | No       | Company that owns the site |
| `address`             | string       | No       | Physical address of the site |
| `integrationID1`      | string       | Yes      | External system link (slot 1) |
| `integrationID2`      | string       | Yes      | External system link (slot 2) |
| `integrationID3`      | string       | Yes      | External system link (slot 3) |
| `warrantyDate`        | string       | Yes      | Warranty expiry — `YYYY-MM-DD`. Null if no warranty. |
| `warrantyStatus`      | string       | No       | `In` (under warranty) or `Out` |
| `dispenser`           | string       | Yes      | Dispensers involved, e.g. `9/10` |
| `ticketStatus`        | string       | No       | Current status |
| `component`           | string       | No       | Hardware component, e.g. `Printer`, `POS` |
| `alerts`              | array[Alert] | No       | Fault conditions that make up this ticket |

`integrationID1/2/3` are free-form fields for linking tickets to external work orders, asset IDs, or other systems. `warrantyDate` and `warrantyStatus` refer to the component warranty.

### Alert Object

| Property              | Type   | Nullable | Description |
|-----------------------|--------|----------|-------------|
| `error`               | string | No       | Fault description, e.g. `communication error` |
| `fuelingPosition`     | number | Yes      | Fueling point that generated the alert. Null for component-level faults. |
| `alertOpenTimestamp`  | string | No       | When the alert was first detected — `YYYY-MM-DD HH:MM:SS` |
| `alertCloseTimestamp` | string | Yes      | When the alert was resolved. `null` means still active. |

`alertCloseTimestamp` being `null` does not necessarily mean the parent ticket is still open — a ticket can be closed with unresolved alerts if the site was serviced by other means.

---

## API Documentation (Swagger UI)

An interactive Swagger UI is included at [`docs/index.html`](docs/index.html). Open it directly in any browser — it works from the local filesystem without a web server because the OpenAPI spec is embedded inline.

- Click **Authorize** (lock icon) and paste a bearer token obtained from the auth endpoint to enable **Try it out** on the ticket endpoint.
- The raw OpenAPI 3.0 spec is at [`docs/openapi.yaml`](docs/openapi.yaml) and can be imported into Postman, Insomnia, or any other OpenAPI-aware tool.

---

## POSH-SiteIQ — PowerShell Module

### Installation

Copy the `POSH-SiteIQ/` folder anywhere on your `$env:PSModulePath`, or import directly:

```powershell
Import-Module 'C:\path\to\POSH-SiteIQ' -Force
```

Requires **PowerShell 5.1** or **PowerShell 7+**.

### Credential Storage

Scripts accept an optional `-Credential` parameter. When omitted they look for an encrypted credential file at `~/.siteiq-cred.xml`:

- **Windows (PS 5.1 or PS 7+):** encrypted with DPAPI — tied to your user account and machine. Created automatically on first run; reused silently on subsequent runs.
- **macOS / Linux (PS 7+):** DPAPI is unavailable, so `Get-Credential` is called every run. No file is written.

The credential block used in every example script:

```powershell
if (-not $Credential) {
    $credPath = Join-Path $HOME '.siteiq-cred.xml'
    if (($IsWindows -or $PSEdition -eq 'Desktop') -and (Test-Path $credPath)) {
        $Credential = Import-Clixml -Path $credPath
    } else {
        $Credential = Get-Credential -Message 'Enter your Site-IQ credentials'
        if ($IsWindows -or $PSEdition -eq 'Desktop') {
            $Credential | Export-Clixml -Path $credPath
        }
    }
}
```

### Cmdlet Reference

The module exports four cmdlets. Import it once per session; the bearer token is stored in module-scope state and reused by all subsequent calls.

#### Connect-SiteIQ

Authenticates and stores the bearer token.

```powershell
Connect-SiteIQ [-Credential] <PSCredential> [-BaseUri <string>] [-WhatIf] [-Verbose]
```

| Parameter     | Type         | Required | Default                   | Description |
|---------------|--------------|----------|---------------------------|-------------|
| `-Credential` | PSCredential | Yes      | —                         | Site-IQ email (as username) and password |
| `-BaseUri`    | string       | No       | `https://dfs.site-iq.com` | Override the API base URL |

Returns a `PSCustomObject` with `Connected`, `Email`, and `BaseUri`.

```powershell
Connect-SiteIQ -Credential (Get-Credential)

$session = Connect-SiteIQ -Credential (Get-Credential)
if (-not $session.Connected) { throw 'Auth failed' }

# Against a custom endpoint
Connect-SiteIQ -Credential (Get-Credential) -BaseUri 'https://staging.site-iq.com'
```

#### Disconnect-SiteIQ

Clears the stored bearer token.

```powershell
Disconnect-SiteIQ [-WhatIf]
```

#### Get-SiteIQTicket

Queries the ticket API. Must be called after `Connect-SiteIQ`.

```powershell
# Date range mode
Get-SiteIQTicket [-Status <string>] [-StartDate <datetime>] [-EndDate <datetime>]
                 [-PageLimit <int>] [-PageOffset <int>] [-All] [-Verbose]

# Delta mode
Get-SiteIQTicket [-Status <string>] -Delta <long>
                 [-PageLimit <int>] [-PageOffset <int>] [-All] [-Verbose]
```

| Parameter     | Type     | Required | Default      | Description |
|---------------|----------|----------|--------------|-------------|
| `-Status`     | string   | No       | `InProgress` | `InProgress`, `Closed`, `Pending Closed`, `Dispatch`, `All` |
| `-StartDate`  | datetime | No       | 30 days ago  | Start of date window. Mutually exclusive with `-Delta`. |
| `-EndDate`    | datetime | No       | Today        | End of date window. Mutually exclusive with `-Delta`. |
| `-Delta`      | long     | Yes*     | —            | Unix epoch timestamp. Returns tickets modified after this time. |
| `-PageLimit`  | int      | No       | `1000`       | Tickets per request (1–1000). Ignored with `-All`. |
| `-PageOffset` | int      | No       | `0`          | Zero-based page offset. Ignored with `-All`. |
| `-All`        | switch   | No       | off          | Auto-pages through all results and streams to the pipeline. |

```powershell
# Defaults: InProgress, last 30 days
Get-SiteIQTicket

# Closed tickets for a specific month
Get-SiteIQTicket -Status Closed -StartDate '2025-07-01' -EndDate '2025-07-31'

# Every ticket, every page
Get-SiteIQTicket -Status All -All

# Incremental sync
$epoch = [long]([datetime]'2025-08-01T00:00:00Z' - [datetime]'1970-01-01T00:00:00Z').TotalSeconds
Get-SiteIQTicket -Delta $epoch -Status All -All

# Pipeline
Get-SiteIQTicket -Status All -All |
    Where-Object { $_.warrantyStatus -eq 'Out' } |
    Group-Object component |
    Sort-Object Count -Descending |
    Format-Table Count, Name
```

#### Test-SiteIQConnection

Returns `$true` if a session token is stored, `$false` otherwise.

```powershell
if (-not (Test-SiteIQConnection)) { Connect-SiteIQ -Credential (Get-Credential) }
```

### Examples

Every script accepts an optional `-Credential` parameter; if omitted it loads from `~/.siteiq-cred.xml` on Windows or prompts on macOS/Linux.

Scripts marked **Raw** use `Invoke-WebRequest` directly — no module required.

| Script | Description |
|--------|-------------|
| [01-BasicConnection.ps1](POSH-Examples/01-BasicConnection.ps1) | Connect, verify with `Test-SiteIQConnection`, disconnect |
| [01-BasicConnection-Raw.ps1](POSH-Examples/01-BasicConnection-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [02-GetInProgressTickets.ps1](POSH-Examples/02-GetInProgressTickets.ps1) | Fetch open tickets and display a summary table |
| [02-GetInProgressTickets-Raw.ps1](POSH-Examples/02-GetInProgressTickets-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [03-GetClosedTickets.ps1](POSH-Examples/03-GetClosedTickets.ps1) | 20 most-recently-closed tickets, sorted newest first |
| [03-GetClosedTickets-Raw.ps1](POSH-Examples/03-GetClosedTickets-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [04-DateRangeQuery.ps1](POSH-Examples/04-DateRangeQuery.ps1) | Fixed date window and rolling last-7-days queries |
| [04-DateRangeQuery-Raw.ps1](POSH-Examples/04-DateRangeQuery-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [05-Pagination.ps1](POSH-Examples/05-Pagination.ps1) | Manual pagination loop vs automatic `-All` switch |
| [05-Pagination-Raw.ps1](POSH-Examples/05-Pagination-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [06-DeltaSync.ps1](POSH-Examples/06-DeltaSync.ps1) | Incremental sync via epoch timestamp — good for scheduled jobs |
| [06-DeltaSync-Raw.ps1](POSH-Examples/06-DeltaSync-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [07-ExportToCsv.ps1](POSH-Examples/07-ExportToCsv.ps1) | Flatten nested alerts and export all tickets to CSV |
| [07-ExportToCsv-Raw.ps1](POSH-Examples/07-ExportToCsv-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [08-FilterAndGroup.ps1](POSH-Examples/08-FilterAndGroup.ps1) | Group by component/site, find high-alert tickets, find today's tickets |
| [08-FilterAndGroup-Raw.ps1](POSH-Examples/08-FilterAndGroup-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [09-WarrantyReport.ps1](POSH-Examples/09-WarrantyReport.ps1) | In/out warranty split, expiring-soon warning, out-of-warranty by site |
| [09-WarrantyReport-Raw.ps1](POSH-Examples/09-WarrantyReport-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [10-FullWorkflow.ps1](POSH-Examples/10-FullWorkflow.ps1) | Weekly report: fetch, summarize by site and component, export CSV |
| [10-FullWorkflow-Raw.ps1](POSH-Examples/10-FullWorkflow-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [11-StoredCredential.ps1](POSH-Examples/11-StoredCredential.ps1) | DPAPI credential file demo — create once, reuse silently |
| [11-StoredCredential-Raw.ps1](POSH-Examples/11-StoredCredential-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [12-AlertDrillDown.ps1](POSH-Examples/12-AlertDrillDown.ps1) | Flatten alerts, top error types, still-open alerts, hot fueling positions |
| [12-AlertDrillDown-Raw.ps1](POSH-Examples/12-AlertDrillDown-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [13-GetAllAlerts.ps1](POSH-Examples/13-GetAllAlerts.ps1) | Pull every alert across all tickets and display as a flat, sorted table |
| [13-GetAllAlerts-Raw.ps1](POSH-Examples/13-GetAllAlerts-Raw.ps1) | Same using raw `Invoke-WebRequest` |
| [14-GetOpenAlerts.ps1](POSH-Examples/14-GetOpenAlerts.ps1) | Pull only unresolved (still-open) alerts, sorted by site |
| [15-GetOpenAlerts-Raw.ps1](POSH-Examples/15-GetOpenAlerts-Raw.ps1) | Same using raw `Invoke-WebRequest` — with error-type classification |

---

## pySiteIQ — Python Module

### Installation

```bash
pip install requests          # required
pip install keyring           # optional — enables persistent credential storage
```

Or from the requirements file:

```bash
pip install -r pyExamples/requirements.txt
```

Requires **Python 3.9+**.

> **Note:** All example scripts include a dependency guard at the top. If `requests` (or any other required package) is missing you will see a clear message instead of a traceback:
> ```
> Missing dependency: No module named 'requests'
> Run: pip install -r requirements.txt
> ```

### Credential Storage

`pyExamples/_creds.py` uses the [`keyring`](https://pypi.org/project/keyring/) package to store credentials in the native system keychain:

| Platform | Credential store           |
|----------|---------------------------|
| Windows  | Windows Credential Manager |
| macOS    | Keychain Access            |
| Linux    | libsecret / KWallet        |

On first run the helper prompts for email + password, then saves them. Subsequent runs load silently. If `keyring` is not installed, it falls back to `getpass` on every run.

To clear stored credentials:

```python
from _creds import clear_credential
clear_credential()
```

### API Reference

```python
from pySiteIQ import SiteIQClient, SiteIQError, SiteIQAuthError
```

#### `SiteIQClient(base_uri='https://dfs.site-iq.com')`

| Parameter  | Type | Default                   | Description |
|------------|------|---------------------------|-------------|
| `base_uri` | str  | `https://dfs.site-iq.com` | Override the API base URL |

Supports use as a context manager — `disconnect()` is called automatically on exit.

```python
with SiteIQClient() as client:
    client.connect(email, password)
    tickets = client.get_tickets()
```

#### `.connect(email, password) → dict`

Authenticates and stores the bearer token. Raises `SiteIQAuthError` on HTTP 401/403. Returns `{'connected': True, 'email': ..., 'base_uri': ...}`.

#### `.disconnect() → None`

Clears the stored bearer token.

#### `.is_connected() → bool`

Returns `True` if a token is currently stored.

#### `.get_tickets(**kwargs) → list`

All parameters are keyword-only.

| Parameter     | Type            | Default | Description |
|---------------|-----------------|---------|-------------|
| `status`      | str             | —       | `'InProgress'`, `'Closed'`, `'Pending Closed'`, `'Dispatch'`, `'All'` |
| `start_date`  | str \| datetime | —       | Start of date window (`'YYYY-MM-DD'` or `datetime`). Ignored with `delta`. |
| `end_date`    | str \| datetime | —       | End of date window. Ignored with `delta`. |
| `delta`       | int             | —       | Unix epoch timestamp. Returns tickets modified after this time. |
| `page_limit`  | int             | `1000`  | Tickets per request (1–1000). Ignored with `all_pages=True`. |
| `page_offset` | int             | `0`     | Zero-based page offset. Ignored with `all_pages=True`. |
| `all_pages`   | bool            | `False` | Auto-pages and returns all results as a single list. |

```python
# Defaults: InProgress, last 30 days
tickets = client.get_tickets()

# Closed tickets for a specific month
tickets = client.get_tickets(status='Closed', start_date='2025-07-01', end_date='2025-07-31')

# Every ticket, every page
tickets = client.get_tickets(status='All', all_pages=True)

# Incremental sync
from datetime import datetime, timezone
epoch = int(datetime(2025, 8, 1, tzinfo=timezone.utc).timestamp())
tickets = client.get_tickets(status='All', delta=epoch, all_pages=True)
```

#### `.iter_tickets(**kwargs) → Iterator[dict]`

Same filter parameters as `.get_tickets()` (no `page_limit`, `page_offset`, or `all_pages`). Streams tickets one at a time, auto-paging. More memory-efficient than `get_tickets(all_pages=True)` for very large result sets.

```python
for ticket in client.iter_tickets(status='All'):
    process(ticket)
```

#### Exceptions

| Exception         | When raised |
|-------------------|-------------|
| `SiteIQError`     | Base class. Also raised when calling ticket methods without connecting. |
| `SiteIQAuthError` | HTTP 401 or 403 from the auth endpoint. |

### Examples

Run examples from the repo root:

```bash
python pyExamples/01_basic_connection.py
```

Scripts marked **Raw** use `requests` directly — no pySiteIQ module required.

| Script | Description |
|--------|-------------|
| [01_basic_connection.py](pyExamples/01_basic_connection.py) | Connect, check `is_connected()`, disconnect |
| [01_basic_connection_raw.py](pyExamples/01_basic_connection_raw.py) | Same using `requests` directly |
| [02_get_in_progress_tickets.py](pyExamples/02_get_in_progress_tickets.py) | Fetch open tickets and print a formatted table |
| [02_get_in_progress_tickets_raw.py](pyExamples/02_get_in_progress_tickets_raw.py) | Same using `requests` directly |
| [03_get_closed_tickets.py](pyExamples/03_get_closed_tickets.py) | 20 most-recently-closed tickets, sorted newest first |
| [03_get_closed_tickets_raw.py](pyExamples/03_get_closed_tickets_raw.py) | Same using `requests` directly |
| [04_date_range_query.py](pyExamples/04_date_range_query.py) | Fixed date window and rolling last-7-days queries |
| [04_date_range_query_raw.py](pyExamples/04_date_range_query_raw.py) | Same using `requests` directly |
| [05_pagination.py](pyExamples/05_pagination.py) | Manual pagination loop vs `all_pages=True` |
| [05_pagination_raw.py](pyExamples/05_pagination_raw.py) | Same using `requests` directly |
| [06_delta_sync.py](pyExamples/06_delta_sync.py) | Incremental sync via epoch timestamp |
| [06_delta_sync_raw.py](pyExamples/06_delta_sync_raw.py) | Same using `requests` directly |
| [07_export_to_csv.py](pyExamples/07_export_to_csv.py) | Flatten tickets to CSV using `csv.DictWriter` |
| [07_export_to_csv_raw.py](pyExamples/07_export_to_csv_raw.py) | Same using `requests` directly |
| [08_filter_and_group.py](pyExamples/08_filter_and_group.py) | Group by component/site using `Counter`, find high-alert tickets |
| [08_filter_and_group_raw.py](pyExamples/08_filter_and_group_raw.py) | Same using `requests` directly |
| [09_warranty_report.py](pyExamples/09_warranty_report.py) | In/out warranty split, expiring-soon list, out-of-warranty by site |
| [09_warranty_report_raw.py](pyExamples/09_warranty_report_raw.py) | Same using `requests` directly |
| [10_full_workflow.py](pyExamples/10_full_workflow.py) | Weekly report: fetch, summarize, export timestamped CSV |
| [10_full_workflow_raw.py](pyExamples/10_full_workflow_raw.py) | Same using `requests` directly |
| [11_stored_credential.py](pyExamples/11_stored_credential.py) | Keychain credential demo — prompt once, reuse silently |
| [11_stored_credential_raw.py](pyExamples/11_stored_credential_raw.py) | Same using `requests` directly |
| [12_alert_drill_down.py](pyExamples/12_alert_drill_down.py) | Flatten alerts, top error types, still-open alerts, hot fueling positions |
| [12_alert_drill_down_raw.py](pyExamples/12_alert_drill_down_raw.py) | Same using `requests` directly |
| [13_get_all_alerts.py](pyExamples/13_get_all_alerts.py) | Pull every alert across all tickets and display as a flat formatted table |
| [13_get_all_alerts_raw.py](pyExamples/13_get_all_alerts_raw.py) | Same using `requests` directly |
| [14_get_open_alerts.py](pyExamples/14_get_open_alerts.py) | Pull only unresolved (still-open) alerts, sorted by site |
| [15_get_open_alerts_raw.py](pyExamples/15_get_open_alerts_raw.py) | Same using `requests` directly — with error-type classification |
