# Manual pagination vs the all_pages parameter
import pathlib, sys
sys.path.insert(0, str(pathlib.Path(__file__).parent.parent))
sys.path.insert(0, str(pathlib.Path(__file__).parent))

from pySiteIQ import SiteIQClient
from _creds import get_credential

email, password = get_credential()

with SiteIQClient() as client:
    client.connect(email, password)

    # Manual: 50 at a time
    page_size = 50
    offset = 0
    all_tickets = []

    while True:
        batch = client.get_tickets(status='All', page_limit=page_size, page_offset=offset)
        all_tickets.extend(batch)
        print(f'  Offset {offset:>5}: got {len(batch)} tickets')
        if len(batch) < page_size:
            break
        offset += page_size

    print(f'Manual total: {len(all_tickets)}\n')

    # Or let the client handle it automatically
    everything = client.get_tickets(status='All', all_pages=True)
    print(f'Auto-paged total: {len(everything)}')
