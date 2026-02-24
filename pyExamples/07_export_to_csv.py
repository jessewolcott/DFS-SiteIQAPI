# Flatten tickets and dump to CSV
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

import csv
from datetime import datetime
try:
    from pySiteIQ import SiteIQClient
except ModuleNotFoundError as e:
    sys.exit(f'Missing dependency: {e}\nRun: pip install -r requirements.txt')
from _creds import get_credential

email, password = get_credential()

out_path = pathlib.Path(__file__).parent / 'SiteIQ-Tickets.csv'

with SiteIQClient() as client:
    client.connect(email, password)
    tickets = client.get_tickets(status='All', all_pages=True)

# alerts is nested — flatten to the fields you actually want
rows = []
for t in tickets:
    rows.append({
        'TicketID':       t['ticketID'],
        'Opened':         t.get('ticketOpenTimestamp'),
        'SiteID':         t.get('siteID'),
        'SiteName':       t.get('siteName'),
        'Company':        t.get('companyName'),
        'Address':        t.get('address'),
        'Status':         t.get('ticketStatus'),
        'Component':      t.get('component'),
        'Dispenser':      t.get('dispenser'),
        'WarrantyStatus': t.get('warrantyStatus'),
        'WarrantyDate':   t.get('warrantyDate'),
        'AlertCount':     len(t.get('alerts') or []),
    })

if rows:
    with open(out_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)

print(f'Wrote {len(rows)} rows to {out_path}')
