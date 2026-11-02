#!/usr/bin/env python3
"""FindWay App Store Connect helper, run on Codemagic.

Uses the App Store Connect API key from the Codemagic integration
(environment variables APP_STORE_CONNECT_ISSUER_ID, APP_STORE_CONNECT_KEY_IDENTIFIER
and APP_STORE_CONNECT_PRIVATE_KEY).

  python3 tools/app_store_setup.py profile   create the "FindWay App Store" signing profile if missing
  python3 tools/app_store_setup.py listing   fill in description, keywords, promotional text,
                                             copyright and TestFlight test information

Safe to run again: it only fills in FindWay's own text and never deletes anything.
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import jwt  # pip install "pyjwt[crypto]"

BUNDLE_ID = "com.leoproductions.findway"
APP_NAME = "FindWay"
PROFILE_NAME = "FindWay App Store"
# Another app on the same account, used to copy the copyright holder and
# TestFlight contact details so they don't have to be typed again.
SISTER_BUNDLE_IDS = ["com.dungeon.descent", "com.stillhere.horror"]
STORE = os.path.join(os.path.dirname(__file__), "..", "store", "en-US")
API = "https://api.appstoreconnect.apple.com"


def token():
    names = ["APP_STORE_CONNECT_ISSUER_ID", "APP_STORE_CONNECT_KEY_IDENTIFIER", "APP_STORE_CONNECT_PRIVATE_KEY"]
    missing = [n for n in names if not os.environ.get(n)]
    if missing:
        found = sorted(k for k in os.environ if "APP_STORE" in k or "ASC" in k)
        sys.exit(f"Missing {missing}. App Store related variables present: {found}")
    now = int(time.time())
    return jwt.encode(
        {"iss": os.environ[names[0]], "iat": now, "exp": now + 1000, "aud": "appstoreconnect-v1"},
        private_key(os.environ[names[2]]),
        algorithm="ES256",
        headers={"kid": os.environ[names[1]], "typ": "JWT"},
    )


def private_key(value):
    """Turns the key from Codemagic into PEM text, whatever shape it arrives in."""
    value = value.strip()
    if value.startswith("@file:"):
        with open(os.path.expanduser(value[6:])) as f:
            value = f.read().strip()
    elif value.startswith("@env:"):
        value = os.environ.get(value[5:], "").strip()
    value = value.replace("\\n", "\n").strip().strip('"').strip()
    if "-----BEGIN" not in value:
        body = "".join(value.split())
        try:
            import base64
            decoded = base64.b64decode(body).decode()
            if "-----BEGIN" in decoded:
                return decoded
        except Exception:
            pass
        lines = [body[i:i + 64] for i in range(0, len(body), 64)]
        value = "-----BEGIN PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END PRIVATE KEY-----"
    else:
        # Rebuild the line breaks in case they were turned into spaces.
        head, rest = value.split("-----BEGIN", 1)
        kind = rest.split("-----", 1)[0]
        body = rest.split("-----", 1)[1].split("-----END", 1)[0]
        body = "".join(body.split())
        lines = [body[i:i + 64] for i in range(0, len(body), 64)]
        value = f"-----BEGIN{kind}-----\n" + "\n".join(lines) + f"\n-----END{kind}-----"
    return value


TOKEN = None


def call(method, path, body=None, params=None):
    global TOKEN
    TOKEN = TOKEN or token()
    url = API + path
    if params:
        url += "?" + urllib.parse.urlencode(params)
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {TOKEN}",
        "Content-Type": "application/json",
    })
    try:
        with urllib.request.urlopen(req) as res:
            raw = res.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")
        raise RuntimeError(f"{method} {path} failed ({e.code}): {detail}") from None


def text(name):
    with open(os.path.join(STORE, name), encoding="utf-8") as f:
        return f.read().strip()


def find_app(bundle_id):
    apps = call("GET", "/v1/apps", params={"filter[bundleId]": bundle_id})["data"]
    return next((a for a in apps if a["attributes"]["bundleId"] == bundle_id), None)


def find_bundle_id():
    found = call("GET", "/v1/bundleIds", params={"filter[identifier]": BUNDLE_ID})["data"]
    return next((b for b in found if b["attributes"]["identifier"] == BUNDLE_ID), None)


# ---------------------------------------------------------------- profile

def make_profile():
    bundle = find_bundle_id()
    if not bundle:
        sys.exit(f"{BUNDLE_ID} is not registered yet. Run the setup step that registers it first.")
    profiles = call("GET", "/v1/profiles", params={"filter[name]": PROFILE_NAME, "filter[profileState]": "ACTIVE"})["data"]
    if profiles:
        print(f'"{PROFILE_NAME}" already exists.')
        return
    certs = call("GET", "/v1/certificates", params={"filter[certificateType]": "DISTRIBUTION,IOS_DISTRIBUTION", "limit": 50})["data"]
    if not certs:
        sys.exit("No distribution certificate found on the Apple account.")
    for c in certs:
        print("Using certificate:", c["attributes"].get("name"), c["attributes"].get("expirationDate"))
    call("POST", "/v1/profiles", {"data": {
        "type": "profiles",
        "attributes": {"name": PROFILE_NAME, "profileType": "IOS_APP_STORE"},
        "relationships": {
            "bundleId": {"data": {"type": "bundleIds", "id": bundle["id"]}},
            "certificates": {"data": [{"type": "certificates", "id": c["id"]} for c in certs]},
        },
    }})
    print(f'Created "{PROFILE_NAME}".')


# ---------------------------------------------------------------- listing

def holder_name(copyright_text):
    """'Copyright leo productions 2026' or '© 2025 Leo' -> 'leo productions' / 'Leo'."""
    name = re.sub(r"(?i)\bcopyright\b|©|\(c\)", " ", copyright_text)
    name = re.sub(r"\b\d{4}(\s*[-–]\s*\d{4})?\b", " ", name)
    return " ".join(name.split()).strip(" ,.-")


def sister_info():
    """Copyright holder and TestFlight contact from another app on the account."""
    holder, contact = None, {}
    for bundle_id in SISTER_BUNDLE_IDS:
        try:
            app = find_app(bundle_id)
            if not app:
                continue
            if not holder:
                versions = call("GET", f"/v1/apps/{app['id']}/appStoreVersions", params={"limit": 5})["data"]
                for v in versions:
                    c = v["attributes"].get("copyright") or ""
                    name = holder_name(c)
                    if name:
                        holder = name
                        break
            if not contact:
                d = call("GET", f"/v1/apps/{app['id']}/betaAppReviewDetail")["data"]["attributes"]
                keys = ("contactFirstName", "contactLastName", "contactPhone", "contactEmail")
                if all(d.get(k) for k in keys):
                    contact = {k: d[k] for k in keys}
        except RuntimeError as e:
            print(f"Couldn't read {bundle_id}: {e}")
        if holder and contact:
            break
    return holder, contact


def fill_listing():
    app = find_app(BUNDLE_ID)
    if not app:
        print(f"No App Store Connect app uses {BUNDLE_ID} yet. Create the app first, then run this again.")
        return True  # not a failure: the app just doesn't exist yet
    app_id = app["id"]
    print(f"Found {app['attributes']['name']} ({app_id}).")
    ok = True
    holder, contact = sister_info()
    year = time.strftime("%Y")

    # App Store listing: description, keywords, promotional text, copyright.
    versions = call("GET", f"/v1/apps/{app_id}/appStoreVersions", params={"filter[platform]": "IOS"})["data"]
    editable = {"PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED"}
    versions = [v for v in versions if (v["attributes"].get("appStoreState") or v["attributes"].get("appVersionState")) in editable]
    if not versions:
        print("No App Store version is waiting for submission, so the listing text was skipped.")
    for v in versions:
        label = v["attributes"].get("versionString")
        locs = call("GET", f"/v1/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]
        loc = next((l for l in locs if l["attributes"]["locale"] == "en-US"), locs[0] if locs else None)
        if not loc:
            print(f"Version {label}: no listing language found, skipped.")
            continue
        try:
            call("PATCH", f"/v1/appStoreVersionLocalizations/{loc['id']}", {"data": {
                "type": "appStoreVersionLocalizations", "id": loc["id"],
                "attributes": {
                    "description": text("description.txt"),
                    "keywords": text("keywords.txt"),
                    "promotionalText": text("promotional_text.txt"),
                },
            }})
            print(f"Version {label} ({loc['attributes']['locale']}): description, keywords and promotional text set.")
        except RuntimeError as e:
            ok = False
            print(f"Version {label}: couldn't set the listing text: {e}")
        if holder:
            try:
                call("PATCH", f"/v1/appStoreVersions/{v['id']}", {"data": {
                    "type": "appStoreVersions", "id": v["id"],
                    "attributes": {"copyright": f"Copyright {holder} {year}"},
                }})
                print(f"Version {label}: copyright set to \"Copyright {holder} {year}\".")
            except RuntimeError as e:
                ok = False
                print(f"Version {label}: couldn't set the copyright: {e}")
        else:
            print("Copyright skipped: couldn't find the name used on your other apps.")

    # TestFlight test information: what to test, feedback email, review notes.
    try:
        locs = call("GET", f"/v1/apps/{app_id}/betaAppLocalizations")["data"]
        attrs = {"description": text("beta_description.txt")}
        # Feedback email: the same one your other apps use for TestFlight.
        if contact.get("contactEmail"):
            attrs["feedbackEmail"] = contact["contactEmail"]
        if locs:
            for l in locs:
                call("PATCH", f"/v1/betaAppLocalizations/{l['id']}", {"data": {
                    "type": "betaAppLocalizations", "id": l["id"], "attributes": attrs}})
        else:
            call("POST", "/v1/betaAppLocalizations", {"data": {
                "type": "betaAppLocalizations",
                "attributes": {**attrs, "locale": "en-US"},
                "relationships": {"app": {"data": {"type": "apps", "id": app_id}}},
            }})
        print("TestFlight: beta app description set" + (" and feedback email set." if "feedbackEmail" in attrs else "; add a feedback email yourself."))
    except RuntimeError as e:
        ok = False
        print(f"TestFlight: couldn't set the beta description: {e}")

    try:
        detail = call("GET", f"/v1/apps/{app_id}/betaAppReviewDetail")["data"]
        attrs = {"notes": text("review_notes.txt"), "demoAccountRequired": False}
        for k, value in contact.items():
            if not detail["attributes"].get(k):
                attrs[k] = value
        call("PATCH", f"/v1/betaAppReviewDetails/{detail['id']}", {"data": {
            "type": "betaAppReviewDetails", "id": detail["id"], "attributes": attrs}})
        print("TestFlight: review notes set, no sign-in required"
              + (", contact details copied from your other app." if contact else "."))
    except RuntimeError as e:
        ok = False
        print(f"TestFlight: couldn't set the review information: {e}")
    return ok


if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    if mode == "profile":
        make_profile()
    elif mode == "listing":
        sys.exit(0 if fill_listing() else 1)
    else:
        sys.exit(__doc__)
