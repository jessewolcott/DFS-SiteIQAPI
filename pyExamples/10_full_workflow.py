# Weekly report: pull open + closed, summarize, export to CSV
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

import csv
from collections import Counter
from datetime import datetime, timedelta
try:
    from pySiteIQ import SiteIQClient
except ModuleNotFoundError as e:
    sys.exit(f'Missing dependency: {e}\nRun: pip install -r requirements.txt')
from _creds import get_credential

email, password = get_credential()

week_ago = datetime.now() - timedelta(days=7)

with SiteIQClient() as client:
    session = client.connect(email, password)
    if not session['connected']:
        raise RuntimeError('Failed to connect')

    open_tickets   = client.get_tickets(status='InProgress', start_date=week_ago, all_pages=True)
    closed_tickets = client.get_tickets(status='Closed',     start_date=week_ago, all_pages=True)

print(f'Last 7 days — Open: {len(open_tickets)}, Closed: {len(closed_tickets)}\n')

all_tickets = open_tickets + closed_tickets

report = []
for t in all_tickets:
    alerts = t.get('alerts') or []
    report.append({
        'TicketID':   t['ticketID'],
        'Site':       t.get('siteName'),
        'SiteID':     t.get('siteID'),
        'Address':    t.get('address'),
        'Status':     t.get('ticketStatus'),
        'Component':  t.get('component'),
        'Dispenser':  t.get('dispenser'),
        'Warranty':   t.get('warrantyStatus'),
        'Opened':     t.get('ticketOpenTimestamp'),
        'AlertCount': len(alerts),
        'FirstAlert': alerts[0].get('error') if alerts else None,
    })

# Top 5 sites by volume
print('Top 5 sites by volume:')
by_site = Counter(r['Site'] for r in report)
for site, count in by_site.most_common(5):
    print(f'  {count:>5}  {site}')

print()
print('By component:')
by_component = Counter(r['Component'] for r in report)
for comp, count in by_component.most_common():
    print(f'  {count:>5}  {comp}')

# Export
timestamp = datetime.now().strftime('%Y-%m-%d_%H%M%S')
csv_path = pathlib.Path(__file__).parent / f'WeeklyReport_{timestamp}.csv'
if report:
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(report[0].keys()))
        writer.writeheader()
        writer.writerows(report)
print(f'\nSaved {len(report)} rows to {csv_path}')
