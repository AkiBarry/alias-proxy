import json
import re
import sys
import yaml

with open("mapping.json") as f:
    mapping = json.load(f)

# Validate alias keys: only lowercase letters allowed
for alias in mapping:
    if not re.fullmatch(r"[a-z]+", alias):
        print(f"ERROR: Invalid alias key '{alias}' — only lowercase letters (a-z) are allowed.")
        sys.exit(1)

routers = {}
services = {}
middlewares = {}

def is_local(target):
    return target.startswith("127.0.0.1") or target.startswith("localhost")

for alias, target in mapping.items():
    if is_local(target):
        # Local target — reverse proxy to host machine
        routers[alias] = {
            "rule": f"Host(`{alias}`)",
            "entryPoints": ["web"],
            "service": alias,
        }
        # Inside Docker, 127.0.0.1/localhost refers to the container itself.
        # Replace with host.docker.internal to reach the host machine.
        docker_target = target.replace("127.0.0.1", "host.docker.internal")
        docker_target = docker_target.replace("localhost", "host.docker.internal")
        services[alias] = {
            "loadBalancer": {
                "servers": [{"url": f"http://{docker_target}"}]
            }
        }
    else:
        # External target — 302 redirect
        # Default to https:// if no scheme specified
        if re.match(r"^https?://", target):
            redirect_url = target
        else:
            redirect_url = f"https://{target}"

        mw_name = f"{alias}-redirect"
        middlewares[mw_name] = {
            "redirectRegex": {
                "regex": "^http://[^/]+(.*)",
                "replacement": f"{redirect_url}$1",
                "permanent": False,
            }
        }
        routers[alias] = {
            "rule": f"Host(`{alias}`)",
            "entryPoints": ["web"],
            "service": f"{alias}-noop",
            "middlewares": [mw_name],
        }
        # Traefik requires a service even for redirects; use a dummy one
        services[f"{alias}-noop"] = {
            "loadBalancer": {
                "servers": [{"url": "http://127.0.0.1"}]
            }
        }

dynamic_config = {
    "http": {
        "routers": routers,
        "services": services,
    }
}

if middlewares:
    dynamic_config["http"]["middlewares"] = middlewares

with open("dynamic.yml", "w") as f:
    yaml.dump(dynamic_config, f, sort_keys=False)

print("dynamic.yml generated successfully!")
