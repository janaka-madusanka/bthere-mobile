"""Export the audited customer UI map as a self-contained SVG for design review."""
from pathlib import Path
from html import escape
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs' / 'design' / 'customer-ui-map.svg'
parts = []
nodes = {}

def add(s):
    parts.append(s)

def text(x, y, value, size=18, color='#183C44', weight=400):
    add(f'<text x="{x}" y="{y}" font-family="Arial, sans-serif" font-size="{size}" fill="{color}" font-weight="{weight}">{escape(value)}</text>')

def panel(x, y, w, h, title, subtitle):
    add(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="24" fill="#F5FAFA" stroke="#D7E6E8"/>')
    text(x+24, y+40, title, 24, weight=700)
    text(x+24, y+68, subtitle, 15, '#617B82')

def node(key, x, y, w, title, desc='', kind='screen'):
    fill, stroke = {'screen': ('#FFFFFF', '#B8D3D7'), 'overlay': ('#F1F4FF', '#BAC7EB'), 'state': ('#E3F8F6', '#82CBC6'), 'decision': ('#FFF6DA', '#DEC570')}[kind]
    add(f'<g id="{key}"><rect x="{x}" y="{y}" width="{w}" height="88" rx="14" fill="{fill}" stroke="{stroke}" stroke-width="2"/>')
    text(x+16, y+23, key, 13, '#55767D', 700)
    text(x+16, y+48, title, 18, weight=700)
    if desc:
        text(x+16, y+71, desc, 14, '#617B82')
    add('</g>')
    nodes[key] = (x, y, w, 88)

def arrow(a, b, label='', dashed=False, side=False):
    ax, ay, aw, ah = nodes[a]
    bx, by, bw, bh = nodes[b]
    if side:
        x1,y1,x2,y2 = ax+aw,ay+ah/2,bx,by+bh/2
        path = f'M{x1},{y1} H{(x1+x2)/2} V{y2} H{x2}'
    else:
        x1,y1,x2,y2 = ax+aw/2,ay+ah,bx+bw/2,by
        path = f'M{x1},{y1} V{(y1+y2)/2} H{x2} V{y2}'
    dash = 'stroke-dasharray="7 5"' if dashed else ''
    add(f'<path d="{path}" fill="none" stroke="#458B93" stroke-width="2.5" {dash} marker-end="url(#arrow)"/>')
    if label:
        tx,ty = (x1+8,(y1+y2)/2-6) if not side else ((x1+x2)/2+8,y1-8)
        text(tx,ty,label,13,'#356D75',700)

add('<svg xmlns="http://www.w3.org/2000/svg" width="2560" height="2610" viewBox="0 0 2560 2610" role="img" aria-labelledby="title description">')
add('<title id="title">BThere customer app UI and navigation map</title><desc id="description">Audited implemented customer screens, overlays, scheduled booking states and enhancement order. Pending features and backend constraints are called out separately.</desc>')
add('<defs><marker id="arrow" markerWidth="8" markerHeight="8" refX="7" refY="4" orient="auto"><path d="M0,0 L8,4 L0,8 Z" fill="#458B93"/></marker></defs>')
add('<rect width="2560" height="2610" fill="#FFFFFF"/>')
add('<rect width="2560" height="170" fill="#006D75"/>')
text(40,65,'BThere / Customer app',38,'#FFFFFF',700)
text(40,105,'UI inventory + navigation map',25,'#CEF4F1')
text(40,140,'Audit: 30 Oct 2026  |  Screen IDs match customer-ui-inventory.md  |  All units pending visual review',17,'#CEF4F1')
text(1390,65,'READING THE MAP',15,'#CEF4F1',700)
text(1390,98,'White: screen   /   Lavender: overlay   /   Teal: state   /   Yellow: decision',17,'#FFFFFF')
text(1390,130,'Solid arrows: main journey   /   Dashed arrows: optional or supporting action',17,'#FFFFFF')

panel(40,210,560,1900,'01 / Authentication & profile','Session guards choose the required next step')
panel(630,210,560,1900,'02 / Home & discovery','Main entry points and browsing')
panel(1220,210,700,1900,'03 / Booking & payment','Scheduled request flow; both selection modes')
panel(1950,210,570,1900,'04 / Wallet','Saved methods and test top-ups')

auth = [
('A01','Startup / session restore','Existing session may skip authentication','state'),
('A02','Email sign in','Auth entry; switch to registration or phone','screen'),
('A03','Email registration','Alternative to sign in','screen'),
('A04','Phone sign in','Request phone OTP','screen'),
('A05','Email OTP verification','Email registration branch','state'),
('A06','Phone OTP verification','Phone sign-in branch','state'),
('A07','Verification success','Continue through profile / market guards','state'),
('P01','Create customer profile','Only when profile is missing','screen'),
('P03','Account','Reached from the top-bar profile action','screen'),
('P02','Edit profile / photo','Existing-profile editing mode','screen'),
('P04','Sign-out confirmation','Account session action','overlay'),
('S01','Configuration help','Shown when runtime configuration is missing','state')]
for i,(key,title,desc,kind) in enumerate(auth):
    node(key,64,310+i*133,512,title,desc,kind)
arrow('A01','A02','If signed out')
# Alternative auth branches are grouped, not incorrectly drawn as sequential steps.
text(70,710,'A02 / A03 / A04 are alternative entry modes.',15,'#617B82')
arrow('A06','A07')
arrow('A07','P01','If profile missing')
arrow('P03','P02')

discovery = [
('D01','Market selection','Required when no market is active','screen'),
('D02','Home','Services, recent bookings, wallet and account','screen'),
('D03','Services / search / options','Expandable service catalog','screen'),
('D04','Service option information','Description and access reasons','overlay'),
('H01','Booking history','Home > Recent services > View all','screen'),
('H02','Historical booking details','Tap a booking history item','overlay')]
for i,(key,title,desc,kind) in enumerate(discovery):
    node(key,654,310+i*150,512,title,desc,kind)
for a,b in [('D01','D02'),('D02','D03'),('D03','D04'),('H01','H02')]:
    arrow(a,b)
text(660,1280,'HOME DESTINATIONS',16,weight=700)
for i,line in enumerate(['Services -> D03','Recent bookings -> H01 / H02','Wallet tab -> W01','Profile action -> P03 / P02']):
    text(660,1320+i*34,line,19)
text(660,1510,'VISIBLE, NOT IMPLEMENTED SCREENS',16,'#9A6B22',700)
for i,line in enumerate(['Opportunities: coming-soon action','Messages: coming-soon action','Notifications: coming-soon action','Recurring services: coming soon']):
    text(660,1550+i*34,line,18,'#796B51')
text(660,1755,'These are separate future functional work.',17,'#617B82')

node('B01',1244,310,652,'Additional service requirements','Conditional access form; continue only when access allows','state')
node('B02',1244,450,652,'Filters / location / schedule / availability','Live provider availability and required selections')
node('G01',1244,600,300,'Providers available?','No -> remain on filters','decision')
node('B06',1596,600,300,'Choose provider','Direct request only')
node('B07',1244,770,652,'Booking details + estimated cost','Open request skips B06; direct request arrives after selection')
node('B08',1244,910,652,'Review booking / payment category','Backend-supported methods only')
node('B09',1596,1050,300,'Select saved card','Card branch; add W03','overlay')
node('B10',1244,1190,652,'Payment confirmation','Creates request using current backend policy')
node('B11',1244,1330,652,'Finding a provider','MATCHING; authoritative status polling','state')
node('B12',1244,1470,652,'Provider accepted','Backend deadline; acceptance alone is not payment success','state')
node('B13',1244,1610,652,'Request details / supported payment action','Current scheduled flow confirms payment after acceptance','state')
node('B14',1244,1780,300,'Payment successful','Confirmed paid / reserved','state')
node('B15',1596,1780,300,'Payment failed','Known failure; retry','state')
for a,b in [('B01','B02'),('B02','G01'),('B07','B08'),('B09','B10'),('B10','B11'),('B11','B12'),('B12','B13'),('B13','B14')]:
    arrow(a,b)
arrow('G01','B06','Direct',side=True)
arrow('G01','B07','Open')
arrow('B06','B07')
arrow('B08','B09','Card')
arrow('B08','B10','Wallet / other')
arrow('B13','B15')
text(1248,1940,'SUPPORTING OVERLAYS',15,weight=700)
text(1248,1972,'B03 Location picker   /   B04 Radius   /   B05 Date, time, duration',16,'#617B82')
text(1248,2004,'B16 Cancel unpaid request / change method confirmation',16,'#617B82')
text(1248,2036,'B15 retry -> B13   |   B14 View booking -> B13',16,'#617B82')
text(1248,2068,'B02 opens B03-B05; B11-B13 may expose B16 when allowed.',15,'#617B82')

wallet = [
('W01','Wallet overview','Balance, methods and recent transactions','screen'),
('W02','Manage payment methods','Saved cards and add-card action','overlay'),
('W03','Add new card','Validation and card brand detection','overlay'),
('W06','Saved-card actions / remove','Method action menu','overlay'),
('W04','Add money','Quick / custom amount and payment method','overlay'),
('W05','Full payment history','Wallet > Payment history > View all','overlay')]
for i,(key,title,desc,kind) in enumerate(wallet):
    node(key,1974,310+i*165,522,title,desc,kind)
arrow('W01','W02')
arrow('W02','W03','Add',dashed=True)
text(1982,1380,'W01 -> W04: Add money',19)
text(1982,1420,'W01 -> W05: View all history',19)
text(1982,1460,'W02 -> W06: Card actions',19)
text(1982,1500,'B09 reuses W03 for adding a card.',18,'#617B82')
text(1982,1610,'PAYMENT CONTRACT LIMITS',16,'#9A6B22',700)
for i,line in enumerate(['Card setup remains test / mock.','Pre-match hold / preauthorization needs','a backend contract before implementation.','No invented 30-second auto approval.','Legacy booking branches need separate','regression checks when their UI changes.']):
    text(1982,1650+i*32,line,17,'#796B51')

panel(40,2150,2480,200,'Shared components / review once, verify everywhere','These are reused components, not extra navigation destinations')
text(64,2250,'C01 Typography + spacing    C02 Top bar    C03 Bottom navigation    C04 Map controls + dropdowns',21)
text(64,2295,'C05 Form fields + validation    C06 Amounts + payment rows    C07 Loading / empty / error / retry states',21)
text(40,2410,'ENHANCEMENT ORDER',18,'#006D75',700)
text(40,2452,'Shared baseline -> Home / services -> Booking journey -> History -> Wallet -> Auth / profile -> Full consistency pass',24,weight=700)
text(40,2504,'Per UI: current screenshot -> agreed reference -> implement -> device review -> approve -> next UI',20,'#617B82')
text(40,2550,'Check small screens, keyboard, long text, larger text, safe areas, back navigation and retained selections.',18,'#617B82')
add('</svg>')
svg = '\n'.join(parts)
ET.fromstring(svg)
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(svg, encoding='utf-8')
print(f'Created {OUT.relative_to(ROOT)} ({len(nodes)} mapped nodes)')
