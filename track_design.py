import math

points = []
descriptions = []
district_headers = []

def add_point(x, z, desc, header=None):
    if header:
        district_headers.append((len(points), header))
    points.append((x, z))
    descriptions.append(desc)

# DISTRICT 1: START/FINISH STRAIGHT (~5km)
add_point(0, 0, "S/F line", "DISTRICT 1: START/FINISH STRAIGHT (~5km)")
add_point(2500, 0, "mid straight")
add_point(5000, 0, "straight end")

# DISTRICT 2: MONACO — tight technical sweeping
monaco_pts = [
    (6800, 800, "Monaco entry sweep R"),
    (8400, 2200, "Monaco sweep SE"),
    (9600, 4200, "Monaco turn S"),
    (10800, 5600, "Monaco chicane R 1"),
    (9800, 7200, "Monaco chicane L 1"),
    (11200, 8800, "Monaco chicane R 2"),
    (10000, 10400, "Monaco chicane L 2"),
    (11400, 12000, "Monaco chicane R 3"),
    (10200, 13600, "Monaco chicane L 3"),
    (11600, 15200, "Monaco chicane R 4"),
    (10400, 16800, "Monaco chicane L 4"),
    (11800, 18200, "Monaco chicane R 5"),
    (10800, 19800, "Monaco sweep S"),
    (11600, 21200, "Monaco hairpin entry"),
    (12800, 22800, "Monaco sweeper R"),
    (14200, 24000, "Monaco exit sweep"),
    (16000, 25000, "Monaco exit"),
]
for i, (x, z, desc) in enumerate(monaco_pts):
    h = "DISTRICT 2: MONACO (~15km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 3: MONZA BLAST — fast flowing, gentle chicanes
monza_pts = [
    (18000, 27500, "Monza fast entry"),
    (20500, 29500, "Monza gentle chicane R"),
    (19500, 32000, "Monza gentle chicane L"),
    (21000, 34500, "Monza blast 1"),
    (23500, 36500, "Monza gentle R"),
    (22500, 39000, "Monza gentle L"),
    (24500, 41500, "Monza blast 2"),
    (27000, 43500, "Monza flow R"),
    (26000, 46000, "Monza flow L"),
    (28000, 48000, "Monza blast 3"),
    (30500, 50000, "Monza gentle R2"),
    (29500, 52500, "Monza gentle L2"),
    (31500, 54500, "Monza fast exit"),
    (34000, 56000, "Monza exit sweep"),
    (37000, 57000, "Monza exit"),
]
for i, (x, z, desc) in enumerate(monza_pts):
    h = "DISTRICT 3: MONZA BLAST (~20km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 4: SPA COMPLEX
spa_pts = [
    (39000, 59000, "Spa entry arc"),
    (40500, 61500, "Spa Eau Rouge entry"),
    (41000, 64000, "Spa Eau Rouge mid"),
    (40000, 66500, "Spa Eau Rouge exit"),
    (38000, 68500, "Spa long left arc 1"),
    (35500, 70000, "Spa long left arc 2"),
    (32500, 71000, "Spa Blanchimont entry"),
    (29500, 71500, "Spa Blanchimont apex"),
    (26500, 71000, "Spa Blanchimont exit"),
    (23500, 70000, "Spa Bus Stop entry"),
    (21000, 68500, "Spa Bus Stop chicane R"),
    (19000, 70000, "Spa Bus Stop chicane L"),
    (16500, 69000, "Spa exit sweep"),
    (14000, 67500, "Spa exit"),
]
for i, (x, z, desc) in enumerate(spa_pts):
    h = "DISTRICT 4: SPA COMPLEX (~15km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 5: SILVERSTONE SEQUENCE
silver_pts = [
    (11500, 66000, "Silverstone entry"),
    (9000, 65000, "Maggots R 1"),
    (7500, 66500, "Maggots L 1"),
    (5000, 65500, "Becketts R 1"),
    (3500, 67000, "Becketts L 1"),
    (1000, 66000, "Chapel R"),
    (-1000, 67500, "Chapel exit L"),
    (-3500, 66500, "Stowe entry R"),
    (-5500, 68000, "Stowe L"),
    (-8000, 67000, "Vale R"),
    (-10000, 68500, "Vale L"),
    (-12500, 67500, "Club entry R"),
    (-14500, 69000, "Club L"),
    (-17000, 68000, "Club exit R"),
    (-19000, 66500, "Silverstone exit"),
]
for i, (x, z, desc) in enumerate(silver_pts):
    h = "DISTRICT 5: SILVERSTONE (~15km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 6: JEDDAH FLOW
jeddah_pts = [
    (-21500, 64500, "Jeddah fast entry"),
    (-24000, 62500, "Jeddah gentle R"),
    (-26000, 60000, "Jeddah flow 1"),
    (-28500, 57500, "Jeddah gentle L"),
    (-30500, 55000, "Jeddah flow 2"),
    (-33000, 52500, "Jeddah gentle R2"),
    (-35000, 50000, "Jeddah flow 3"),
    (-37500, 47000, "Jeddah gentle L2"),
    (-39000, 44000, "Jeddah flow 4"),
    (-41000, 41000, "Jeddah gentle R3"),
    (-42500, 38000, "Jeddah flow 5"),
    (-43500, 35000, "Jeddah gentle L3"),
    (-44000, 32000, "Jeddah sweep N"),
    (-44500, 29000, "Jeddah flow 6"),
    (-44000, 26000, "Jeddah exit sweep"),
    (-43000, 23500, "Jeddah exit"),
]
for i, (x, z, desc) in enumerate(jeddah_pts):
    h = "DISTRICT 6: JEDDAH FLOW (~20km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 7: SINGAPORE MAZE
sing_pts = [
    (-42000, 21000, "Singapore entry"),
    (-40500, 19500, "Singapore S1 R"),
    (-42000, 17500, "Singapore S1 L"),
    (-40000, 15500, "Singapore S2 R"),
    (-42000, 13500, "Singapore S2 L"),
    (-40000, 11500, "Singapore S3 R"),
    (-42000, 9500, "Singapore S3 L"),
    (-40500, 7500, "Singapore S4 R"),
    (-42500, 5500, "Singapore S4 L"),
    (-40500, 3500, "Singapore S5 R"),
    (-42000, 1500, "Singapore S5 L"),
    (-40000, -500, "Singapore S6 R"),
    (-41500, -2500, "Singapore S6 L"),
    (-39500, -4500, "Singapore exit sweep"),
    (-37500, -6000, "Singapore exit"),
]
for i, (x, z, desc) in enumerate(sing_pts):
    h = "DISTRICT 7: SINGAPORE MAZE (~15km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 8: COTA SWEEP
cota_pts = [
    (-35000, -8000, "COTA entry"),
    (-32500, -9500, "COTA Turn 1 entry"),
    (-29500, -10500, "COTA Turn 1 apex 1"),
    (-26500, -11000, "COTA Turn 1 apex 2"),
    (-23500, -10500, "COTA Turn 1 exit"),
    (-21000, -9000, "COTA esses entry R"),
    (-19000, -10500, "COTA esses L"),
    (-16500, -9000, "COTA esses R2"),
    (-14000, -10500, "COTA back straight entry"),
    (-11500, -11500, "COTA back straight"),
    (-8500, -12000, "COTA Turn 12 entry"),
    (-6000, -11000, "COTA Turn 12 apex"),
    (-4000, -9500, "COTA stadium entry"),
    (-2000, -10500, "COTA stadium chicane L"),
    (0, -9000, "COTA stadium exit R"),
    (2500, -8000, "COTA exit"),
]
for i, (x, z, desc) in enumerate(cota_pts):
    h = "DISTRICT 8: COTA SWEEP (~15km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 9: SUZUKA ESSES
suzuka_pts = [
    (5000, -7000, "Suzuka entry"),
    (7500, -5500, "Suzuka S1 R"),
    (9000, -7000, "Suzuka S1 L"),
    (11500, -5500, "Suzuka S2 R"),
    (13000, -7500, "Suzuka S2 L"),
    (15500, -6000, "Suzuka S3 R Dunlop"),
    (17500, -7500, "Suzuka Degner 1"),
    (20000, -6500, "Suzuka Degner 2"),
    (22500, -8000, "Suzuka hairpin approach"),
    (24500, -6500, "Suzuka spoon entry"),
    (27000, -7500, "Suzuka spoon apex"),
    (29500, -6000, "Suzuka 130R entry"),
    (32000, -5000, "Suzuka 130R apex"),
    (34500, -4000, "Suzuka 130R exit"),
    (37000, -3500, "Suzuka chicane"),
    (39500, -2500, "Suzuka exit"),
]
for i, (x, z, desc) in enumerate(suzuka_pts):
    h = "DISTRICT 9: SUZUKA ESSES (~15km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 10: BAHRAIN MIX
bahrain_pts = [
    (41500, -1000, "Bahrain entry"),
    (43000, 1500, "Bahrain Turn 1"),
    (42000, 3500, "Bahrain chicane L"),
    (43500, 5500, "Bahrain fast R"),
    (42500, 7500, "Bahrain technical L"),
    (44000, 9500, "Bahrain flow R"),
    (43000, 11500, "Bahrain chicane L2"),
    (44500, 13500, "Bahrain fast section R"),
    (43500, 15500, "Bahrain inner L"),
    (44500, 17500, "Bahrain outer R"),
    (43000, 19500, "Bahrain Turn 10 L"),
    (44000, 21500, "Bahrain fast R2"),
    (42500, 23000, "Bahrain exit sweep L"),
    (41000, 24500, "Bahrain exit"),
]
for i, (x, z, desc) in enumerate(bahrain_pts):
    h = "DISTRICT 10: BAHRAIN MIX (~15km)" if i == 0 else None
    add_point(x, z, desc, h)

# DISTRICT 11: INTERLAGOS RETURN
inter_pts = [
    (39000, 23000, "Interlagos entry"),
    (36500, 21500, "Senna S entry R"),
    (34500, 22500, "Senna S apex L"),
    (32000, 21000, "Senna S exit R"),
    (29500, 20000, "Interlagos Reta Oposta"),
    (27000, 18500, "Interlagos Descida R"),
    (25000, 19500, "Interlagos Ferradura L"),
    (22500, 18000, "Interlagos Laranjinha R"),
    (20000, 17000, "Interlagos Pinheirinho"),
    (17500, 15500, "Interlagos Bico de Pato R"),
    (15500, 16500, "Interlagos merge L"),
    (13500, 15000, "Interlagos Juncao R"),
    (11000, 13500, "Interlagos Subida 1"),
    (8500, 12000, "Interlagos Subida 2"),
    (6000, 10000, "Interlagos sweeper"),
    (4000, 7500, "Interlagos approach"),
    (2500, 5000, "Interlagos final sweep"),
    (1000, 2500, "Interlagos final approach"),
]
for i, (x, z, desc) in enumerate(inter_pts):
    h = "DISTRICT 11: INTERLAGOS RETURN (~15km)" if i == 0 else None
    add_point(x, z, desc, h)

# Catmull-Rom interpolation
def catmull_rom(p0, p1, p2, p3, t):
    t2 = t * t
    t3 = t2 * t
    x = 0.5 * ((2*p1[0]) + (-p0[0]+p2[0])*t + (2*p0[0]-5*p1[0]+4*p2[0]-p3[0])*t2 + (-p0[0]+3*p1[0]-3*p2[0]+p3[0])*t3)
    z = 0.5 * ((2*p1[1]) + (-p0[1]+p2[1])*t + (2*p0[1]-5*p1[1]+4*p2[1]-p3[1])*t2 + (-p0[1]+3*p1[1]-3*p2[1]+p3[1])*t3)
    return (x, z)

n = len(points)
total_length = 0.0
subdivisions = 10
all_spline_points = []

for i in range(n):
    p0 = points[(i - 1) % n]
    p1 = points[i]
    p2 = points[(i + 1) % n]
    p3 = points[(i + 2) % n]
    prev = p1
    for s in range(1, subdivisions + 1):
        t = s / subdivisions
        curr = catmull_rom(p0, p1, p2, p3, t)
        dx = curr[0] - prev[0]
        dz = curr[1] - prev[1]
        total_length += math.sqrt(dx*dx + dz*dz)
        all_spline_points.append(curr)
        prev = curr

print(f"Total control points: {n}")
print(f"Total spline length: {total_length/1000:.1f} km")
xs = [p[0] for p in points]
zs = [p[1] for p in points]
print(f"X: {min(xs)/1000:.1f} to {max(xs)/1000:.1f} km (span: {(max(xs)-min(xs))/1000:.1f} km)")
print(f"Z: {min(zs)/1000:.1f} to {max(zs)/1000:.1f} km (span: {(max(zs)-min(zs))/1000:.1f} km)")

# Check minimum distance between non-adjacent control points
min_dist = float('inf')
min_pair = (-1, -1)
dists = []
for i in range(n):
    for j in range(i + 3, n):
        if i == 0 and j >= n - 2:
            continue
        dx = points[i][0] - points[j][0]
        dz = points[i][1] - points[j][1]
        dist = math.sqrt(dx*dx + dz*dz)
        dists.append((dist, i, j))
        if dist < min_dist:
            min_dist = dist
            min_pair = (i, j)

print(f"\nMin non-adjacent distance: {min_dist:.0f}m between #{min_pair[0]} and #{min_pair[1]}")
print(f"  #{min_pair[0]}: {descriptions[min_pair[0]]}")
print(f"  #{min_pair[1]}: {descriptions[min_pair[1]]}")

dists.sort()
print(f"\n5 closest non-adjacent pairs:")
for d, i, j in dists[:10]:
    print(f"  #{i} <-> #{j}: {d:.0f}m")

# Self-intersection check
def segments_intersect(a1, a2, b1, b2):
    def cross(o, a, b):
        return (a[0]-o[0])*(b[1]-o[1]) - (a[1]-o[1])*(b[0]-o[0])
    d1 = cross(b1, b2, a1)
    d2 = cross(b1, b2, a2)
    d3 = cross(a1, a2, b1)
    d4 = cross(a1, a2, b2)
    if ((d1 > 0 and d2 < 0) or (d1 < 0 and d2 > 0)) and \
       ((d3 > 0 and d4 < 0) or (d3 < 0 and d4 > 0)):
        return True
    return False

sp = all_spline_points
n_sp = len(sp)
intersections = 0
for i in range(0, n_sp - 1):
    for j in range(i + 10, n_sp - 1):
        if j > n_sp - 10 and i < 10:
            continue
        if segments_intersect(sp[i], sp[i+1], sp[j], sp[j+1]):
            intersections += 1
            if intersections <= 5:
                # Find which control points these correspond to
                ci = i // subdivisions
                cj = j // subdivisions
                print(f"\n*** INTERSECTION: spline seg {i} (ctrl ~#{ci}) x seg {j} (ctrl ~#{cj})")

if intersections == 0:
    print("\nNo self-intersections detected!")
else:
    print(f"\n{intersections} self-intersections detected!")

# Per-district lengths
print("\n--- Per-district lengths ---")
district_indices = [idx for idx, _ in district_headers]
district_indices.append(n)
for d in range(len(district_headers)):
    start_idx = district_headers[d][0]
    end_idx = district_indices[d + 1]
    name = district_headers[d][1]
    dist_length = 0.0
    for i in range(start_idx, end_idx):
        p0 = points[(i - 1) % n]
        p1 = points[i]
        p2 = points[(i + 1) % n]
        p3 = points[(i + 2) % n]
        prev = p1
        for s in range(1, subdivisions + 1):
            t = s / subdivisions
            curr = catmull_rom(p0, p1, p2, p3, t)
            dx = curr[0] - prev[0]
            dz = curr[1] - prev[1]
            dist_length += math.sqrt(dx*dx + dz*dz)
            prev = curr
    print(f"  {name}: {dist_length/1000:.1f} km ({end_idx - start_idx} pts)")
