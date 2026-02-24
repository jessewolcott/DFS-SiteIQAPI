import requests
from datetime import datetime
from typing import Iterator, Optional, Union


class SiteIQError(Exception):
    """Base exception for Site-IQ API errors."""


class SiteIQAuthError(SiteIQError):
    """Authentication failed (HTTP 401/403)."""


class SiteIQClient:
    """
    Client for the DFS Site-IQ Tickets External API.

    Basic usage::

        client = SiteIQClient()
        client.connect('user@example.com', 'password')
        tickets = client.get_tickets()
        client.disconnect()

    As a context manager::

        with SiteIQClient() as client:
            client.connect('user@example.com', 'password')
            for ticket in client.iter_tickets(status='All'):
                print(ticket['ticketID'])
    """

    DEFAULT_BASE_URI = 'https://dfs.site-iq.com'
    _VALID_STATUSES = frozenset({'InProgress', 'Closed', 'Pending Closed', 'Dispatch', 'All'})

    def __init__(self, base_uri: str = DEFAULT_BASE_URI) -> None:
        self.base_uri: str = base_uri.rstrip('/')
        self._token: Optional[str] = None
        self._email: Optional[str] = None

    def connect(self, email: str, password: str) -> dict:
        """Authenticate and store the bearer token. Raises SiteIQAuthError on 401/403."""
        resp = requests.post(
            f'{self.base_uri}/api/web/auth/token',
            json={'email': email, 'password': password},
            timeout=30,
        )
        if resp.status_code in (401, 403):
            raise SiteIQAuthError(
                f'Authentication failed (HTTP {resp.status_code}): check email and password'
            )
        resp.raise_for_status()
        self._token = resp.json()['token']
        self._email = email
        return {'connected': True, 'email': email, 'base_uri': self.base_uri}

    def disconnect(self) -> None:
        """Clear the stored session token."""
        self._token = None
        self._email = None

    def is_connected(self) -> bool:
        """Return True if a token is currently stored."""
        return self._token is not None

    def get_tickets(
        self,
        *,
        status: Optional[str] = None,
        start_date: Optional[Union[str, datetime]] = None,
        end_date: Optional[Union[str, datetime]] = None,
        delta: Optional[int] = None,
        page_limit: int = 1000,
        page_offset: int = 0,
        all_pages: bool = False,
    ) -> list:
        """
        Retrieve tickets from the API. All parameters are keyword-only.

        status     -- 'InProgress', 'Closed', 'Pending Closed', 'Dispatch', or 'All'
        start_date -- 'YYYY-MM-DD' string or datetime; ignored when delta is set
        end_date   -- 'YYYY-MM-DD' string or datetime; ignored when delta is set
        delta      -- Unix epoch (int); returns tickets modified after this timestamp;
                      mutually exclusive with start_date/end_date
        page_limit -- tickets per request, 1-1000 (ignored when all_pages=True)
        page_offset -- zero-based page offset (ignored when all_pages=True)
        all_pages  -- auto-page through everything and return a single list
        """
        self._require_connected()
        params = self._build_params(status, start_date, end_date, delta)

        if all_pages:
            return list(self._iter_pages(params))

        if not (1 <= page_limit <= 1000):
            raise ValueError('page_limit must be between 1 and 1000')
        if page_offset < 0:
            raise ValueError('page_offset must be >= 0')

        params['pageLimit'] = str(page_limit)
        params['pageOffset'] = str(page_offset)
        return self._get(params)

    def iter_tickets(
        self,
        *,
        status: Optional[str] = None,
        start_date: Optional[Union[str, datetime]] = None,
        end_date: Optional[Union[str, datetime]] = None,
        delta: Optional[int] = None,
    ) -> Iterator[dict]:
        """
        Stream all matching tickets one at a time, auto-paging.

        Accepts the same filter parameters as get_tickets(). More memory-efficient
        than get_tickets(all_pages=True) when working with very large result sets.
        """
        self._require_connected()
        yield from self._iter_pages(self._build_params(status, start_date, end_date, delta))

    def _require_connected(self) -> None:
        if not self._token:
            raise SiteIQError('Not connected. Call connect() first.')

    def _build_params(self, status, start_date, end_date, delta) -> dict:
        if delta is not None and (start_date is not None or end_date is not None):
            raise ValueError('delta cannot be combined with start_date or end_date')
        if status is not None and status not in self._VALID_STATUSES:
            raise ValueError(f'status must be one of {sorted(self._VALID_STATUSES)}')

        params: dict = {}
        if status:
            params['status'] = status
        if delta is not None:
            params['delta'] = str(int(delta))
        else:
            if start_date is not None:
                params['startDate'] = _fmt_date(start_date)
            if end_date is not None:
                params['endDate'] = _fmt_date(end_date)
        return params

    def _get(self, params: dict) -> list:
        resp = requests.get(
            f'{self.base_uri}/api/external/ticket',
            params=params,
            headers={'Authorization': f'Bearer {self._token}', 'Accept': '*/*'},
            timeout=30,
        )
        resp.raise_for_status()
        return resp.json()

    def _iter_pages(self, base_params: dict) -> Iterator[dict]:
        offset = 0
        while True:
            batch = self._get({**base_params, 'pageLimit': '1000', 'pageOffset': str(offset)})
            yield from batch
            if len(batch) < 1000:
                break
            offset += 1000

    def __enter__(self) -> 'SiteIQClient':
        return self

    def __exit__(self, *args) -> None:
        self.disconnect()

    def __repr__(self) -> str:
        state = f'connected as {self._email}' if self.is_connected() else 'disconnected'
        return f'SiteIQClient({self.base_uri!r}, {state})'


def _fmt_date(d: Union[str, datetime]) -> str:
    return d.strftime('%Y-%m-%d') if isinstance(d, datetime) else d
