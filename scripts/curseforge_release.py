"""Build HCOneButton and upload only on an explicit GitHub release event.

Python 3 standard library only. No network access during prepare/tests.
The token is read exclusively from CF_API_TOKEN during upload.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sys
import urllib.error
import urllib.request
import uuid
import zipfile

REPOSITORY = "DoctorB/hc-one-button"
AUTHORIZED_ACTORS = frozenset({"doctorb", "doctorcalibano"})
PROJECT_ID = 1666468
CLASSIC_VERSION_TYPE = 67408
API_ROOT = "https://www.curseforge.com/api"
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = Path("release/ci")
TAG = re.compile(r"v(\d+\.\d+\.\d+(?:-(?:alpha|beta)\.\d+)?)\Z")


def require(condition, message):
    if not condition:
        raise ValueError(message)


def authorize_actor(event):
    # GitHub supplies both values: actor remains the original initiator on reruns.
    # No fallback to release.author (which may merely have created the draft).
    actor = os.environ.get("GITHUB_ACTOR", "")
    triggering_actor = os.environ.get("GITHUB_TRIGGERING_ACTOR", "")
    require(actor.casefold() in AUTHORIZED_ACTORS and triggering_actor.casefold() in AUTHORIZED_ACTORS,
            "Only DoctorB and DoctorCalibano may run this release workflow")
    sender = event.get("sender")
    require(isinstance(sender, dict) and sender.get("type") == "User"
            and isinstance(sender.get("login"), str) and sender["login"].casefold() == actor.casefold(),
            "Missing or inconsistent GitHub event sender; publication denied")
    return actor, triggering_actor


def read_json(path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path, value):
    # Never silently replace an earlier artifact or upload receipt.
    with path.open("x", encoding="utf-8", newline="\n") as stream:
        json.dump(value, stream, ensure_ascii=False, indent=2)
        stream.write("\n")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def toc_metadata(root):
    toc = (root / "HCOneButton/HCOneButton.toc").read_text(encoding="utf-8-sig")
    fields = dict(re.findall(r"^## ([\w-]+):\s*([^\r\n]+)", toc, re.MULTILINE))
    version = fields.get("Version", "")
    require(TAG.fullmatch("v" + version), "Invalid TOC version")
    interface = fields.get("Interface", "")
    require(re.fullmatch(r"11\d{3}", interface), "Only Classic Era interface values are supported")
    game_version = f"{int(interface) // 10000}.{int(interface) // 100 % 100}.{int(interface) % 100}"
    for path, expression in (
        ("Core/Init.lua", r'HCOB\.VERSION\s*=\s*"([^"]+)"'),
        ("Core/State.lua", r'VERSION = HCOB\.VERSION or "([^"]+)"'),
    ):
        match = re.search(expression, (root / "HCOneButton" / path).read_text(encoding="utf-8-sig"))
        require(match and match[1] == version, "TOC/runtime version mismatch")
    for name in ("README.md", "CHANGELOG.md", "LICENSE"):
        source, packaged = (root / name).read_bytes(), (root / "HCOneButton" / name).read_bytes()
        if name == "LICENSE":  # Same normalization as tests/toc_manifest.lua on Windows.
            source, packaged = source.replace(b"\r\n", b"\n"), packaged.replace(b"\r\n", b"\n")
        require(source == packaged,
                f"Packaged {name} differs from repository copy")
    require(f"Current version:** `{version}`" in (root / "README.md").read_text(encoding="utf-8"),
            "README version mismatch")
    require(f"current release is `{version}`" in (root / "CHANGELOG.md").read_text(encoding="utf-8"),
            "CHANGELOG version mismatch")
    entries = [line.strip().replace("\\", "/") for line in toc.splitlines()
               if line.strip() and not line.startswith("##")]
    require(len(entries) == len(set(entries)), "Duplicate TOC entries")
    return version, game_version, entries


def release_context(event, event_name, version):
    authorize_actor(event)
    require(event.get("repository", {}).get("full_name") == REPOSITORY, "Unexpected repository")
    require(event_name in ("release", "workflow_dispatch"), "Unsupported workflow event")
    if event_name == "workflow_dispatch":
        return {"tag": "v" + version, "releaseType": "release", "publish": False}
    release = event.get("release", {})
    require(event.get("action") == "published" and release.get("draft") is False,
            "Only published, non-draft releases can upload")
    tag = release.get("tag_name", "")
    match = TAG.fullmatch(tag)
    require(match and match[1] == version, "Release tag must equal v + the exact TOC version")
    notes = release.get("body")
    require(isinstance(notes, str) and notes.strip(), "Release body/changelog must not be empty")
    prerelease = release.get("prerelease")
    require(type(prerelease) is bool, "Missing release/prerelease flag")
    require("-" not in version or prerelease, "Alpha/beta tags must be GitHub prereleases")
    require(type(release.get("id")) is int and release["id"] > 0, "Missing GitHub release ID")
    release_type = "alpha" if "-alpha." in version else ("beta" if prerelease else "release")
    return {"tag": tag, "releaseType": release_type, "publish": True,
            "releaseId": release["id"], "changelog": notes}


def local_changelog(root, version):
    text = (root / "CHANGELOG.md").read_text(encoding="utf-8")
    match = re.search(r"^## " + re.escape(version) + r"[^\n]*\n.*?(?=^## |\Z)",
                      text, re.MULTILINE | re.DOTALL)
    require(match, "Missing current release section in CHANGELOG.md")
    return match[0].strip() + "\n"


def package_files(root, entries):
    # Explicit package allowlist: no tests, workflows, credentials or local ZIPs.
    names = ["HCOneButton.toc", "README.md", "CHANGELOG.md", "LICENSE"] + entries
    require(len(names) == len(set(names)), "Duplicate package paths")
    result = {}
    addon = root / "HCOneButton"
    for name in names:
        path = PurePosixPath(name)
        require(not path.is_absolute() and ".." not in path.parts and ":" not in name
                and not any(part.startswith(".") for part in path.parts), "Unsafe package path")
        source = addon / path
        require(not any(part.is_symlink() for part in [source, *source.parents]), "Symlinks are not packaged")
        require(source.is_file() and source.resolve().is_relative_to(addon.resolve()),
                f"Missing or invalid package file: {name}")
        result["HCOneButton/" + name] = source.read_bytes()
    return result


def verify_archive(path, expected):
    with zipfile.ZipFile(path) as archive:
        require(archive.namelist() == sorted(expected), "ZIP manifest mismatch")
        require(archive.testzip() is None, "ZIP CRC failure")
        for name, sha in expected.items():
            require(digest(archive.read(name)) == sha, f"ZIP content mismatch: {name}")


def prepare(root, output, event, event_name):
    version, game_version, entries = toc_metadata(root)
    context = release_context(event, event_name, version)
    notes = context.pop("changelog", None) or local_changelog(root, version)
    files = package_files(root, entries)
    # A fresh directory also prevents mixing previous version artifacts.
    output.mkdir(parents=True, exist_ok=False)
    filename = f"HCOneButton-v{version}-ClassicEra.zip"
    archive_path = output / filename
    with zipfile.ZipFile(archive_path, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in sorted(files.items()):
            info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, content)
    hashes = {name: digest(content) for name, content in files.items()}
    verify_archive(archive_path, hashes)
    notes_name = f"HCOneButton-v{version}-CurseForge-ReleaseNotes.md"
    with (output / notes_name).open("x", encoding="utf-8", newline="\n") as stream:
        stream.write(notes)
    manifest = {**context, "projectId": PROJECT_ID, "version": version,
                "gameVersion": game_version, "zip": filename, "notes": notes_name,
                "sha256": digest(archive_path.read_bytes()), "files": hashes,
                "notesSha256": digest((output / notes_name).read_bytes())}
    write_json(output / "manifest.json", manifest)
    print(f"Verified {filename}: {len(files)} files; Classic Era {game_version}; {context['releaseType']}")
    return manifest


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward the upload credential to a redirected host.
        return None


def request_json(path, token, data=None, content_type=None):
    headers = {"X-Api-Token": token, "Accept": "application/json",
               "User-Agent": "HCOneButton-GitHub-Release"}
    if content_type:
        headers["Content-Type"] = content_type
    request = urllib.request.Request(API_ROOT + path, data=data, headers=headers)
    try:
        with urllib.request.build_opener(NoRedirect()).open(request, timeout=60) as response:
            return json.loads(response.read())
    except (urllib.error.URLError, OSError, ValueError):
        # Do not print remote bodies/headers, which might echo the token.
        # In particular, never retry a POST whose success might be ambiguous.
        raise ValueError("CurseForge request failed or returned an invalid response. "
                         "Check the project Files page before any new upload; no automatic retry was made.") from None


def game_version_id(versions, name):
    require(isinstance(versions, list), "Invalid CurseForge version catalog")
    matches = [item.get("id") for item in versions if isinstance(item, dict)
               and item.get("gameVersionTypeID") == CLASSIC_VERSION_TYPE and item.get("name") == name]
    require(len(matches) == 1 and type(matches[0]) is int and matches[0] > 0,
            "No unique exact Classic Era version match; refusing to guess another game version")
    return matches[0]


def multipart(metadata, filename, content):
    boundary = "hcob-" + uuid.uuid4().hex
    body = (f"--{boundary}\r\nContent-Disposition: form-data; name=\"metadata\"\r\n"
            "Content-Type: application/json\r\n\r\n").encode()
    body += json.dumps(metadata, ensure_ascii=False).encode("utf-8")
    body += (f"\r\n--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; "
             f"filename=\"{filename}\"\r\nContent-Type: application/zip\r\n\r\n").encode()
    return body + content + f"\r\n--{boundary}--\r\n".encode(), "multipart/form-data; boundary=" + boundary


def upload(output, event, event_name, token, run_attempt):
    actor, triggering_actor = authorize_actor(event)
    require(event_name == "release", "Manual validation runs cannot publish")
    require(run_attempt == "1", "Upload on workflow reruns is blocked to avoid duplicate files. "
            "Check CurseForge first; validated artifacts remain available for manual upload.")
    require(token and token.strip(), "Missing repository secret CF_API_TOKEN")
    manifest = read_json(output / "manifest.json")
    context = release_context(event, event_name, manifest["version"])
    require(manifest.get("publish") is True and manifest.get("projectId") == PROJECT_ID,
            "Artifact is not approved for this project")
    require(all(manifest.get(key) == context[key] for key in ("releaseId", "tag", "releaseType")),
            "Artifact/release event mismatch")
    expected_zip = f"HCOneButton-v{manifest['version']}-ClassicEra.zip"
    expected_notes = f"HCOneButton-v{manifest['version']}-CurseForge-ReleaseNotes.md"
    require(manifest["zip"] == expected_zip and manifest["notes"] == expected_notes, "Invalid artifact paths")
    content = (output / expected_zip).read_bytes()
    notes = (output / expected_notes).read_bytes()
    require(digest(content) == manifest["sha256"] and digest(notes) == manifest["notesSha256"],
            "Artifact changed after validation")
    require(notes.decode("utf-8") == context["changelog"], "Changelog no longer matches the release body")
    verify_archive(output / expected_zip, manifest["files"])
    require(not (output / "curseforge-receipt.json").exists(), "This package already has an upload receipt")
    versions = request_json("/game/wow/versions", token)
    version_id = game_version_id(versions, manifest["gameVersion"])
    metadata = {"changelog": context["changelog"], "changelogType": "markdown",
                "displayName": f"HCOneButton v{manifest['version']}", "releaseType": context["releaseType"],
                "gameVersions": [version_id], "isMarkedForManualRelease": False}
    body, content_type = multipart(metadata, expected_zip, content)
    result = request_json(f"/projects/{PROJECT_ID}/upload-file", token, body, content_type)
    require(isinstance(result, dict) and type(result.get("id")) is int and result["id"] > 0,
            "Upload result is ambiguous: check CurseForge before retrying")
    receipt = {"projectId": PROJECT_ID, "fileId": result["id"], "releaseId": context["releaseId"],
               "tag": context["tag"], "sha256": manifest["sha256"],
               "actor": actor, "triggeringActor": triggering_actor}
    write_json(output / "curseforge-receipt.json", receipt)
    message = f"CurseForge accepted file {result['id']} for project {PROJECT_ID}; approval may still be pending."
    print(message)
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as summary:
            summary.write(message + "\n")
    return receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=("prepare", "upload"))
    args = parser.parse_args()
    event = read_json(Path(os.environ["GITHUB_EVENT_PATH"]))
    event_name = os.environ.get("GITHUB_EVENT_NAME", "")
    if args.command == "prepare":
        prepare(ROOT, ROOT / OUTPUT, event, event_name)
    else:
        upload(ROOT / OUTPUT, event, event_name, os.environ.get("CF_API_TOKEN"),
               os.environ.get("GITHUB_RUN_ATTEMPT", ""))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError) as error:
        print(f"Release stopped: {error}", file=sys.stderr)
        sys.exit(1)
