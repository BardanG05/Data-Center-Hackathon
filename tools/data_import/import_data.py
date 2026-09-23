"""Converts the supplied hackathon spreadsheets into the game's reviewed JSON files.

Run from this folder:  python import_data.py
Reads ../../Survey.csv.xlsx and ../../BCP Data.xlsx; writes town-builder/data/survey.json
and town-builder/data/real_world_data.json. Nothing else in the game reads the spreadsheets.
"""
import collections, datetime, json
import openpyxl

ROOT = "../.."
OUT = f"{ROOT}/town-builder/data"
TODAY = datetime.date.today().isoformat()


def sheet_rows(path, name=None):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb[name] if name else wb.worksheets[0]
    return [r for r in ws.iter_rows(values_only=True) if any(c is not None for c in r)]


# ---------------------------------------------------------------- survey
rows = sheet_rows(f"{ROOT}/Survey.csv.xlsx")
header, answers = rows[0], rows[1:]


def col(fragment):
    matches = [i for i, h in enumerate(header) if h and fragment in h]
    assert len(matches) == 1, (fragment, matches)
    return matches[0]


def counts(fragment, order=None):
    i = col(fragment)
    c = collections.Counter(str(r[i]) for r in answers if r[i] is not None)
    keys = order or [k for k, _ in c.most_common()]
    return {"question": header[i], "valid_n": sum(c.values()), "missing": len(answers) - sum(c.values()),
            "counts": {k: c.get(k, 0) for k in keys}}


CONDITIONS = [
    "Powered entirely by renewable (wind/solar) energy",
    "Redirected waste heat to warm local homes and businesses",
    "Required to fund local community projects or amenities",
    "Required to create a minimum number of local jobs",
    "Subject to independent, publicly reported environmental monitoring",
    "Architecturally designed to complement the local landscape",
    "Operated with regular open days or public information sessions",
    "Supported local schools with STEM education programmes",
    "Provided a direct reduction in local energy tariffs or bills",
    "Established a Community Liaison Committee with local decision-making power",
]
top3_i = col("Which three of the above conditions")
top3 = collections.Counter()
top3_valid = 0
for r in answers:
    if r[top3_i] is None:
        continue
    top3_valid += 1
    for option in CONDITIONS:  # options contain commas, so match whole strings
        if option in str(r[top3_i]):
            top3[option] += 1

IMPACT_AREAS = [
    "Natural environment",
    "People's health, skills and wellbeing (Human)",
    "Community identity and cohesion (Social)",
    "Land use and built infrastructure (Manufactured)",
    "Local economy and finances (Financial)",
]


def multi(fragment, options):
    i = col(fragment)
    c, valid = collections.Counter(), 0
    for r in answers:
        if r[i] is None:
            continue
        valid += 1
        for option in options:
            if option in str(r[i]):
                c[option] += 1
    return {"question": header[i], "valid_n": valid, "multiple_selections": 2, "counts": {k: c[k] for k in options}}


survey = {
    "schema_version": 1,
    "status": "imported",
    "source": "Social Acceptance of Sustainable Data Centres in Ireland (Maynooth University), supplied as Survey.csv.xlsx",
    "converted": TODAY,
    "sample_size": len(answers),
    "population": "Adults resident in Ireland who answered an online survey; not a representative sample of Ireland or of Bournemouth.",
    "scope_wording": "Among the surveyed respondents in Ireland…",
    "questions": {
        "attitude": counts("current attitude toward sustainable data centres",
                           ["Strongly supportive", "Somewhat supportive", "Neutral", "Somewhat opposed", "Strongly opposed",
                            "I don't have enough information to form a view"]),
        "accept_within_5km": counts("built within 5 km of your home",
                                    ["Completely acceptable", "Somewhat acceptable", "Neither acceptable nor unacceptable",
                                     "Somewhat unacceptable", "Completely unacceptable"]),
        "belief_fossil_fuels": counts("[All data centres in Ireland run on fossil fuels]", ["True", "False", "Don't Know"]),
        "belief_significant_share": counts("significant proportion of Ireland's total electricity use]", ["True", "False", "Don't Know"]),
        "belief_waste_heat": counts("[Data centres can redirect waste heat", ["True", "False", "Don't Know"]),
        "top3_conditions": {"question": header[top3_i], "valid_n": top3_valid, "multiple_selections": 3,
                            "counts": {k: top3[k] for k in CONDITIONS}},
        "most_negative_areas": multi("most negatively impact in your community", IMPACT_AREAS),
        "main_influence": counts("What single factor most influences your view"),
        "gut_feeling": counts("instinctive, gut-level feeling"),
    },
}
json.dump(survey, open(f"{OUT}/survey.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)

# ---------------------------------------------------------------- real-world data
BCP = f"{ROOT}/BCP Data.xlsx"
cso = {int(r[0]): {"data_centres": r[1], "other_customers": r[3], "total": r[4]}
       for r in sheet_rows(BCP, "CSO DC Electricity Consumption ")[1:] if isinstance(r[0], (int, float))}
seai = {int(r[0]): r[1] for r in sheet_rows(BCP, "SEAI DC Demand Forecast")[1:] if isinstance(r[0], (int, float))}
renew = {int(r[0]): r[2] for r in sheet_rows(BCP, "EirGrid RES KPI")[1:]
         if isinstance(r[0], (int, float)) and "Renewable" in str(r[1]) and int(r[0]) <= 2025}
kpmg = sheet_rows(BCP, "KPMG P87 (2025)")
types = {}
for j, name in enumerate(kpmg[0][1:5], start=1):
    types[name] = {"energy_gwh_per_year": kpmg[1][j], "building_sqft": kpmg[2][j],
                   "water_megalitres_per_year": kpmg[3][j], "co2_tonnes_per_year": kpmg[4][j]}
priorities = {r[0]: r[1] for r in sheet_rows(BCP, "Beyond FF Slide n.47 (2025)")[1:] if isinstance(r[1], (int, float))}

# Demand index: CSO metered use to 2025, then SEAI's forecast year-on-year growth applied to the CSO 2025 value.
last_cso = max(cso)
index, value = {}, None
for year in range(2015, 2035):
    if year in cso:
        value = cso[year]["data_centres"]
    else:
        value = value * seai[year] / seai[year - 1]
    index[year] = round(value / cso[2015]["data_centres"], 4)
other_index = {y: round(cso[y]["other_customers"] / cso[2015]["other_customers"], 4) for y in cso}

real = {
    "schema_version": 1,
    "status": "imported",
    "converted": TODAY,
    "geography": "Republic of Ireland (national). None of these values describe Bournemouth.",
    "facts": {
        "cso_electricity_gwh": {"source": "CSO data centre electricity consumption, via BCP Data.xlsx", "unit": "GWh/year", "by_year": cso},
        "seai_dc_forecast_gwh": {"source": "SEAI data centre demand forecast, via BCP Data.xlsx", "unit": "GWh/year", "by_year": seai},
        "renewable_share_of_demand": {"source": "EirGrid RES KPI, via BCP Data.xlsx", "unit": "fraction", "by_year": renew},
        "typical_data_centre_types": {"source": "KPMG report p.87 (2025), via BCP Data.xlsx", "by_type": types},
        "energy_shortage_priority": {"source": "Beyond Fossil Fuels survey slide 47 (2025), via BCP Data.xlsx",
                                     "question": "In the event of an energy shortage, which sectors should be prioritised?",
                                     "unit": "share naming it top priority", "by_sector": priorities},
    },
    "derived": {
        "dc_demand_index": {"method": f"CSO data-centre GWh ÷ CSO 2015 value for 2015–{last_cso}; later years apply SEAI forecast year-on-year growth to the CSO {last_cso} value.",
                            "by_year": index},
        "other_demand_index": {"method": "CSO other-customer GWh ÷ CSO 2015 value.", "by_year": other_index},
    },
}
json.dump(real, open(f"{OUT}/real_world_data.json", "w", encoding="utf-8"), indent=1, ensure_ascii=False)

share = {y: cso[y]["data_centres"] / cso[y]["total"] for y in cso}
print("DC share 2015 %.1f%%, %d %.1f%%" % (share[2015] * 100, last_cso, share[last_cso] * 100))
print("index", index)
print("top3", dict(top3), top3_valid)
print({k: v["counts"] for k, v in survey["questions"].items() if k != "top3_conditions"})
