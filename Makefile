VERSION ?= "v1.0.0"

docker:
	docker build --build-arg version="$(VERSION)" -t ppmpplatform/ps-route53-backup:latest . && \
	docker build --build-arg version="$(VERSION)" -t ppmpplatform/ps-route53-backup:"$(VERSION)" .

docker-run:
	docker run ppmpplatform/ps-route53-backup:"$(VERSION)"

docker-push: docker
	docker push ppmpplatform/ps-route53-backup:"$(VERSION)" && \
	docker push ppmpplatform/ps-route53-backup:latest
