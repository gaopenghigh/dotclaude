# via copilot-api
# npx copilot-api start -p 4001

# via litellm
uvx --python 3.12 --from "litellm[proxy]" litellm -c litellm_config.yaml --port 4001
