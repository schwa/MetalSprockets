default:
	just --list

update-api:
	swift-api-tool . -o .public-api.yaml
