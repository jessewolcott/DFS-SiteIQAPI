# Weekly report: pull open + closed, summarize, export to CSV using requests directly — no pySiteIQ module required
import csv
import getpass
import pathlib
import requests
from collections import Counter
from datetime import datetime, timedelta

BASE_URI = 'https://dfs.site-iq.com'

# Authenticate
email    = input('Site-IQ email: ')
password = getpass.getpass('Password: ')

resp = requests.post(
    f'{BASE_URI}/api/web/auth/token',
    json={'email': email, 'password': password},
    timeout=30,
)
resp.raise_for_status()
token = resp.json()['token']

if not token:
    raise RuntimeError('Failed to connect')

headers  = {'Authorization': f'Bearer {token}'}
week_ago = (datetime.now() - timedelta(days=7)).strftime('%Y-%m-%d')


def get_all_pages(status, start_date):
    page_size = 1000
    offset    = 0
    result    = []
    while True:
        r = requests.get(
            f'{BASE_URI}/api/external/ticket',
            headers=headers,
            params={'status': status, 'startDate': start_date, 'pageLimit': page_size, 'pageOffset': offset},
            timeout=30,
        )
        r.raise_for_status()
        batch = r.json()
        result.extend(batch)
        if len(batch) < page_size:
            break
        offset += page_size
    return result


open_tickets   = get_all_pages('InProgress', week_ago)
closed_tickets = get_all_pages('Closed',     week_ago)

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
csv_path  = pathlib.Path(__file__).parent / f'WeeklyReport_{timestamp}.csv'
if report:
    with open(csv_path, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=list(report[0].keys()))
        writer.writeheader()
        writer.writerows(report)
print(f'\nSaved {len(report)} rows to {csv_path}')
