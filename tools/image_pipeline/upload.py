"""Uploads cdn/ to a Cloudflare R2 bucket over the S3 API.

Keys in .env or the environment: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID,
R2_SECRET_ACCESS_KEY, R2_BUCKET. R2_ACCOUNT_ID is the bare account id or the
full S3 API address from the dashboard (required for EU-jurisdiction buckets).

Every url/thumbUrl in cdn/manifest.json must exist in cdn/ or in the bucket,
otherwise nothing is uploaded. Then pictures/ and thumbs/ go up (objects that
already exist with the same size are skipped), manifest.json last.

    uv run upload.py --dry-run
    uv run upload.py
    uv run upload.py --delete-stale    # also remove remote pictures/ and thumbs/
                                       # objects referenced by neither the old
                                       # (bucket) nor the new manifest
"""

import argparse
import json
import os

from common import CDN, CDN_MANIFEST, load_env

KEYS = ("R2_ACCOUNT_ID", "R2_ACCESS_KEY_ID", "R2_SECRET_ACCESS_KEY", "R2_BUCKET")
FOLDERS = ("pictures", "thumbs")


def endpoint_url(account: str) -> str:
    """R2_ACCOUNT_ID may be the bare account id or the bucket's full S3 API
    address from the dashboard (needed for EU buckets: <id>.eu.r2...)."""
    if "://" not in account:
        return f"https://{account}.r2.cloudflarestorage.com"
    from urllib.parse import urlsplit

    parts = urlsplit(account)
    return f"{parts.scheme}://{parts.netloc}"


def manifest_refs(manifest: dict) -> set[str]:
    """Bucket keys a manifest points to (relative url/thumbUrl only)."""
    return {
        p[k]
        for c in manifest.get("categories", [])
        for p in c.get("puzzles", [])
        for k in ("url", "thumbUrl")
        if isinstance(p.get(k), str) and "://" not in p[k]
    }


IMAGE_CACHE = "public, max-age=31536000, immutable"
MANIFEST_CACHE = "public, max-age=300"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="list what would be uploaded, change nothing")
    parser.add_argument(
        "--delete-stale", action="store_true",
        help="remove remote pictures/ and thumbs/ objects referenced by neither the bucket's nor the new manifest",
    )
    args = parser.parse_args()

    load_env()
    missing = [k for k in KEYS if not os.environ.get(k)]
    if missing and not args.dry_run:
        raise SystemExit(f"missing in .env or environment: {', '.join(missing)}")
    if not CDN_MANIFEST.exists():
        raise SystemExit("cdn/manifest.json not found, run manifest.py first")

    new_refs = manifest_refs(json.loads(CDN_MANIFEST.read_text(encoding="utf-8")))
    files = [(f"{d}/{f.name}", f) for d in FOLDERS for f in sorted((CDN / d).glob("*.webp"))]
    local = {key for key, _ in files}
    client = None
    if missing:
        print(f"no credentials ({', '.join(missing)}): no network checks, listing all files")
    else:
        import boto3
        from botocore.config import Config

        client = boto3.client(
            "s3",
            endpoint_url=endpoint_url(os.environ["R2_ACCOUNT_ID"]),
            aws_access_key_id=os.environ["R2_ACCESS_KEY_ID"],
            aws_secret_access_key=os.environ["R2_SECRET_ACCESS_KEY"],
            region_name="auto",
            config=Config(retries={"max_attempts": 5, "mode": "standard"}),
        )
    bucket = os.environ.get("R2_BUCKET")

    def not_found(e) -> bool:
        return e.response["Error"]["Code"] in ("404", "NoSuchKey", "NotFound")

    def remote_size(key: str) -> int | None:
        from botocore.exceptions import ClientError

        try:
            return client.head_object(Bucket=bucket, Key=key)["ContentLength"]
        except ClientError as e:
            if not_found(e):
                return None
            raise

    # Every file the new manifest points to must be in cdn/ or already in the bucket.
    absent = sorted(r for r in new_refs - local if client is None or remote_size(r) is None)
    if absent:
        where = "cdn/" if client is None else "cdn/ or the bucket"
        for r in absent:
            print(f"missing: {r}")
        raise SystemExit(f"{len(absent)} file(s) in cdn/manifest.json are not in {where}; nothing uploaded")

    # The manifest on the bucket now; its files must survive --delete-stale.
    old_refs: set[str] = set()
    if client is not None:
        from botocore.exceptions import ClientError

        try:
            body = client.get_object(Bucket=bucket, Key="manifest.json")["Body"].read()
            old_refs = manifest_refs(json.loads(body))
            print(f"bucket manifest.json references {len(old_refs)} files")
        except ClientError as e:
            if not not_found(e):
                raise
            print("no manifest.json on the bucket yet")

    uploaded = skipped = 0
    for key, f in files:
        if client is not None and remote_size(key) == f.stat().st_size:
            skipped += 1
            continue
        uploaded += 1
        if args.dry_run:
            print(f"would upload {key} ({f.stat().st_size} bytes)")
            continue
        client.upload_file(
            str(f), bucket, key,
            ExtraArgs={"ContentType": "image/webp", "CacheControl": IMAGE_CACHE},
        )
        print(f"uploaded {key}")

    if args.dry_run:
        print("would upload manifest.json")
    else:
        client.upload_file(
            str(CDN_MANIFEST), bucket, "manifest.json",
            ExtraArgs={"ContentType": "application/json", "CacheControl": MANIFEST_CACHE},
        )
        print("uploaded manifest.json")

    deleted = 0
    if args.delete_stale:
        if client is None:
            print("--delete-stale needs credentials; skipped")
        else:
            keep = old_refs | new_refs
            paginator = client.get_paginator("list_objects_v2")
            for d in FOLDERS:
                for page in paginator.paginate(Bucket=bucket, Prefix=f"{d}/"):
                    for obj in page.get("Contents", []):
                        if obj["Key"] in keep:
                            continue
                        deleted += 1
                        if args.dry_run:
                            print(f"would delete {obj['Key']}")
                        else:
                            client.delete_object(Bucket=bucket, Key=obj["Key"])
                            print(f"deleted {obj['Key']}")
    verb = "would be" if args.dry_run else "were"
    print(f"{uploaded} files {verb} uploaded, {skipped} skipped, {deleted} stale {verb} deleted")


if __name__ == "__main__":
    main()
