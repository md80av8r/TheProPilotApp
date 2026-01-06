#!/usr/bin/env python3
"""
AirNav FBO Scraper
Fetches FBO data from AirNav.com for specified airports.

Usage:
    python3 scrape_airnav_fbos.py

Output: propilot_fbos.csv in the project root directory
"""

import csv
import random
import re
import time
import urllib.request
from typing import List, Dict

# Rotate user agents to look more natural
USER_AGENTS = [
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:121.0) Gecko/20100101 Firefox/121.0',
]

# Top US airports - modify this list as needed
AIRPORTS = [
    # Major Hubs
    "KATL", "KLAX", "KORD", "KDFW", "KDEN", "KJFK", "KSFO", "KLAS", "KSEA", "KMCO",
    "KEWR", "KPHX", "KMIA", "KIAH", "KBOS", "KMSP", "KDTW", "KFLL", "KPHL", "KLGA",
    "KBWI", "KSLC", "KDCA", "KSAN", "KTPA", "KAUS", "KMDW", "KHNL", "KSTL", "KBNA",
    "KOAK", "KSMF", "KPDX", "KSJC", "KMCI", "KCLT", "KRDU", "KSAT", "KCLE", "KPIT",
    "KIND", "KCMH", "KPBI", "KABQ", "KANC", "KONT", "KSNA", "KBUR", "KFAT",

    # Business Aviation Hubs
    "KTEB", "KVNY", "KHPN", "KSDL", "KAPA", "KADS", "KPDK", "KOPF", "KFXE", "KBCT",
    "KPTK", "KFRG", "KBED", "KPWK", "KCRQ", "KSMO", "KMMU", "KCDW", "KHWD", "KSQL",
    "KSGR", "KDWH", "KAFW", "KFTW", "KFFZ", "KIWA", "KDVT", "KCGZ", "KCHD", "KISP",

    # Regional/GA Airports
    "KBJC", "KEGE", "KASE", "KTEX", "KGUC", "KMTJ", "KGJT", "KCYS", "KLAR",
    "KBZN", "KMSO", "KBIL", "KGTF", "KHLN", "KFCA", "KGPI", "KIDA", "KTWF", "KPIH",
    "KSUN", "KJAC", "KRKS", "KOGD", "KPVU", "KCDC", "KSGU", "KPRC", "KFLG",
    "KIFP", "KTUS", "KGYR", "KGEU",

    # More GA airports
    "KFFC", "KLZU", "KRYY", "KCNI", "KPDK", "KAHN", "KSAV", "KJAX", "KDAB",
    "KOBE", "KLEE", "KLAL", "KAPF", "KRSW", "KSPG", "KPIE", "KSRQ", "KVRB",
    "KPMP", "KHWO", "KTMB", "KMTH", "KEYW", "KISM", "KORL", "KSFB", "KMLB",
]

# Blacklist for non-FBO alt text (badges, certifications, etc)
NAME_BLACKLIST = [
    'Air Elite', 'IS-BAH', 'Multi Service', 'NATA', 'Safety', 'Customs',
    'DASSP', 'AEG Fuels', 'Everest', 'CAA', 'U.S.', 'UVair', 'Avcard',
    'World Fuel', 'Phillips', 'Colt', 'Contract', 'Aviation Card', 'MSA',
    'Go Rentals', 'ARGUS', 'Wyvern', 'TSA', 'Registered', '1dot'
]


def fetch_url(url: str, retry_count: int = 3) -> str:
    """Fetch URL content with proper headers and retry logic"""
    headers = {
        'User-Agent': random.choice(USER_AGENTS),
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
        'Accept-Encoding': 'identity',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
    }

    for attempt in range(retry_count):
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as response:
                if response.status == 200:
                    return response.read().decode('utf-8', errors='ignore')
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait_time = (attempt + 1) * 30
                print(f"  Rate limited (429)! Waiting {wait_time}s...")
                time.sleep(wait_time)
                continue
            elif e.code == 403:
                print(f"  Blocked (403)!")
                return ""
            else:
                print(f"  HTTP Error {e.code}")
        except Exception as e:
            print(f"  Error: {e}")

        if attempt < retry_count - 1:
            time.sleep(5)

    return ""


def scrape_airport(airport: str) -> List[Dict]:
    """Scrape FBO data for a single airport"""
    url = f"https://www.airnav.com/airport/{airport}"
    html = fetch_url(url)
    if not html:
        return []

    fbos = []

    # Find FBO section
    fbo_start = html.find('FBO, Fuel Providers')
    if fbo_start < 0:
        return fbos

    next_section = html.find('<H3>', fbo_start + 100)
    if next_section < 0:
        next_section = len(html)

    fbo_section = html[fbo_start:next_section]

    # Split into rows - each FBO is in a TR with valign=middle
    rows = re.split(r'<TR[^>]*valign=middle[^>]*>', fbo_section)

    seen_fbos = set()  # Track by email to avoid duplicates

    for row in rows[1:]:  # Skip header
        # Get FBO ID from href pattern
        id_match = re.search(r'href="/airport/' + airport + r'/([A-Z0-9_]+)"', row)
        if not id_match:
            continue
        fbo_id = id_match.group(1)
        if '#' in fbo_id or 'comment' in fbo_id.lower() or 'link' in fbo_id.lower():
            continue

        # Try multiple methods to get the FBO name
        name = None

        # Method 1: Look for "More info about {FBO Name}"
        more_info = re.search(r'More info[^<]*about ([^<]+)</FONT>', row)
        if more_info:
            name = more_info.group(1).strip()

        # Method 2: Look for 240x60 logo image with alt text
        if not name:
            img_match = re.search(r'<IMG src="[^"]+/lc/' + fbo_id + r'/[^"]*"[^>]*alt="([^"]+)"', row)
            if img_match:
                candidate = img_match.group(1).strip()
                if not any(b.lower() in candidate.lower() for b in NAME_BLACKLIST):
                    name = candidate

        # Method 3: Use cleaned FBO ID
        if not name:
            name = fbo_id.replace('_', ' ').title()
            # Expand common abbreviations
            name = name.replace(' Av', ' Aviation').replace(' E', ' East').replace(' W', ' West').replace(' S', ' South')

        # Skip if name matches blacklist
        if any(b.lower() in name.lower() for b in NAME_BLACKLIST):
            continue

        if len(name) < 4:
            continue

        # Get phone
        phone_match = re.search(r'(\d{3}[-.]?\d{3}[-.]?\d{4})', row)
        phone = phone_match.group(1) if phone_match else ''

        # Get email
        email_match = re.search(r'mailto:([^?"]+)', row)
        email = email_match.group(1) if email_match else ''

        # Skip duplicates (same email at same airport)
        fbo_key = f"{airport}:{email}" if email else f"{airport}:{name}"
        if fbo_key in seen_fbos:
            continue
        seen_fbos.add(fbo_key)

        # Get ASRI frequency
        asri_match = re.search(r'ASRI ([0-9.]+)', row)
        asri = asri_match.group(1) if asri_match else ''

        fbos.append({
            'airport_code': airport,
            'name': name,
            'phone': phone,
            'unicom': asri,
            'website': '',  # Could parse if needed
            'email': email,
            'jet_a_price': '',
            'avgas_price': '',
            'crew_cars': 'Unknown',
            'crew_lounge': 'Yes',
            'catering': 'Unknown',
            'maintenance': 'Unknown',
            'hangars': 'Unknown',
            'deice': 'Unknown',
            'oxygen': 'Unknown',
            'gpu': 'Unknown',
            'lav': 'Unknown',
            'handling_fee': '',
            'overnight_fee': '',
            'ramp_fee': '',
            'ramp_fee_waived': 'Unknown'
        })

    return fbos


def main():
    """Main scraper function"""
    all_fbos = []

    print("=" * 60)
    print("AirNav FBO Scraper")
    print("=" * 60)
    print(f"Scraping {len(AIRPORTS)} airports...")
    print()

    for i, airport in enumerate(AIRPORTS):
        print(f"[{i+1}/{len(AIRPORTS)}] Fetching {airport}...", end=" ")
        fbos = scrape_airport(airport)
        all_fbos.extend(fbos)
        print(f"Found {len(fbos)} FBOs")

        # Rate limiting - randomized to look more human
        if i < len(AIRPORTS) - 1:
            delay = random.uniform(2.0, 4.0)
            time.sleep(delay)

        # Progress update every 20 airports
        if (i + 1) % 20 == 0:
            print(f"  === Progress: {i + 1}/{len(AIRPORTS)} airports, {len(all_fbos)} total FBOs ===")

    print()
    print("=" * 60)
    print(f"Total FBOs found: {len(all_fbos)}")
    print("=" * 60)

    # Write to CSV
    output_file = "../propilot_fbos.csv"
    fieldnames = [
        'airport_code', 'name', 'phone', 'unicom', 'website',
        'jet_a_price', 'avgas_price', 'crew_cars', 'crew_lounge',
        'catering', 'maintenance', 'hangars', 'deice', 'oxygen',
        'gpu', 'lav', 'handling_fee', 'overnight_fee', 'ramp_fee', 'ramp_fee_waived'
    ]

    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for fbo in all_fbos:
            # Only write fields that match our schema
            row = {k: fbo.get(k, '') for k in fieldnames}
            writer.writerow(row)

    print(f"\nWrote {len(all_fbos)} FBOs to {output_file}")
    print("Done!")


if __name__ == "__main__":
    main()
